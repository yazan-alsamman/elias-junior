import 'dart:async';

import 'package:app/controller/cv_controller.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/job_match_report.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/services/career_api_service.dart';
import 'package:app/services/cv_pipeline_cache.dart';
import 'package:app/services/job_match_cache.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One row in the pipeline stepper — titles/subtitles reflect what the user did.
class PipelineStepInfo {
  const PipelineStepInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class PipelineController extends GetxController {
  bool isLoading = true;
  ATSCheckReport? latestReport;
  JobMatchReport? latestJobMatch;
  int activeStepIndex = 0;
  int progressPercent = 0;
  List<PipelineStepInfo> steps = const <PipelineStepInfo>[];
  String stageTitle = 'Upload CV';
  String stageBlurb =
      'Upload a PDF or Word CV to start ATS screening and job-fit analysis.';
  bool showStepProgress = false;

  /// Which CV the pipeline page is showing (null = latest / live upload).
  String? focusedDocumentId;
  String? _liveUploadFileName;
  CVDocument? focusedDocument;

  @override
  void onInit() {
    super.onInit();
    unawaited(fetchPipelineData());
  }

  void selectDocument(String? documentId) {
    focusedDocumentId = documentId;
    unawaited(fetchPipelineData());
  }

  /// Called when user picks a new file — pipeline restarts at step 1.
  void beginNewUpload(String fileName) {
    _liveUploadFileName = fileName;
    focusedDocumentId = null;
    focusedDocument = null;
    isLoading = false;
    unawaited(CvPipelineCache.reset(fileName: fileName));
    _applyLiveUpload(fileName);
    update();
  }

  /// Live refresh while uploading / post-upload flow (no loading spinner).
  Future<void> syncLive() async {
    final CVController? cv = _tryReadCvController();
    if (cv == null) return;

    if (cv.isUploading && _liveUploadFileName != null) {
      _applyLiveUpload(_liveUploadFileName!);
      update();
      return;
    }

    final CVDocument? doc = _resolveDocument(cv);
    if (doc != null) {
      await _applyFromAppState(doc, persist: true);
      update();
    }
  }

  Future<void> fetchPipelineData() async {
    isLoading = true;
    update();

    final CVController? cv = _tryReadCvController();
    if (cv != null && cv.isUploading && _liveUploadFileName != null) {
      _applyLiveUpload(_liveUploadFileName!);
      isLoading = false;
      update();
      return;
    }

    final CVDocument? doc = cv != null ? _resolveDocument(cv) : null;
    if (doc != null) {
      await _applyFromAppState(doc, persist: false);
      isLoading = false;
      update();
      return;
    }

    if (Get.find<AuthApiService>().isLoggedIn) {
      try {
        final Map<String, dynamic> data =
            await CareerApiService.to.pipelineSummary();
        final Map<String, dynamic>? lr =
            data['latestReport'] as Map<String, dynamic>?;
        latestReport = lr != null ? ATSCheckReport.fromJson(lr) : null;
        progressPercent = (data['progressPercent'] as num?)?.toInt() ?? 0;
        activeStepIndex = (data['activeStepIndex'] as num?)?.toInt() ?? 0;
        steps = _defaultSteps();
        stageTitle = steps[activeStepIndex.clamp(0, steps.length - 1)].title;
        stageBlurb = steps[activeStepIndex.clamp(0, steps.length - 1)].subtitle;
      } catch (_) {
        _resetEmpty();
      }
    } else {
      _resetEmpty();
    }

    isLoading = false;
    update();
  }

  void _resetEmpty() {
    latestReport = null;
    latestJobMatch = null;
    focusedDocument = null;
    progressPercent = 0;
    activeStepIndex = 0;
    steps = _defaultSteps();
    stageTitle = 'Upload CV';
    stageBlurb =
        'Upload a PDF or Word CV to start ATS screening and job-fit analysis.';
  }

  CVController? _tryReadCvController() {
    if (!Get.isRegistered<CVController>()) return null;
    return Get.find<CVController>();
  }

  CVDocument? _resolveDocument(CVController cv) {
    if (focusedDocumentId != null) {
      for (final CVDocument d in cv.documents) {
        if (d.id == focusedDocumentId) {
          focusedDocument = d;
          return d;
        }
      }
    }
    if (cv.postUploadDocument != null) {
      focusedDocument = cv.postUploadDocument;
      focusedDocumentId = cv.postUploadDocument!.id;
      return cv.postUploadDocument;
    }
    focusedDocument = cv.latestDocument;
    focusedDocumentId = cv.latestDocument?.id;
    return cv.latestDocument;
  }

  static List<PipelineStepInfo> _defaultSteps() {
    return const <PipelineStepInfo>[
      PipelineStepInfo(
        title: 'Upload CV',
        subtitle: 'Choose a PDF or Word file',
        icon: Icons.cloud_upload_rounded,
      ),
      PipelineStepInfo(
        title: 'ATS check',
        subtitle: 'Format & keyword screening',
        icon: Icons.fact_check_rounded,
      ),
      PipelineStepInfo(
        title: 'Target job',
        subtitle: 'Job title & description',
        icon: Icons.work_outline_rounded,
      ),
      PipelineStepInfo(
        title: 'Job fit (RAG)',
        subtitle: 'CV vs role match score',
        icon: Icons.compare_arrows_rounded,
      ),
      PipelineStepInfo(
        title: 'Results',
        subtitle: 'Scores, gaps & courses',
        icon: Icons.insights_rounded,
      ),
    ];
  }

  void _applyLiveUpload(String fileName) {
    final CVController? cv = _tryReadCvController();
    final int msg = cv?.messageIndex ?? 0;
    steps = <PipelineStepInfo>[
      PipelineStepInfo(
        title: 'Upload CV',
        subtitle: 'Uploading $fileName…',
        icon: Icons.cloud_upload_rounded,
      ),
      const PipelineStepInfo(
        title: 'ATS check',
        subtitle: 'Waiting for upload…',
        icon: Icons.fact_check_rounded,
      ),
      const PipelineStepInfo(
        title: 'Target job',
        subtitle: 'Job title & description',
        icon: Icons.work_outline_rounded,
      ),
      const PipelineStepInfo(
        title: 'Job fit (RAG)',
        subtitle: 'CV vs role match score',
        icon: Icons.compare_arrows_rounded,
      ),
      const PipelineStepInfo(
        title: 'Results',
        subtitle: 'Scores, gaps & courses',
        icon: Icons.insights_rounded,
      ),
    ];
    activeStepIndex = 0;
    showStepProgress = true;
    progressPercent = ((msg + 1) / CVController.progressMessages.length * 100)
        .round()
        .clamp(8, 92);
    stageTitle = 'Upload CV';
    stageBlurb = CVController.progressMessages[msg];
    latestReport = null;
    latestJobMatch = null;
    focusedDocument = null;
  }

  Future<void> _applyFromAppState(
    CVDocument doc, {
    required bool persist,
  }) async {
    final CVController? cv = _tryReadCvController();
    final ATSCheckReport r = doc.report;
    latestReport = r;
    focusedDocument = doc;

    JobMatchReport? match = cv?.lastJobMatchReport;
    if (match != null &&
        cv!.postUploadDocument?.id != doc.id &&
        cv.postUploadDocument?.fileName != doc.fileName) {
      match = await JobMatchCache.load(
        fileName: doc.fileName,
        documentId: doc.id,
      );
    } else if (match == null) {
      match = await JobMatchCache.load(
        fileName: doc.fileName,
        documentId: doc.id,
      );
    }
    latestJobMatch = match;

    final bool isLiveDoc = _isLiveSessionDoc(doc, cv);
    final bool uploading = isLiveDoc && (cv?.isUploading ?? false);
    final bool ragRunning = isLiveDoc && (cv?.isComputingJobMatch ?? false);
    final bool hasUpload = true;
    final bool hasAts = !uploading && r.score >= 0;
    final String jobTitle = isLiveDoc ? (cv?.postJobTitle.text.trim() ?? '') : '';
    final String jobDesc = isLiveDoc ? (cv?.postJobDescription.text.trim() ?? '') : '';
    final bool hasJobTarget = jobTitle.isNotEmpty ||
        jobDesc.isNotEmpty ||
        (match?.jobTitle.isNotEmpty ?? false);
    final bool hasRag = match != null && match.finalScore >= 0;
    final bool flowDone =
        isLiveDoc && cv?.postUploadStep == PostUploadStep.none && hasAts;

    final CvPipelineSnapshot? cached = await CvPipelineCache.load(
      documentId: doc.id,
      fileName: doc.fileName,
    );

    final String atsSubtitle = uploading
        ? 'Analyzing ${doc.fileName}…'
        : 'Score ${r.score} · ${r.listBadgeLabel}';
    final String jobSubtitle = jobTitle.isNotEmpty
        ? jobTitle
        : (match?.jobTitle.isNotEmpty ?? false)
            ? match!.jobTitle
            : 'Enter title & paste posting';
    final JobMatchReport? rag = match;
    final String ragSubtitle = ragRunning
        ? 'RAG analyzing…'
        : hasRag && rag != null
            ? '${rag.finalScore}% match · ${rag.suitabilityHeadline.isNotEmpty ? rag.suitabilityHeadline : 'Compared to target role'}'
            : 'Run Check fit on dashboard';
    final String resultsSubtitle = hasRag && rag != null
        ? 'ATS ${r.score} · Job fit ${rag.finalScore}'
        : 'ATS ${r.score} · add target job for fit score';

    steps = <PipelineStepInfo>[
      PipelineStepInfo(
        title: 'Upload CV',
        subtitle: doc.fileName,
        icon: Icons.cloud_upload_rounded,
      ),
      PipelineStepInfo(
        title: 'ATS check',
        subtitle: atsSubtitle,
        icon: Icons.fact_check_rounded,
      ),
      PipelineStepInfo(
        title: 'Target job',
        subtitle: jobSubtitle,
        icon: Icons.work_outline_rounded,
      ),
      PipelineStepInfo(
        title: 'Job fit (RAG)',
        subtitle: ragSubtitle,
        icon: Icons.compare_arrows_rounded,
      ),
      PipelineStepInfo(
        title: 'Results',
        subtitle: resultsSubtitle,
        icon: Icons.insights_rounded,
      ),
    ];

    showStepProgress = uploading || ragRunning;

    if (uploading) {
      activeStepIndex = 0;
      final int msg = cv?.messageIndex ?? 0;
      progressPercent = ((msg + 1) / CVController.progressMessages.length * 100)
          .round()
          .clamp(8, 92);
      stageTitle = 'Upload CV';
      stageBlurb = CVController.progressMessages[msg];
    } else if (ragRunning) {
      activeStepIndex = 3;
      progressPercent = 55;
      stageTitle = 'Job fit (RAG)';
      stageBlurb =
          'Comparing your CV skills to ${jobTitle.isNotEmpty ? jobTitle : 'the target role'} using the vector knowledge base.';
    } else if (isLiveDoc && cv?.postUploadStep == PostUploadStep.atsReview) {
      activeStepIndex = 1;
      progressPercent = r.score.clamp(0, 100);
      stageTitle = 'ATS check';
      stageBlurb =
          'ATS complete — score ${r.score}. Continue to enter your target job.';
    } else if (isLiveDoc && cv?.postUploadStep == PostUploadStep.jobMatch) {
      activeStepIndex = hasRag ? 4 : (hasJobTarget ? 3 : 2);
      progressPercent = hasRag
          ? 100
          : (hasJobTarget ? 50 : 30);
      stageTitle = hasRag ? 'Results' : 'Target job';
      stageBlurb = hasRag
          ? 'Job fit ${rag!.finalScore}. Review results or return to dashboard.'
          : 'Enter the job you are applying for, then run Check fit (RAG).';
    } else {
      final List<bool> done = <bool>[
        hasUpload,
        hasAts,
        hasJobTarget || (cached?.targetJobDone ?? false),
        hasRag || (cached?.ragDone ?? false),
        hasRag || flowDone || (cached?.resultsDone ?? false),
      ];
      final int next = done.indexWhere((bool d) => !d);
      if (next >= 0) {
        activeStepIndex = next;
      } else {
        activeStepIndex = steps.length;
      }

      if (activeStepIndex >= steps.length) {
        progressPercent = 100;
        stageTitle = 'Results';
        stageBlurb = hasRag && rag != null
            ? 'Complete — ATS ${r.score}, job fit ${rag.finalScore}. Open Results Hub for gaps and courses.'
            : 'Complete — ATS ${r.score}. Add a target job to get a CV-to-role fit score.';
      } else {
        if (activeStepIndex == 1) {
          progressPercent = r.score.clamp(0, 100);
        } else if (activeStepIndex == 3) {
          progressPercent = hasJobTarget ? 40 : 10;
        } else {
          progressPercent = (activeStepIndex / (steps.length - 1) * 100)
              .round()
              .clamp(0, 100);
        }
        stageTitle = steps[activeStepIndex].title;
        stageBlurb = switch (activeStepIndex) {
          0 => 'Choose a PDF or Word file from your device.',
          1 =>
            'ATS score ${r.score}. ${r.recommendations.isNotEmpty ? r.recommendations.first : 'Review format and keywords.'}',
          2 =>
            'Add the job you are applying for so we can score CV-to-job match.',
          3 => hasRag && rag != null
              ? 'Job fit score: ${rag.finalScore}. ${rag.missingSkills.isNotEmpty ? '${rag.missingSkills.length} skill gap(s) found.' : 'Strong alignment with the role.'}'
              : 'Paste the job description and tap Check fit (RAG + vector KB).',
          _ => hasRag && rag != null
              ? 'Open Results Hub for ATS ${r.score}, job fit ${rag.finalScore}, gaps, and course picks.'
              : 'Open Results Hub for your ATS score and optimization tips.',
        };
      }
    }

    if (persist && doc.id != null) {
      _liveUploadFileName = null;
      await CvPipelineCache.save(
        CvPipelineSnapshot(
          documentKey: 'id_${doc.id}',
          fileName: doc.fileName,
          activeStepIndex: activeStepIndex,
          progressPercent: progressPercent,
          targetJobDone: hasJobTarget,
          ragDone: hasRag,
          resultsDone: activeStepIndex >= steps.length,
        ),
      );
    }
  }

  bool _isLiveSessionDoc(CVDocument doc, CVController? cv) {
    if (cv == null) return false;
    if (cv.postUploadDocument?.id == doc.id) return true;
    if (cv.postUploadDocument?.fileName == doc.fileName &&
        cv.postUploadStep != PostUploadStep.none) {
      return true;
    }
    if (_liveUploadFileName != null &&
        doc.fileName == _liveUploadFileName &&
        (cv.isUploading || cv.latestDocument?.fileName == _liveUploadFileName)) {
      return true;
    }
    return cv.latestDocument?.id == doc.id &&
        cv.postUploadStep != PostUploadStep.none;
  }
}
