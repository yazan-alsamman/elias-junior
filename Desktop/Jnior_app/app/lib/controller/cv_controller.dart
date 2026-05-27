import 'dart:async';
import 'dart:typed_data';

import 'package:app/common/api_config.dart';
import 'package:app/common/platform_file_bytes.dart';
import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/job_match_report.dart';
import 'package:app/model/parsed_cv_profile.dart';
import 'package:app/controller/pipeline_controller.dart';
import 'package:app/controller/portfolio_controller.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/services/career_api_service.dart';
import 'package:app/services/cv_text_heuristic.dart';
import 'package:app/services/fake_cv_parser_service.dart';
import 'package:app/services/ats_score_ledger.dart';
import 'package:app/services/local_ats_report_cache.dart';
import 'package:app/services/local_ats_service.dart';
import 'package:app/services/local_cv_file_cache.dart';
import 'package:app/services/job_match_cache.dart';
import 'package:app/services/local_cv_json_store.dart';
import 'package:app/services/local_rag_service.dart';
import 'package:app/services/rag_role_mapper.dart';
import 'package:app/services/portfolio_profile_cache.dart';
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

  /// Last uploaded file bytes — used to re-parse for portfolio without re-picking a file.
  Uint8List? lastUploadBytes;
  String? lastUploadFileName;

  static const List<String> progressMessages = <String>[
    'Reading your CV…',
    'Running ATS format check…',
    'Saving results to your profile…',
    'Almost done…',
  ];

  final List<CVDocument> documents = <CVDocument>[];
  final Map<String, ATSCheckReport> _localAtsByDocumentId = <String, ATSCheckReport>{};
  final Map<String, ATSCheckReport> _localAtsByFileName = <String, ATSCheckReport>{};
  final Map<String, AtsScoreLedgerEntry> _scoreLedgerByFileName =
      <String, AtsScoreLedgerEntry>{};
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
  JobMatchReport? lastJobMatchReport;
  String? selectedTargetRole;
  List<RagRoleOption> ragRoleOptions = RagRoleMapper.knownRoles;
  String? jobMatchError;
  String ragRolePreviewLabel = '';
  ParsedCvProfile? _jobMatchProfileCache;

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
      unawaited(_restorePortfolioCache());
      unawaited(_preloadLocalAtsCache().then((_) => loadFromApi()));
    }
  }

  Future<void> _preloadLocalAtsCache() async {
    _localAtsByDocumentId.clear();
    _localAtsByFileName.clear();
    _scoreLedgerByFileName.clear();
    _localAtsByDocumentId.addAll(await LocalAtsReportCache.loadAllByDocumentId());
    _localAtsByFileName.addAll(await LocalAtsReportCache.loadAllByFileName());
    _scoreLedgerByFileName.addAll(await AtsScoreLedger.loadAllByFileName());
  }

  void _rememberLocalAtsReport({
    required ATSCheckReport report,
    String? documentId,
    String? fileName,
  }) {
    if (documentId != null && documentId.isNotEmpty) {
      _localAtsByDocumentId[documentId] = report;
    }
    if (fileName != null && fileName.trim().isNotEmpty) {
      _localAtsByFileName[fileName.trim()] = report;
    }
  }

  ATSCheckReport? _localAtsForDocument(CVDocument doc) {
    if (doc.id != null && _localAtsByDocumentId.containsKey(doc.id)) {
      return _localAtsByDocumentId[doc.id!];
    }
    return _localAtsByFileName[doc.fileName];
  }

  Future<void> _restorePortfolioCache() async {
    final ParsedCvProfile? fromJson =
        await LocalCvJsonStore.loadLatest(allowDemo: false);
    if (fromJson != null &&
        fromJson.hasPortfolioData &&
        !LocalCvJsonStore.isBundledDemoProfile(fromJson)) {
      lastPortfolioProfile = fromJson;
      return;
    }
    final ParsedCvProfile? cached = await PortfolioProfileCache.load();
    if (cached != null && cached.hasPortfolioData) {
      lastPortfolioProfile = cached;
    }
  }

  Future<CVDocument> _applyCachedAtsReport(CVDocument doc) async {
    ATSCheckReport? cached = _localAtsForDocument(doc);
    cached ??= await LocalAtsReportCache.loadFor(
      documentId: doc.id,
      fileName: doc.fileName,
    );
    if (cached != null) {
      _rememberLocalAtsReport(
        report: cached,
        documentId: doc.id,
        fileName: doc.fileName,
      );
      return doc.copyWith(report: cached);
    }

    if (doc.report.score == 28 ||
        LocalAtsReportCache.isPlaceholderScore(doc.report)) {
      AtsScoreLedgerEntry? ledger = _scoreLedgerByFileName[doc.fileName];
      ledger ??= await AtsScoreLedger.loadFor(
        documentId: doc.id,
        fileName: doc.fileName,
      );
      if (ledger != null && ledger.score > 0 && ledger.score != 28) {
        final ATSCheckReport patched =
            doc.report.withScore(ledger.score, engineOverride: ledger.engine);
        _rememberLocalAtsReport(
          report: patched,
          documentId: doc.id,
          fileName: doc.fileName,
        );
        return doc.copyWith(report: patched);
      }
    }
    return doc;
  }

  Future<CVDocument> _rescoreFromLocalFile(CVDocument doc) async {
    final ATSCheckReport? existing = _localAtsForDocument(doc);
    if (existing != null &&
        existing.isRealAts &&
        !LocalAtsReportCache.isPlaceholderScore(existing)) {
      return doc.copyWith(report: existing);
    }
    if (!LocalAtsReportCache.isPlaceholderScore(doc.report)) {
      return doc;
    }
    final Uint8List? bytes = await LocalCvFileCache.load(
      documentId: doc.id,
      fileName: doc.fileName,
    );
    if (bytes == null || bytes.isEmpty) {
      return doc;
    }
    try {
      final LocalAtsResult ats = await LocalAtsService.instance.analyzeFile(
        fileBytes: bytes,
        fileName: doc.fileName,
      );
      final ATSCheckReport report = ats.toAtsCheckReport();
      _rememberLocalAtsReport(
        report: report,
        documentId: doc.id,
        fileName: doc.fileName,
      );
      await LocalAtsReportCache.save(
        report: report,
        documentId: doc.id,
        fileName: doc.fileName,
      );
      await AtsScoreLedger.save(
        score: report.score,
        decision: report.scoreDecision,
        documentId: doc.id,
        fileName: doc.fileName,
      );
      _scoreLedgerByFileName[doc.fileName] = AtsScoreLedgerEntry(
        score: report.score,
        decision: report.scoreDecision,
      );
      return doc.copyWith(report: report);
    } catch (_) {
      return doc;
    }
  }

  /// Same filename, many Mongo rows — one cached PDF fixes all placeholder scores.
  Future<void> _rescoreMatchingFileName(
    List<CVDocument> docs,
    String fileName,
    ATSCheckReport report,
  ) async {
    for (int i = 0; i < docs.length; i++) {
      if (docs[i].fileName != fileName) {
        continue;
      }
      if (!LocalAtsReportCache.isPlaceholderScore(docs[i].report)) {
        continue;
      }
      docs[i] = docs[i].copyWith(report: report);
      _rememberLocalAtsReport(
        report: report,
        documentId: docs[i].id,
        fileName: fileName,
      );
      await LocalAtsReportCache.save(
        report: report,
        documentId: docs[i].id,
        fileName: fileName,
      );
    }
  }

  Future<void> _rescoreStaleFromCachedFiles(List<CVDocument> docs) async {
    if (lastUploadBytes != null &&
        lastUploadFileName != null &&
        lastUploadFileName!.isNotEmpty) {
      try {
        final LocalAtsResult ats = await LocalAtsService.instance.analyzeFile(
          fileBytes: lastUploadBytes!,
          fileName: lastUploadFileName!,
        );
        await _rescoreMatchingFileName(
          docs,
          lastUploadFileName!,
          ats.toAtsCheckReport(),
        );
      } catch (_) {
        /* ATS offline */
      }
    }

    final Set<String> staleNames = docs
        .where((CVDocument d) => LocalAtsReportCache.isPlaceholderScore(d.report))
        .map((CVDocument d) => d.fileName)
        .toSet();
    for (final String fileName in staleNames) {
      final Uint8List? shared = await LocalCvFileCache.load(fileName: fileName);
      if (shared == null || shared.isEmpty) {
        continue;
      }
      try {
        final LocalAtsResult ats = await LocalAtsService.instance.analyzeFile(
          fileBytes: shared,
          fileName: fileName,
        );
        await _rescoreMatchingFileName(
          docs,
          fileName,
          ats.toAtsCheckReport(),
        );
      } catch (_) {
        /* ATS offline — try per-doc */
      }
    }

    for (int i = 0; i < docs.length; i++) {
      if (LocalAtsReportCache.isPlaceholderScore(docs[i].report)) {
        docs[i] = await _rescoreFromLocalFile(docs[i]);
      }
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
        unawaited(PortfolioProfileCache.save(parsed));
        unawaited(
          LocalCvJsonStore.saveParsed(
            sourceFileName: doc.fileName,
            profile: parsed,
            documentId: doc.id,
          ),
        );
        return enriched;
      }
    }
    return doc;
  }

  /// Load CV list from Express + MongoDB.
  Future<void> loadFromApi() async {
    try {
      await _preloadLocalAtsCache();
      final List<CVDocument> list = await CareerApiService.to.documentsList();
      final List<CVDocument> enriched = <CVDocument>[];
      for (final CVDocument doc in list) {
        CVDocument row = _enrichDocumentWithParse(doc);
        row = await _applyCachedAtsReport(row);
        enriched.add(row);
      }
      await _rescoreStaleFromCachedFiles(enriched);
      documents
        ..clear()
        ..addAll(enriched);
      if (documents.isNotEmpty) {
        final CVDocument latest = documents.first;
        final JobMatchReport? cached = await JobMatchCache.load(
          fileName: latest.fileName,
          documentId: latest.id,
        );
        if (cached != null) {
          lastJobMatchReport = cached;
        }
      }
      update();
      final int stale = documents
          .where((CVDocument d) => LocalAtsReportCache.isPlaceholderScore(d.report))
          .length;
      if (stale > 0 && _localAtsByDocumentId.isEmpty && _localAtsByFileName.isEmpty) {
        AuroraSnack.info(
          'ATS scores',
          '$stale CV(s) still show placeholder score 28. '
          'Start ATS (start-local-dev.cmd) and upload once to refresh.',
          duration: const Duration(seconds: 6),
        );
      }
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
    lastPortfolioProfile = null;
    lastUploadBytes = null;
    lastUploadFileName = null;
    unawaited(PortfolioProfileCache.clear());
    unawaited(LocalCvJsonStore.clear());
    _localAtsByDocumentId.clear();
    _localAtsByFileName.clear();
    _scoreLedgerByFileName.clear();
    unawaited(LocalAtsReportCache.clear());
    unawaited(AtsScoreLedger.clear());
    unawaited(LocalCvFileCache.clear());
    unawaited(JobMatchCache.clear());
    lastJobMatchReport = null;
    update();
  }

  /// Parse one stored CV file (by Mongo id / filename) for portfolio preview.
  Future<ParsedCvProfile?> reparseDocumentForPortfolio(CVDocument doc) async {
    final Uint8List? bytes = await LocalCvFileCache.load(
      documentId: doc.id,
      fileName: doc.fileName,
    );
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    try {
      final LocalAtsResult ats = await LocalAtsService.instance.analyzeFile(
        fileBytes: bytes,
        fileName: doc.fileName,
      );
      final FakeCvParserResult? fake =
          await FakeCvParserService.instance.parseAndStore(
        fileName: doc.fileName,
        resumeText: ats.extractedText,
        documentId: doc.id,
      );
      if (fake != null && fake.profile.hasPortfolioData) {
        lastPortfolioProfile = fake.profile;
        unawaited(PortfolioProfileCache.save(fake.profile));
        return fake.profile;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Re-run local ATS + JSON store (no file picker).
  Future<ParsedCvProfile?> reparseLastUploadForPortfolio() async {
    final Uint8List? bytes = lastUploadBytes;
    final String? fileName = lastUploadFileName;
    String resumeText = '';
    if (bytes != null &&
        bytes.isNotEmpty &&
        fileName != null &&
        fileName.isNotEmpty) {
      try {
        final LocalAtsResult ats = await LocalAtsService.instance.analyzeFile(
          fileBytes: bytes,
          fileName: fileName,
        );
        resumeText = ats.extractedText;
      } catch (_) {
        /* use JSON folder fallback */
      }
    }
    final FakeCvParserResult? fake = await FakeCvParserService.instance
        .parseAndStore(fileName: fileName ?? 'cv.pdf', resumeText: resumeText);
    if (fake != null && fake.profile.hasPortfolioData) {
      lastPortfolioProfile = fake.profile;
      unawaited(PortfolioProfileCache.save(fake.profile));
      return fake.profile;
    }
    return await LocalCvJsonStore.loadLatest();
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
    lastJobMatchReport = null;
    jobMatchError = null;
    selectedTargetRole = null;
    unawaited(_loadRagRoles());
    unawaited(_prepareJobMatchStep());
    update();
  }

  Future<void> _prepareJobMatchStep() async {
    final CVDocument? doc = postUploadDocument;
    _jobMatchProfileCache = await _profileForJobMatch(doc);
    if (postJobTitle.text.trim().isEmpty &&
        _jobMatchProfileCache?.headline.isNotEmpty == true) {
      postJobTitle.text = _jobMatchProfileCache!.headline;
    }
    refreshRagRolePreview();
  }

  void refreshRagRolePreview() {
    ragRolePreviewLabel = LocalRagService.previewTargetRole(
      jobTitle: postJobTitle.text.trim(),
      jobDescription: postJobDescription.text.trim(),
      overrideRole: selectedTargetRole,
      cvProfile: _jobMatchProfileCache,
    );
    update();
  }

  Future<void> _loadRagRoles() async {
    ragRoleOptions = await LocalRagService.instance.fetchRoles();
    update();
  }

  Future<ParsedCvProfile?> _profileForJobMatch(CVDocument? doc) async {
    if (doc?.parsedProfile != null && doc!.parsedProfile!.hasPortfolioData) {
      return doc.parsedProfile;
    }
    if (lastPortfolioProfile != null && lastPortfolioProfile!.hasPortfolioData) {
      return lastPortfolioProfile;
    }
    if (doc != null) {
      final ParsedCvProfile? reparsed = await reparseDocumentForPortfolio(doc);
      if (reparsed != null && reparsed.hasPortfolioData) {
        return reparsed;
      }
      final ParsedCvProfile? bundled = await LocalCvJsonStore.loadBundledForFileName(
        doc.fileName,
      );
      if (bundled != null) {
        return bundled;
      }
    }
    return LocalCvJsonStore.loadLatest(allowDemo: false);
  }

  JobMatchReport? jobMatchForDocument(CVDocument? doc) {
    if (doc == null) {
      return lastJobMatchReport;
    }
    if (lastJobMatchReport != null &&
        (lastJobMatchReport!.jobTitle == postJobTitle.text.trim() ||
            doc.fileName == postUploadDocument?.fileName)) {
      return lastJobMatchReport;
    }
    return null;
  }

  Future<JobMatchReport?> loadCachedJobMatch(CVDocument doc) async {
    return JobMatchCache.load(
      fileName: doc.fileName,
      documentId: doc.id,
    );
  }

  Future<void> runTargetJobMatch() async {
    if (postJobTitle.text.trim().isEmpty) {
      AuroraSnack.error('Target job', 'Enter a job title to run RAG job fit.');
      return;
    }
    final CVDocument? doc = postUploadDocument;
    isComputingJobMatch = true;
    jobMatchError = null;
    update();

    try {
      final bool ready = await LocalRagService.instance.isReady();
      if (!ready) {
        throw RagServiceException(
          'RAG offline. Run .\\start-local-dev.cmd, set OPENAI_API_KEY in RAG/env.local, then: python -m cv_rag.cli ingest',
        );
      }

      final ParsedCvProfile? profile =
          _jobMatchProfileCache ?? await _profileForJobMatch(doc);
      if (profile == null || !profile.hasPortfolioData) {
        throw RagServiceException(
          'No parsed CV JSON yet. Upload a CV from cv-s/ or wait for parse to finish.',
        );
      }
      _jobMatchProfileCache = profile;

      final JobMatchReport report = await LocalRagService.instance.analyzeCv(
        profile: profile,
        jobTitle: postJobTitle.text.trim(),
        company: postCompany.text.trim(),
        jobDescription: postJobDescription.text.trim(),
        targetRole: selectedTargetRole,
      );

      lastJobMatchReport = report;
      computedJobMatchPercent = report.finalScore;
      if (doc != null) {
        final int idx = documents.indexWhere((CVDocument d) => d.id == doc.id);
        if (idx >= 0) {
          documents[idx] = documents[idx].copyWithParsed(profile);
        }
        unawaited(
          JobMatchCache.save(
            fileName: doc.fileName,
            report: report,
            documentId: doc.id,
          ),
        );
      }
    } on RagServiceException catch (e) {
      jobMatchError = e.message;
      computedJobMatchPercent = null;
      lastJobMatchReport = null;
      AuroraSnack.error('Job fit (RAG)', e.message, duration: const Duration(seconds: 8));
    } catch (e) {
      jobMatchError = e.toString();
      computedJobMatchPercent = null;
      lastJobMatchReport = null;
      AuroraSnack.error('Job fit (RAG)', '$e', duration: const Duration(seconds: 8));
    }

    isComputingJobMatch = false;
    update();
    if (Get.isRegistered<PipelineController>()) {
      unawaited(Get.find<PipelineController>().fetchPipelineData());
    }
  }

  void finishPostUploadFlow() {
    postUploadStep = PostUploadStep.none;
    postUploadDocumentIndex = null;
    computedJobMatchPercent = null;
    jobMatchError = null;
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
      lastUploadBytes = fileBytes;
      lastUploadFileName = name;
      await LocalCvFileCache.save(bytes: fileBytes, fileName: name);

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

      final FakeCvParserResult? fakeParse =
          await FakeCvParserService.instance.parseAndStore(
        fileName: name,
        resumeText: resumeText,
        fileBytes: fileBytes,
      );

      Map<String, dynamic>? parsedCvMap = fakeParse?.parsedCvMap;
      ParsedCvProfile? localParsed = fakeParse?.profile;
      String parseEngine =
          fakeParse?.parseEngine ?? LocalCvJsonStore.fakeParserEngine;

      if (resumeText.isEmpty && fakeParse != null && fakeParse.fromLocalJson) {
        AuroraSnack.info(
          'CV parser (local)',
          'Using saved CV JSON from your device. Upload again after restarting ATS for live text extract.',
          duration: const Duration(seconds: 5),
        );
      }

      final ATSCheckReport localReport = atsResult.toAtsCheckReport();
      _rememberLocalAtsReport(report: localReport, fileName: name);
      await AtsScoreLedger.save(
        score: localReport.score,
        decision: localReport.scoreDecision,
        fileName: name,
      );
      _scoreLedgerByFileName[name] = AtsScoreLedgerEntry(
        score: localReport.score,
        decision: localReport.scoreDecision,
      );
      await LocalAtsReportCache.save(report: localReport, fileName: name);

      final Map<String, dynamic> atsPayload =
          Map<String, dynamic>.from(atsResult.raw);
      atsPayload['computed_score'] = localReport.score;
      atsPayload['computed_decision'] = localReport.scoreDecision;

      final Map<String, dynamic> saved =
          await CareerApiService.to.saveLocalAnalysis(
        originalFileName: name,
        fileType: ext,
        ats: atsPayload,
        fileBytes: fileBytes,
        fileName: name,
        parsedCv: parsedCvMap,
        parseEngine: parseEngine,
        resumeText: resumeText,
      );

      CVDocument uploaded = CVDocument.fromUploadResponse(saved);
      uploaded = uploaded.copyWith(report: localReport);
      await LocalCvFileCache.save(
        bytes: fileBytes,
        fileName: name,
        documentId: uploaded.id,
      );
      _rememberLocalAtsReport(
        report: localReport,
        documentId: uploaded.id,
        fileName: name,
      );
      await AtsScoreLedger.save(
        score: localReport.score,
        decision: localReport.scoreDecision,
        documentId: uploaded.id,
        fileName: name,
      );
      _scoreLedgerByFileName[name] = AtsScoreLedgerEntry(
        score: localReport.score,
        decision: localReport.scoreDecision,
      );
      await LocalAtsReportCache.save(
        report: localReport,
        documentId: uploaded.id,
        fileName: name,
      );
      for (int i = 0; i < documents.length; i++) {
        if (documents[i].fileName == name &&
            LocalAtsReportCache.isPlaceholderScore(documents[i].report)) {
          documents[i] = documents[i].copyWith(report: localReport);
        }
      }
      if (localParsed != null && localParsed.hasPortfolioData) {
        uploaded = uploaded.copyWithParsed(localParsed);
        if (uploaded.id != null) {
          await LocalCvJsonStore.saveParsed(
            sourceFileName: name,
            profile: localParsed,
            documentId: uploaded.id,
          );
        }
      } else if (parsedCvMap != null) {
        uploaded = uploaded.copyWithParsed(
          ParsedCvProfile.fromJson(parsedCvMap),
        );
      }
      if (uploaded.parsedProfile != null &&
          uploaded.parsedProfile!.hasPortfolioData) {
        lastPortfolioProfile = uploaded.parsedProfile;
        unawaited(PortfolioProfileCache.save(uploaded.parsedProfile!));
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
