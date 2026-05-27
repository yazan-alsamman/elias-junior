import 'dart:async';

import 'package:app/controller/cv_controller.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/job_match_report.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/services/career_api_service.dart';
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

  @override
  void onInit() {
    super.onInit();
    unawaited(fetchPipelineData());
  }

  /// Prefer local CV + user actions; fall back to backend summary when empty.
  Future<void> fetchPipelineData() async {
    isLoading = true;
    update();

    final CVDocument? latestLocal = _tryReadLatestLocalDocument();
    if (latestLocal != null) {
      _applyFromAppState(latestLocal);
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
        latestReport = null;
        latestJobMatch = null;
        progressPercent = 0;
        activeStepIndex = 0;
        steps = _defaultSteps();
        stageTitle = 'Upload CV';
        stageBlurb =
            'Upload a PDF or Word CV to start ATS screening and job-fit analysis.';
      }
    } else {
      latestReport = null;
      latestJobMatch = null;
      progressPercent = 0;
      activeStepIndex = 0;
      steps = _defaultSteps();
      stageTitle = 'Upload CV';
      stageBlurb =
          'Upload a PDF or Word CV to start ATS screening and job-fit analysis.';
    }

    isLoading = false;
    update();
  }

  CVDocument? _tryReadLatestLocalDocument() {
    if (!Get.isRegistered<CVController>()) return null;
    return Get.find<CVController>().latestDocument;
  }

  CVController? _tryReadCvController() {
    if (!Get.isRegistered<CVController>()) return null;
    return Get.find<CVController>();
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

  void _applyFromAppState(CVDocument doc) {
    final CVController? cv = _tryReadCvController();
    final ATSCheckReport r = doc.report;
    latestReport = r;
    latestJobMatch = cv?.lastJobMatchReport;

    final bool uploading = cv?.isUploading ?? false;
    final bool ragRunning = cv?.isComputingJobMatch ?? false;
    final bool hasUpload = true;
    final bool hasAts = !uploading && r.score >= 0;
    final String jobTitle = cv?.postJobTitle.text.trim() ?? '';
    final String jobDesc = cv?.postJobDescription.text.trim() ?? '';
    final JobMatchReport? match = latestJobMatch;
    final bool hasJobTarget = jobTitle.isNotEmpty ||
        jobDesc.isNotEmpty ||
        (match?.jobTitle.isNotEmpty ?? false);
    final bool hasRag = match != null && match.finalScore >= 0;
    final bool onResults =
        hasAts && (hasRag || cv?.postUploadStep == PostUploadStep.none);

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

    final List<bool> done = <bool>[
      hasUpload,
      hasAts,
      hasJobTarget,
      hasRag,
      hasAts && (hasRag || onResults),
    ];

    showStepProgress = uploading || ragRunning;
    if (uploading) {
      activeStepIndex = 0;
      final int msg = cv?.messageIndex ?? 0;
      progressPercent = ((msg + 1) / CVController.progressMessages.length * 100)
          .round()
          .clamp(5, 95);
      stageTitle = 'Upload CV';
      stageBlurb = CVController.progressMessages[msg];
    } else if (!hasAts) {
      activeStepIndex = 1;
      progressPercent = 40;
      stageTitle = 'ATS check';
      stageBlurb =
          'Running format rules and keyword scan against ${doc.fileName}.';
    } else if (ragRunning) {
      activeStepIndex = 3;
      progressPercent = 55;
      stageTitle = 'Job fit (RAG)';
      stageBlurb =
          'Comparing your CV skills to ${jobTitle.isNotEmpty ? jobTitle : 'the target role'} using the vector knowledge base.';
    } else {
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
          progressPercent = hasJobTarget ? 25 : 0;
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
  }
}
