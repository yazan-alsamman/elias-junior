import 'package:app/common/app_colors.dart';
import 'package:app/common/custom_card.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/job_match_report.dart';
import 'package:app/services/rag_role_mapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Full-screen overlay after a new CV upload: ATS → target job + match.
class PostUploadFlowOverlay extends StatelessWidget {
  const PostUploadFlowOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CVController>(
      builder: (CVController c) {
        if (c.postUploadStep == PostUploadStep.none) {
          return const SizedBox.shrink();
        }
        final CVDocument? doc = c.postUploadDocument;
        if (doc == null) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            child: Stack(
              children: <Widget>[
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: 'Back to dashboard',
                      onPressed: c.finishPostUploadFlow,
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: c.postUploadStep == PostUploadStep.atsReview
                            ? _AtsStepCard(
                                key: const ValueKey<String>('ats'),
                                document: doc,
                                onContinue: c.continueFromAtsToJobStep,
                                onBackToDashboard: c.finishPostUploadFlow,
                              )
                            : _JobStepCard(
                                key: const ValueKey<String>('job'),
                                controller: c,
                                document: doc,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AtsStepCard extends StatelessWidget {
  final CVDocument document;
  final VoidCallback onContinue;
  final VoidCallback onBackToDashboard;

  const _AtsStepCard({
    super.key,
    required this.document,
    required this.onContinue,
    required this.onBackToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 520;
    final ATSCheckReport r = document.report;
    final bool looksGood = r.isPassByScore;
    final String scoreLabel =
        r.isRealAts ? '${r.score}' : (r.isUnavailable ? 'N/A' : '${r.score}');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: CustomCard(
        light: true,
        padding: EdgeInsets.all(narrow ? 16 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fact_check_rounded, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'ATS check',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        document.fileName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: looksGood ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: looksGood ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    looksGood ? Icons.check_circle_outline : Icons.info_outline,
                    color: looksGood ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.suitabilityHeadline.isEmpty
                          ? (looksGood
                              ? 'Looks suitable for typical ATS screening'
                              : 'Consider improving keywords before applying widely')
                          : r.suitabilityHeadline,
                      style: TextStyle(
                        color: looksGood ? const Color(0xFF166534) : const Color(0xFF92400E),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!r.isRealAts) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Text(
                  !r.isRealAts
                      ? 'Not from Uvicorn ATS — restart Node :3003 + ATS :8000, then re-upload this file (old results stay in the database).'
                      : 'ATS format check from Uvicorn rule engine.',
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                _ScoreChip(label: 'ATS score', value: scoreLabel),
                const SizedBox(width: 10),
                _ScoreChip(label: 'Format', value: '${r.formatScore}'),
                const SizedBox(width: 10),
                _ScoreChip(
                  label: r.isRealAts ? 'Decision' : 'Sections',
                  value: r.isRealAts ? r.scoreDecision : r.sectionMatch,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              r.isRealAts ? 'Format issues' : 'Keywords',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.isRealAts
                  ? (r.failedRulesCount > 0
                      ? '${r.failedRulesCount} rule(s) failed'
                      : 'All format rules passed')
                  : '${r.keywordsChecked} / ${r.keywordsTotal} matched in scan',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (r.missingKeywords.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                r.isRealAts ? 'Issues found' : 'Missing or weak keywords',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: r.missingKeywords
                    .map(
                      (String k) => Chip(
                        label: Text(k),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        labelStyle: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (r.recommendations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              const Text(
                'Recommendations',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              ...r.recommendations.map(
                (String line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• ', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w800)),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onBackToDashboard,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue — CV & target job', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: <Widget>[
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobStepCard extends StatelessWidget {
  final CVController controller;
  final CVDocument document;

  const _JobStepCard({
    super.key,
    required this.controller,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 520;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: CustomCard(
        light: true,
        padding: EdgeInsets.all(narrow ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'CV content (preview)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: SelectableText(
                    document.contentPreview.isEmpty
                        ? 'No preview text available for this file.'
                        : document.contentPreview,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: <Widget>[
                Icon(Icons.work_outline, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text(
                  'Target job',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Same idea as the dashboard: tell us what you are applying for so we can judge fit.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            if (narrow) ...<Widget>[
              _LabeledField(
                label: 'Job title',
                hint: 'e.g. Product Manager',
                controller: controller.postJobTitle,
                onChanged: (_) => controller.refreshRagRolePreview(),
              ),
              const SizedBox(height: 12),
              _LabeledField(
                label: 'Company (optional)',
                hint: 'e.g. Google, Meta…',
                controller: controller.postCompany,
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _LabeledField(
                      label: 'Job title',
                      hint: 'e.g. Product Manager',
                      controller: controller.postJobTitle,
                      onChanged: (_) => controller.refreshRagRolePreview(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LabeledField(
                      label: 'Company (optional)',
                      hint: 'e.g. Google, Meta…',
                      controller: controller.postCompany,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Job description / requirements',
              hint: 'Paste the posting so we can compare your CV to it…',
              controller: controller.postJobDescription,
              maxLines: 4,
              onChanged: (_) => controller.refreshRagRolePreview(),
            ),
            if (controller.ragRolePreviewLabel.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.psychology_outlined, color: Color(0xFF0369A1), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'RAG compares your CV skills to: ${controller.ragRolePreviewLabel} '
                        '+ keywords from the job description',
                        style: const TextStyle(
                          color: Color(0xFF0C4A6E),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'KB role (RAG)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: controller.selectedTargetRole,
              decoration: InputDecoration(
                hintText: 'Auto-detect from job title',
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'Auto-detect from job title',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...controller.ragRoleOptions.map(
                  (RagRoleOption o) => DropdownMenuItem<String>(
                    value: o.role,
                    child: Text(o.label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: controller.isComputingJobMatch
                  ? null
                  : (String? v) {
                      controller.selectedTargetRole = v;
                      controller.refreshRagRolePreview();
                    },
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: controller.isComputingJobMatch
                  ? null
                  : () => controller.runTargetJobMatch(),
              icon: controller.isComputingJobMatch
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.compare_arrows_rounded, size: 20),
              label: Text(
                controller.isComputingJobMatch
                    ? 'RAG analyzing…'
                    : 'Check fit (RAG + vector KB)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (controller.jobMatchError != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Text(
                  controller.jobMatchError!,
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (controller.lastJobMatchReport != null) ...<Widget>[
              const SizedBox(height: 16),
              _RagJobMatchPanel(report: controller.lastJobMatchReport!),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: controller.finishPostUploadFlow,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done — back to dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RagJobMatchPanel extends StatelessWidget {
  const _RagJobMatchPanel({required this.report});

  final JobMatchReport report;

  @override
  Widget build(BuildContext context) {
    final bool suitable = report.isSuitable;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: suitable ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: suitable ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: report.finalScore / 100,
                      strokeWidth: 5,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        suitable ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      ),
                    ),
                    Text(
                      '${report.finalScore}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      suitable ? 'Suitable for this role' : 'Gaps vs target role',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.suitabilityHeadline,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    Text(
                      'RAG · ${RagRoleMapper.labelForRole(report.targetRole)} · ${report.specialization}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (report.missingSkills.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Skill gaps',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.missingSkills.take(12).map(
                (String s) => Chip(
                  label: Text(
                    s.replaceAll('_', ' '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: const Color(0xFFFFF7ED),
                  side: const BorderSide(color: Color(0xFFFDBA74)),
                  visualDensity: VisualDensity.compact,
                ),
              ).toList(),
            ),
          ],
          if (report.recommendedCourses.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Recommended courses',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            ...report.recommendedCourses.take(4).map(
              (String c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $c', style: const TextStyle(fontSize: 13, height: 1.35)),
              ),
            ),
          ],
          if (report.retrievedEvidence.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            const Text(
              'KB evidence (vector retrieval)',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              report.retrievedEvidence.first.content.length > 160
                  ? '${report.retrievedEvidence.first.content.substring(0, 160)}…'
                  : report.retrievedEvidence.first.content,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
            ),
          ),
        ),
      ],
    );
  }
}
