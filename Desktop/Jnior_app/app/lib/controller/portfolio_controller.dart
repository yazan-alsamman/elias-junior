import 'dart:async';

import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/parsed_cv_profile.dart';
import 'package:app/model/portfolio_preview_data.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/services/career_api_service.dart';
import 'package:app/services/cv_text_heuristic.dart';
import 'package:app/services/github_og_image_service.dart';
import 'package:app/services/portfolio_custom_image_codec.dart';
import 'package:app/services/portfolio_profile_cache.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Trims invisible chars and ensures a scheme so browsers and [launchUrl] accept the string.
String normalizePublishedPortfolioUrl(String? raw) {
  if (raw == null) {
    return '';
  }
  final String trimmed =
      raw.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
  if (trimmed.isEmpty) {
    return '';
  }
  final RegExp hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');
  if (hasScheme.hasMatch(trimmed)) {
    return trimmed;
  }
  return 'http://$trimmed';
}

class PortfolioController extends GetxController {
  final TextEditingController githubLinkController = TextEditingController();
  final TextEditingController projectInputController = TextEditingController();

  bool loading = false;
  bool showPreview = false;
  String displayUsername = '';
  bool publishing = false;
  String? publishedPortfolioUrl;

  final List<String> projectNames = <String>[];
  PortfolioTemplate selectedTemplate = PortfolioTemplate.classic;
  PortfolioPreviewData? previewData;

  /// GitHub-provided OG images per repo title (exact string as typed).
  final Map<String, String> projectOgImageUrls = <String, String>{};

  /// Desktop/mobile: filesystem path chosen in the image picker (not sent raw; JPEG snapshot on save).
  final Map<String, String> projectCustomCoverPaths = <String, String>{};

  /// Web (or transient): unpicked bytes for live preview until encoded on save.
  final Map<String, Uint8List> projectCustomCoverMemory = <String, Uint8List>{};

  int _ogJobSerial = 0;

  @override
  void onInit() {
    super.onInit();
    unawaited(_hydrateGithub());
  }

  Future<void> _hydrateGithub() async {
    if (!Get.find<AuthApiService>().isLoggedIn) {
      return;
    }
    try {
      final Map<String, dynamic>? body = await CareerApiService.to.getGithub();
      final Map<String, dynamic>? g =
          body?['github'] as Map<String, dynamic>?;
      if (g != null && g['githubUsername'] != null) {
        displayUsername = g['githubUsername'] as String? ?? '';
        githubLinkController.text = displayUsername.isNotEmpty ? displayUsername : '';
        showPreview = displayUsername.isNotEmpty;
        if (showPreview) {
          await hydrateFromLatestCv(tryReparseLastUpload: true);
          _rebuildPreviewDataOnly();
          _scheduleOgResolution();
        }
        update();
      }
    } catch (_) {}
  }

  void addProjectFromField() {
    final String raw = projectInputController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    projectNames.add(raw);
    projectInputController.clear();
    _rebuildPreviewIfVisible();
    update();
  }

  void removeProject(int index) {
    if (index >= 0 && index < projectNames.length) {
      final String dead = portfolioProjectKey(projectNames[index]);
      projectCustomCoverPaths.remove(dead);
      projectCustomCoverMemory.remove(dead);
      projectNames.removeAt(index);
      _rebuildPreviewIfVisible();
      update();
    }
  }

  Future<void> pickCoverForProject(String projectDisplayName) async {
    final String key = portfolioProjectKey(projectDisplayName);
    if (key.isEmpty) {
      return;
    }
    try {
      final FilePickerResult? res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (res == null || res.files.isEmpty) {
        return;
      }
      final PlatformFile file = res.files.single;
      if (kIsWeb) {
        final Uint8List? bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          AuroraSnack.warning('Image', 'Could not read image data.');
          return;
        }
        projectCustomCoverMemory[key] = bytes;
        projectCustomCoverPaths.remove(key);
      } else {
        final String? path = file.path;
        if (path == null || path.trim().isEmpty) {
          return;
        }
        projectCustomCoverPaths[key] = path;
        projectCustomCoverMemory.remove(key);
      }
      update();
      _rebuildPreviewIfVisible();
    } catch (e) {
      AuroraSnack.error('Image', '$e');
    }
  }

  void clearCoverForProject(String projectDisplayName) {
    final String k = portfolioProjectKey(projectDisplayName);
    projectCustomCoverPaths.remove(k);
    projectCustomCoverMemory.remove(k);
    update();
    _rebuildPreviewIfVisible();
  }

  Future<Map<String, String>> _buildCustomCoversForSnapshot() async {
    final Map<String, String> out = <String, String>{};
    for (final String n in projectNames) {
      final String k = portfolioProjectKey(n);
      if (k.isEmpty) {
        continue;
      }
      if (projectCustomCoverMemory.containsKey(k)) {
        final Uint8List? b = projectCustomCoverMemory[k];
        if (b != null && b.isNotEmpty) {
          final String? u = PortfolioCustomImageCodec.bytesToSnapshotDataUrl(b);
          if (u != null) {
            out[k] = u;
          }
        }
      } else if (projectCustomCoverPaths.containsKey(k)) {
        final String? path = projectCustomCoverPaths[k];
        if (path != null && path.trim().isNotEmpty) {
          final String? u =
              await PortfolioCustomImageCodec.filePathToSnapshotDataUrl(path);
          if (u != null) {
            out[k] = u;
          }
        }
      }
    }
    return out;
  }

  void setTemplate(PortfolioTemplate template) {
    selectedTemplate = template;
    _rebuildPreviewIfVisible();
    update();
  }

  ParsedCvProfile? _parsedFromCv;

  /// Called right after CV upload when parser JSON is in the upload response.
  void applyParsedProfile(ParsedCvProfile parsed) {
    if (!parsed.hasPortfolioData) {
      return;
    }
    _applyParsedToPortfolio(parsed);
  }

  /// Load name, bio, skills from stored JSON or parsed résumé text.
  Future<void> hydrateFromLatestCv({bool tryReparseLastUpload = false}) async {
    if (!Get.find<AuthApiService>().isLoggedIn) {
      return;
    }
    if (!Get.isRegistered<CVController>()) {
      return;
    }
    final CVController cv = Get.find<CVController>();

    final ParsedCvProfile? disk = await PortfolioProfileCache.load();
    if (disk != null && disk.hasPortfolioData) {
      cv.lastPortfolioProfile = disk;
      _applyParsedToPortfolio(disk);
      return;
    }

    if (cv.documents.isEmpty) {
      await cv.loadFromApi();
    }
    if (cv.documents.isEmpty) {
      if (tryReparseLastUpload) {
        final ParsedCvProfile? reparsed =
            await cv.reparseLastUploadForPortfolio();
        if (reparsed != null) {
          _applyParsedToPortfolio(reparsed);
        }
      }
      return;
    }

    final List<CVDocument> sorted = List<CVDocument>.from(cv.documents)
      ..sort(
        (CVDocument a, CVDocument b) => b.uploadedAt.compareTo(a.uploadedAt),
      );

    ParsedCvProfile? parsed;
    for (final CVDocument doc in sorted) {
      parsed = await _resolveParsedForDocument(doc);
      if (parsed != null && parsed.hasPortfolioData) {
        break;
      }
    }

    if (parsed != null && parsed.hasPortfolioData) {
      _applyParsedToPortfolio(parsed);
      return;
    }

    final ParsedCvProfile? cached = cv.lastPortfolioProfile;
    if (cached != null && cached.hasPortfolioData) {
      _applyParsedToPortfolio(cached);
      return;
    }

    if (tryReparseLastUpload) {
      final ParsedCvProfile? reparsed =
          await cv.reparseLastUploadForPortfolio();
      if (reparsed != null) {
        _applyParsedToPortfolio(reparsed);
        return;
      }
    }
  }

  Future<ParsedCvProfile?> _resolveParsedForDocument(CVDocument doc) async {
    ParsedCvProfile? parsed = doc.parsedProfile;
    if (parsed != null && parsed.hasPortfolioData) {
      return parsed;
    }

    if (doc.id != null) {
      try {
        final Map<String, dynamic> body =
            await CareerApiService.to.fetchParsedProfile(doc.id!);
        final Object? raw = body['parsedCv'];
        if (raw is Map<String, dynamic>) {
          parsed = ParsedCvProfile.fromJson(raw);
          if (parsed.hasPortfolioData) {
            return parsed;
          }
        }
      } catch (_) {
        /* try text fallback */
      }
    }

    String text = doc.extractedText.trim();
    if (_isPlaceholderExtractedText(text)) {
      final String preview = doc.contentPreview.trim();
      if (preview.length > 80 && !_isPlaceholderExtractedText(preview)) {
        text = preview;
      } else {
        return null;
      }
    }
    if (text.length > 80) {
      return CvTextHeuristic.parseResumeText(text);
    }
    return null;
  }

  bool _isPlaceholderExtractedText(String text) {
    final String low = text.toLowerCase();
    return low.startsWith('uploaded cv:') ||
        low.startsWith('uploaded for ats') ||
        low == 'pending';
  }

  void _applyParsedToPortfolio(ParsedCvProfile parsed) {
    _parsedFromCv = parsed;
    unawaited(PortfolioProfileCache.save(parsed));
    if (projectNames.isEmpty && parsed.projects.isNotEmpty) {
      for (final Map<String, dynamic> p in parsed.projects) {
        final String name =
            (p['name'] ?? p['title'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          projectNames.add(name);
        }
      }
    }
    if (showPreview && displayUsername.isNotEmpty) {
      _rebuildPreviewDataOnly();
      update();
    }
  }

  /// Rebuild live preview after CV list loads or when opening Portfolio.
  void refreshPreviewFromCv() {
    if (showPreview && displayUsername.isNotEmpty) {
      _rebuildPreviewDataOnly();
      update();
    }
  }

  void _rebuildPreviewDataOnly() {
    if (!showPreview || displayUsername.isEmpty) {
      previewData = null;
      return;
    }
    final ParsedCvProfile? parsed = _parsedFromCv;
    if (parsed != null && parsed.hasPortfolioData) {
      previewData = PortfolioPreviewData.fromParsedProfile(
        parsed: parsed,
        githubUsername: displayUsername,
        template: selectedTemplate,
        projectNames: List<String>.from(projectNames),
        projectOgImagesByName: Map<String, String>.from(projectOgImageUrls),
        projectCustomImagesByName: const <String, String>{},
      );
      return;
    }
    if (Get.find<AuthApiService>().isLoggedIn) {
      previewData = PortfolioPreviewData.fromAwaitingCv(
        githubUsername: displayUsername,
        template: selectedTemplate,
        projectNames: List<String>.from(projectNames),
        projectOgImagesByName: Map<String, String>.from(projectOgImageUrls),
        projectCustomImagesByName: const <String, String>{},
      );
      return;
    }
    previewData = PortfolioPreviewData.fromDummy(
      githubUsername: displayUsername,
      template: selectedTemplate,
      projectNames: List<String>.from(projectNames),
      projectOgImagesByName: Map<String, String>.from(projectOgImageUrls),
      projectCustomImagesByName: const <String, String>{},
    );
  }

  void _rebuildPreviewIfVisible() {
    if (!showPreview || displayUsername.isEmpty) {
      return;
    }
    _rebuildPreviewDataOnly();
    _scheduleOgResolution();
  }

  void _scheduleOgResolution() {
    if (!showPreview || displayUsername.isEmpty) {
      return;
    }
    final int serial = ++_ogJobSerial;
    unawaited(_runOgResolution(serial, githubOwnerLogin: displayUsername));
  }

  Future<void> _runOgResolution(
    int serial, {
    required String githubOwnerLogin,
  }) async {
    final List<String> names = projectNames
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    final Map<String, String> next = <String, String>{};
    for (final String n in names) {
      if (serial != _ogJobSerial) {
        return;
      }
      final String? img = await GithubOgImageService.fetchRepoOgImage(
        githubOwnerLogin: githubOwnerLogin,
        repoDisplayName: n,
      );
      if (img != null) {
        next[n] = img;
      }
    }
    if (serial != _ogJobSerial) {
      return;
    }
    projectOgImageUrls
      ..clear()
      ..addAll(next);
    _rebuildPreviewDataOnly();
    update();
  }

  Future<void> fetchPortfolio() async {
    final String? user = extractGithubUsername(githubLinkController.text);
    if (user == null || user.isEmpty) {
      AuroraSnack.warning(
        'GitHub',
        'Enter a GitHub username or paste a github.com/profile link.',
      );
      return;
    }
    loading = true;
    showPreview = false;
    previewData = null;
    update();

    if (Get.find<AuthApiService>().isLoggedIn) {
      try {
        await CareerApiService.to.linkGithub(user);
        displayUsername = user;
      } catch (e) {
        loading = false;
        update();
        AuroraSnack.error('GitHub', '$e');
        return;
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      displayUsername = user;
    }

    loading = false;
    showPreview = true;
    update();
    await hydrateFromLatestCv(tryReparseLastUpload: true);
    _rebuildPreviewDataOnly();
    update();
    if (_parsedFromCv == null || !_parsedFromCv!.hasPortfolioData) {
      AuroraSnack.warning(
        'CV data missing',
        'Upload your CV on the Dashboard (ATS must be running), then generate preview again.',
        duration: const Duration(seconds: 7),
      );
    }
    _scheduleOgResolution();
  }

  /// Saves portfolio to MongoDB and sets [publishedPortfolioUrl] (opens at /p/{slug} on the API host).
  Future<void> publishPortfolioLink() async {
    if (!Get.find<AuthApiService>().isLoggedIn) {
      AuroraSnack.warning(
        'Sign in',
        'Log in to create a public portfolio link.',
      );
      return;
    }
    final CVController cv = Get.find<CVController>();
    CVDocument? chosen;
    for (final CVDocument d in cv.documents) {
      if (d.id != null && d.report.status != 'Pending') {
        chosen = d;
        break;
      }
    }
    if (chosen?.id == null) {
      AuroraSnack.warning(
        'Portfolio',
        'Upload a CV on the Dashboard and run ATS analysis first.',
      );
      return;
    }
    final String? parsedGh = extractGithubUsername(githubLinkController.text);
    final String gh = (parsedGh != null && parsedGh.isNotEmpty)
        ? parsedGh
        : displayUsername.trim();
    if (gh.isEmpty) {
      AuroraSnack.warning(
        'GitHub',
        'Enter your GitHub username or profile link above, then generate the preview.',
      );
      return;
    }
    final List<String> trimmedRepos = projectNames
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    if (trimmedRepos.isEmpty) {
      AuroraSnack.warning(
        'Repositories',
        'Add at least one GitHub repo name that you shipped (above), then save again.',
      );
      return;
    }
    publishing = true;
    update();
    try {
      final int serial = ++_ogJobSerial;
      await _runOgResolution(serial, githubOwnerLogin: gh);
      final Map<String, String> customSnap = await _buildCustomCoversForSnapshot();
      final ParsedCvProfile? parsed = _parsedFromCv ?? chosen!.parsedProfile;
      final PortfolioPreviewData snapshotData = parsed != null &&
              parsed.hasPortfolioData
          ? PortfolioPreviewData.fromParsedProfile(
              parsed: parsed,
              githubUsername: gh,
              template: selectedTemplate,
              projectNames: List<String>.from(projectNames),
              projectOgImagesByName:
                  Map<String, String>.from(projectOgImageUrls),
              projectCustomImagesByName: customSnap,
            )
          : PortfolioPreviewData.fromAwaitingCv(
              githubUsername: gh,
              template: selectedTemplate,
              projectNames: List<String>.from(projectNames),
              projectOgImagesByName:
                  Map<String, String>.from(projectOgImageUrls),
              projectCustomImagesByName: customSnap,
            );

      final Map<String, dynamic> body = await CareerApiService.to.upsertPortfolio(
        documentId: chosen!.id!,
        templateId: selectedTemplate.name,
        githubUsername: gh,
        projects: List<String>.from(projectNames),
        previewSnapshot: snapshotData.toJson(),
      );
      final Map<String, dynamic>? p =
          body['portfolio'] as Map<String, dynamic>?;
      final String normalized =
          normalizePublishedPortfolioUrl(p?['portfolioUrl'] as String?);
      publishedPortfolioUrl = normalized.isEmpty ? null : normalized;
      update();
      if (publishedPortfolioUrl != null && publishedPortfolioUrl!.isNotEmpty) {
        AuroraSnack.success(
          'Portfolio published',
          'Link ready. Open it on the same machine as the API, or set PUBLIC_BASE_URL '
          'to your PC IP if you use a phone.',
          duration: const Duration(seconds: 6),
        );
      }
    } catch (e) {
      AuroraSnack.error('Portfolio', '$e');
    } finally {
      publishing = false;
      update();
    }
  }

  @override
  void onClose() {
    githubLinkController.dispose();
    projectInputController.dispose();
    super.onClose();
  }
}
