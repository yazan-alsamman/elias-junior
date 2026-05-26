import 'dart:async';
import 'dart:typed_data';

import 'package:app/common/api_config.dart';
import 'package:app/common/platform_file_bytes.dart';
import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/parsed_cv_profile.dart';
import 'package:app/controller/pipeline_controller.dart';
import 'package:app/controller/portfolio_controller.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/services/career_api_service.dart';
import 'package:app/services/cv_text_heuristic.dart';
import 'package:app/services/local_ats_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// After a new upload: ATS review → target job + match (same idea as dashboard).
enum PostUploadStep {
  none,
  atsReview,
  jobMatch,
}

class CVController extends GetxController {
  /// Last successfully parsed profile (same session) when Mongo has no JSON yet.
  ParsedCvProfile? lastPortfolioProfile;

  static const List<String> progressMessages = <String>[
    'Reading your CV…',
    'Running ATS format check…',
    'Saving results to your profile…',
    'Almost done…',
  ];

  final List<CVDocument> documents = <CVDocument>[];
  bool isUploading = false;
  int messageIndex = 0;
  Timer? _uploadMessageTimer;
  bool _uploadCancelled = false;

  /// Stops the fake "processing" overlay and returns to the dashboard without adding a CV.
  void cancelUpload() {
    if (!isUploading) {
      return;
    }
    _uploadCancelled = true;
    _uploadMessageTimer?.cancel();
    _uploadMessageTimer = null;
    isUploading = false;
    messageIndex = 0;
    update();
  }

  PostUploadStep postUploadStep = PostUploadStep.none;
  int? postUploadDocumentIndex;
  bool isComputingJobMatch = false;
  int? computedJobMatchPercent;

  late final TextEditingController postJobTitle;
  late final TextEditingController postCompany;
  late final TextEditingController postJobDescription;

  @override
  void onInit() {
    super.onInit();
    postJobTitle = TextEditingController();
    postCompany = TextEditingController();
    postJobDescription = TextEditingController();
    if (Get.find<AuthApiService>().isLoggedIn) {
      unawaited(loadFromApi());
    }
  }

  CVDocument _enrichDocumentWithParse(CVDocument doc) {
    if (doc.parsedProfile != null && doc.parsedProfile!.hasPortfolioData) {
      return doc;
    }
    final String text = doc.extractedText.trim();
    if (text.length > 80 &&
        !text.toLowerCase().startsWith('uploaded cv:') &&
        !text.toLowerCase().startsWith('uploaded for ats')) {
      final ParsedCvProfile? parsed = CvTextHeuristic.parseResumeText(text);
      if (parsed != null && parsed.hasPortfolioData) {
        final CVDocument enriched = doc.copyWithParsed(parsed);
        lastPortfolioProfile = parsed;
        return enriched;
      }
    }
    return doc;
  }

  /// Load CV list from Express + MongoDB.
  Future<void> loadFromApi() async {
    try {
      final List<CVDocument> list = await CareerApiService.to.documentsList();
      final List<CVDocument> enriched = <CVDocument>[];
      for (final CVDocument doc in list) {
        enriched.add(_enrichDocumentWithParse(doc));
      }
      documents
        ..clear()
        ..addAll(enriched);
      update();
      if (Get.isRegistered<PortfolioController>()) {
        final PortfolioController port = Get.find<PortfolioController>();
        unawaited(
          port.hydrateFromLatestCv().then((_) => port.refreshPreviewFromCv()),
        );
      }
      // Keep Pipeline page in sync with the latest CV.
      if (Get.isRegistered<PipelineController>()) {
        unawaited(Get.find<PipelineController>().fetchPipelineData());
      }
    } catch (e) {
      AuroraSnack.error('CV storage', '$e');
    }
  }

  /// After logout — clear stored CVs (no fake demo scores).
  void resetToDemo() {
    documents.clear();
    update();
  }

  @override
  void onClose() {
    postJobTitle.dispose();
    postCompany.dispose();
    postJobDescription.dispose();
    super.onClose();
  }

  CVDocument? get postUploadDocument {
    final int? i = postUploadDocumentIndex;
    if (i == null || i < 0 || i >= documents.length) {
      return null;
    }
    return documents[i];
  }

  /// Most recently uploaded CV (sorted by `uploadedAt`, descending).
  /// Single source of truth for Pipeline + Results pages.
  CVDocument? get latestDocument {
    if (documents.isEmpty) return null;
    final List<CVDocument> sorted = List<CVDocument>.from(documents)
      ..sort((CVDocument a, CVDocument b) =>
          b.uploadedAt.compareTo(a.uploadedAt));
    return sorted.first;
  }

  int get cvsAnalyzed => documents.length;

  int get skillsMatched {
    if (documents.isEmpty) {
      return 0;
    }
    final CVDocument? latest = latestDocument;
    if (latest?.parsedProfile != null && latest!.parsedProfile!.skills.isNotEmpty) {
      return latest.parsedProfile!.skills.length;
    }
    return latest?.report.keywordsChecked ?? 0;
  }

  int get avgAtsScore {
    if (documents.isEmpty) {
      return 0;
    }
    final int sum = documents.fold<int>(
      0,
      (int a, CVDocument d) => a + d.report.score,
    );
    return sum ~/ documents.length;
  }

  void continueFromAtsToJobStep() {
    if (postUploadStep != PostUploadStep.atsReview) {
      return;
    }
    postUploadStep = PostUploadStep.jobMatch;
    computedJobMatchPercent = null;
    update();
  }

  Future<void> runTargetJobMatch() async {
    if (postJobTitle.text.trim().isEmpty) {
      return;
    }
    isComputingJobMatch = true;
    update();
    await Future<void>.delayed(const Duration(milliseconds: 950));
    final CVDocument? doc = postUploadDocument;
    final int base = doc?.report.score ?? 55;
    final int titleN = postJobTitle.text.length.clamp(0, 20);
    final int jdN = (postJobDescription.text.length ~/ 35).clamp(0, 22);
    computedJobMatchPercent = (base ~/ 2 + titleN + jdN).clamp(38, 96);
    isComputingJobMatch = false;
    update();
  }

  void finishPostUploadFlow() {
    postUploadStep = PostUploadStep.none;
    postUploadDocumentIndex = null;
    computedJobMatchPercent = null;
    isComputingJobMatch = false;
    postJobTitle.clear();
    postCompany.clear();
    postJobDescription.clear();
    update();
  }

  Future<void> uploadCv() async {
    // Native Android file picker is a system screen — no Flutter button can appear there.
    // Offer cancel here; inside the picker, Back / swipe-back closes it and returns null.
    final bool? proceed = await AuroraDialog.confirm(
      title: 'Upload CV',
      message:
          "The next screen is Android's file picker (not part of this app).\n\n"
          'To go back without choosing a file: press the device Back button, '
          'or swipe from the left edge / use the gesture bar.\n\n'
          'If Downloads is empty, push a PDF or Word file into the emulator, '
          'or open the side menu to browse another folder.',
      confirmLabel: 'Choose file',
      cancelLabel: 'Back to dashboard',
      icon: Icons.upload_file_rounded,
    );
    if (proceed != true) {
      return;
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'docx'],
      withData: true,
      withReadStream: true,
      dialogTitle: 'Select CV (PDF or Word)',
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final PlatformFile file = result.files.first;
    final String name = file.name;
    if (name.isEmpty) {
      return;
    }

    _uploadCancelled = false;
    isUploading = true;
    messageIndex = 0;
    update();

    _uploadMessageTimer?.cancel();
    _uploadMessageTimer = Timer.periodic(const Duration(milliseconds: 700), (Timer t) {
      if (_uploadCancelled) {
        t.cancel();
        return;
      }
      messageIndex = (messageIndex + 1) % progressMessages.length;
      update();
    });

    const Duration totalDelay = Duration(seconds: 2);
    const int steps = 20;
    final int stepMs = totalDelay.inMilliseconds ~/ steps;
    for (int i = 0; i < steps; i++) {
      await Future<void>.delayed(Duration(milliseconds: stepMs));
      if (_uploadCancelled) {
        _uploadMessageTimer?.cancel();
        _uploadMessageTimer = null;
        return;
      }
    }

    _uploadMessageTimer?.cancel();
    _uploadMessageTimer = null;

    if (_uploadCancelled) {
      return;
    }

    final bool useApi = Get.find<AuthApiService>().isLoggedIn;
    if (!useApi) {
      isUploading = false;
      update();
      AuroraSnack.warning(
        'Sign in required',
        'Log in to run a real ATS format check on your CV.',
      );
      return;
    }

    try {
      final Uint8List fileBytes = await readPlatformFileBytes(file);

      // ATS only (local Uvicorn :8000). CV parser is paused — see ApiConfig.cvParserEnabled.
      final String ext = name.toLowerCase().split('.').last;

      final LocalAtsResult atsResult;
      try {
        atsResult = await LocalAtsService.instance.analyzeFile(
          fileBytes: fileBytes,
          fileName: name,
        );
      } catch (atsErr) {
        AuroraSnack.error(
          'ATS engine offline',
          'Start ATS: .\\start-local-dev.cmd  (URL: ${ApiConfig.atsBaseUrl})\n$atsErr',
          duration: const Duration(seconds: 8),
        );
        isUploading = false;
        update();
        return;
      }

      final String resumeText = atsResult.extractedText;
      Map<String, dynamic>? parsedCvMap;
      ParsedCvProfile? localParsed;
      String parseEngine = 'text-heuristic-v1';

      if (resumeText.length > 80) {
        localParsed = CvTextHeuristic.parseResumeText(resumeText);
        if (localParsed != null && localParsed.hasPortfolioData) {
          parsedCvMap = localParsed.toPortfolioJson();
        }
      } else if (resumeText.isEmpty) {
        AuroraSnack.warning(
          'CV text',
          'Restart ATS (start-local-dev.cmd) so the engine returns résumé text for your portfolio.',
          duration: const Duration(seconds: 7),
        );
      }

      if (parsedCvMap == null) {
        try {
          final Map<String, dynamic> extracted =
              await CareerApiService.to.extractParseCvFile(
            fileBytes: fileBytes,
            fileName: name,
          );
          final Object? raw = extracted['parsedCv'];
          if (raw is Map<String, dynamic>) {
            parsedCvMap = raw;
            localParsed = ParsedCvProfile.fromJson(parsedCvMap);
            parseEngine =
                (extracted['parseEngine'] as String?) ?? parseEngine;
          }
        } catch (_) {
          /* Hostinger may lack extract-parse; client ATS text is enough */
        }
      }

      final Map<String, dynamic> saved =
          await CareerApiService.to.saveLocalAnalysis(
        originalFileName: name,
        fileType: ext,
        ats: atsResult.raw,
        fileBytes: fileBytes,
        fileName: name,
        parsedCv: parsedCvMap,
        parseEngine: parseEngine,
        resumeText: resumeText,
      );

      CVDocument uploaded = CVDocument.fromUploadResponse(saved);
      if (saved['_saveVia'] == 'upload-analyze') {
        uploaded = uploaded.copyWith(report: atsResult.toAtsCheckReport());
      }
      if (localParsed != null && localParsed.hasPortfolioData) {
        uploaded = uploaded.copyWithParsed(localParsed);
      } else if ((uploaded.parsedProfile == null ||
              !uploaded.parsedProfile!.hasPortfolioData) &&
          resumeText.length > 80) {
        final ParsedCvProfile? fromText =
            CvTextHeuristic.parseResumeText(resumeText);
        if (fromText != null) {
          uploaded = uploaded.copyWithParsed(fromText);
        }
      } else if (parsedCvMap != null && uploaded.parsedProfile == null) {
        uploaded = uploaded.copyWithParsed(
          ParsedCvProfile.fromJson(parsedCvMap),
        );
      }
      if (uploaded.parsedProfile != null &&
          uploaded.parsedProfile!.hasPortfolioData) {
        lastPortfolioProfile = uploaded.parsedProfile;
      }
      documents.add(uploaded);
      if (Get.isRegistered<PortfolioController>()) {
        final PortfolioController port = Get.find<PortfolioController>();
        if (uploaded.parsedProfile != null &&
            uploaded.parsedProfile!.hasPortfolioData) {
          port.applyParsedProfile(uploaded.parsedProfile!);
        } else if (uploaded.id != null) {
          unawaited(
            port.hydrateFromLatestCv().then((_) => port.refreshPreviewFromCv()),
          );
        }
      }
      postUploadDocumentIndex = documents.length - 1;
      postUploadStep = PostUploadStep.atsReview;
      computedJobMatchPercent = null;
      if (Get.isRegistered<PipelineController>()) {
        unawaited(Get.find<PipelineController>().fetchPipelineData());
      }
    } catch (e) {
      AuroraSnack.error(
        'Upload / ATS',
        e.toString().replaceFirst('Exception: ', ''),
        duration: const Duration(seconds: 8),
      );
    }

    isUploading = false;
    update();
  }

}
