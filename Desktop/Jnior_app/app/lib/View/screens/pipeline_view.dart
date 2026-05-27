import 'package:app/common/app_colors.dart';
import 'package:app/common/app_navigation.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/widgets/animated_counter.dart';
import 'package:app/common/widgets/aurora_background.dart';
import 'package:app/common/widgets/blur_pill.dart';
import 'package:app/common/widgets/glow_card.dart';
import 'package:app/common/widgets/gradient_button.dart';
import 'package:app/common/widgets/gradient_text.dart';
import 'package:app/common/widgets/skeleton.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/controller/pipeline_controller.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:app/model/job_match_report.dart';
import 'package:app/view/widgets/app_drawer.dart';
import 'package:app/view/widgets/app_side_rail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PipelineView extends StatelessWidget {
  const PipelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CVController>(
      builder: (CVController cv) {
        return GetBuilder<PipelineController>(
          builder: (PipelineController controller) {
            final double width = MediaQuery.of(context).size.width;
            final bool desktop = width >= 980;
            return Scaffold(
          backgroundColor: AuroraDark.bg,
          extendBodyBehindAppBar: true,
          appBar: desktop
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  centerTitle: true,
                  leading: IconButton(
                    tooltip: 'Back to Dashboard',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: AppNavigation.toDashboard,
                  ),
                  title: GradientText(
                    'Pipeline',
                    style: AppType.titleLarge,
                  ),
                  iconTheme:
                      const IconThemeData(color: AuroraDark.textPrimary),
                  actions: <Widget>[
                    IconButton(
                      tooltip: 'Log out',
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: AppNavigation.logout,
                    ),
                    Builder(
                      builder: (BuildContext context) => IconButton(
                        tooltip: 'Menu',
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  ],
                ),
          drawer: desktop
              ? null
              : const AppDrawer(current: AppDrawerPage.pipeline),
          body: AuroraBackground(
            intensity: 0.55,
            child: SafeArea(
              child: Row(
                children: <Widget>[
                  if (desktop)
                    const AppSideRail(current: AppDrawerPage.pipeline),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        width < 700 ? AppSpacing.md : AppSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (desktop) AppSpacing.gapSm,
                          if (cv.documents.isNotEmpty)
                            _PipelineCvPicker(
                              documents: cv.documents,
                              selectedId: controller.focusedDocumentId,
                              isUploading: cv.isUploading,
                              uploadFileName: cv.lastUploadFileName,
                              onSelected: controller.selectDocument,
                            ),
                          if (cv.documents.isNotEmpty) AppSpacing.gapMd,
                          _PipelineHeader(
                            mobile: width < 700,
                            subtitle: controller.isLoading
                                ? 'Your CV is being analyzed through our AI engine.'
                                : controller.stageBlurb,
                          ),
                          AppSpacing.gapLg,
                          controller.isLoading
                              ? const _PipelineSkeleton()
                              : _PipelineContent(
                                  controller: controller,
                                  report: controller.latestReport,
                                  narrowContent: width < 700,
                                  useVerticalStepper: width < 900,
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }
}

class _PipelineCvPicker extends StatelessWidget {
  final List<CVDocument> documents;
  final String? selectedId;
  final bool isUploading;
  final String? uploadFileName;
  final ValueChanged<String?> onSelected;

  const _PipelineCvPicker({
    required this.documents,
    required this.selectedId,
    required this.isUploading,
    required this.uploadFileName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<CVDocument> sorted = List<CVDocument>.from(documents)
      ..sort((CVDocument a, CVDocument b) =>
          b.uploadedAt.compareTo(a.uploadedAt));

    return GlowCard(
      glowColor: AuroraDark.cyanBright,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.description_outlined,
              color: AuroraDark.cyanBright, size: 20),
          AppSpacing.gapSm,
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: isUploading ? null : (selectedId ?? sorted.first.id),
                dropdownColor: AuroraDark.surfaceHigh,
                style: AppType.bodyMedium.copyWith(color: AuroraDark.textPrimary),
                items: <DropdownMenuItem<String?>>[
                  if (isUploading && uploadFileName != null)
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'Live: uploading $uploadFileName…',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ...sorted.map(
                    (CVDocument d) => DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(
                        '${d.fileName} · ATS ${d.report.score}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onSelected,
              ),
            ),
          ),
          if (isUploading) ...<Widget>[
            AppSpacing.gapSm,
            const PulsingDot(color: AuroraDark.lime),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────────────────────────────

class _PipelineHeader extends StatelessWidget {
  final bool mobile;
  final String subtitle;
  const _PipelineHeader({required this.mobile, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            BlurPill(
              label: 'PROCESSING',
              icon: Icons.bolt_rounded,
              color: AuroraDark.violet,
              dense: true,
            ),
            const SizedBox(width: 8),
            const PulsingDot(color: AuroraDark.lime),
            Text(
              'Live',
              style: AppType.labelSmall.copyWith(
                color: AuroraDark.lime,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        AppSpacing.gapSm,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Processing ',
                style: mobile
                    ? AppType.headlineLarge
                    : AppType.headlineLarge
                        .copyWith(fontSize: 40, height: 1.1),
              ),
              GradientText(
                'Pipeline',
                style: mobile
                    ? AppType.headlineLarge
                    : AppType.headlineLarge
                        .copyWith(fontSize: 40, height: 1.1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppType.bodyMedium,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Content
// ─────────────────────────────────────────────────────────────────────

class _PipelineContent extends StatelessWidget {
  final PipelineController controller;
  final ATSCheckReport? report;
  final bool narrowContent;
  final bool useVerticalStepper;

  const _PipelineContent({
    required this.controller,
    required this.report,
    required this.narrowContent,
    required this.useVerticalStepper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GlowCard(
          glowColor: AuroraDark.violet,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _PipelineStepper(
            steps: controller.steps,
            activeStepIndex: controller.activeStepIndex,
            progressPercent: controller.progressPercent,
            showStepProgress: controller.showStepProgress,
            useVerticalTimeline: useVerticalStepper,
          ),
        ),
        AppSpacing.gapLg,
        GlowCard(
          glowColor: AuroraDark.cyanBright,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _StageDetailsCard(
            report: report,
            jobMatch: controller.latestJobMatch,
            stageTitle: controller.stageTitle,
            stageBlurb: controller.stageBlurb,
            activeStepIndex: controller.activeStepIndex,
            onRefresh: controller.fetchPipelineData,
            mobile: narrowContent,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Stepper
// ─────────────────────────────────────────────────────────────────────

class _PipelineStepper extends StatelessWidget {
  final List<PipelineStepInfo> steps;
  final int activeStepIndex;
  final int progressPercent;
  final bool showStepProgress;
  final bool useVerticalTimeline;

  const _PipelineStepper({
    required this.steps,
    required this.activeStepIndex,
    required this.progressPercent,
    required this.showStepProgress,
    required this.useVerticalTimeline,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    if (useVerticalTimeline) {
      return _VerticalPipelineTimeline(
        steps: steps,
        activeStepIndex: activeStepIndex,
        progressPercent: progressPercent,
        showStepProgress: showStepProgress,
      );
    }
    return _HorizontalPipelineStepper(
      steps: steps,
      activeStepIndex: activeStepIndex,
      progressPercent: progressPercent,
      showStepProgress: showStepProgress,
    );
  }
}

class _VerticalPipelineTimeline extends StatelessWidget {
  final List<PipelineStepInfo> steps;
  final int activeStepIndex;
  final int progressPercent;
  final bool showStepProgress;

  const _VerticalPipelineTimeline({
    required this.steps,
    required this.activeStepIndex,
    required this.progressPercent,
    required this.showStepProgress,
  });

  static const double _connectorHeight = 36;
  static const double _lineWidth = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List<Widget>.generate(steps.length, (int i) {
        final PipelineStepInfo step = steps[i];
        final bool done = i < activeStepIndex;
        final bool active =
            i == activeStepIndex && activeStepIndex < steps.length;
        final bool showProgress = showStepProgress && active;
        final bool isLast = i == steps.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _StepDot(done: done, active: active, icon: step.icon),
                  if (!isLast)
                    Container(
                      width: _lineWidth,
                      height: _connectorHeight,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            done
                                ? AuroraDark.lime
                                : AuroraDark.borderStrong,
                            done
                                ? AuroraDark.lime.withValues(alpha: 0.4)
                                : AuroraDark.border,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StepBody(
                  label: step.title,
                  sub: step.subtitle,
                  showProgress: showProgress,
                  progressPercent: progressPercent,
                  alignCenter: false,
                  active: active,
                  done: done,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _HorizontalPipelineStepper extends StatelessWidget {
  final List<PipelineStepInfo> steps;
  final int activeStepIndex;
  final int progressPercent;
  final bool showStepProgress;

  const _HorizontalPipelineStepper({
    required this.steps,
    required this.activeStepIndex,
    required this.progressPercent,
    required this.showStepProgress,
  });

  static const double _stepWidth = 140;
  static const double _barWidth = 28;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(steps.length, (int i) {
          final PipelineStepInfo step = steps[i];
          final bool done = i < activeStepIndex;
          final bool active =
              i == activeStepIndex && activeStepIndex < steps.length;
          final bool showProgress = showStepProgress && active;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: _stepWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _StepDot(done: done, active: active, icon: step.icon),
                    AppSpacing.gapXs,
                    _StepBody(
                      label: step.title,
                      sub: step.subtitle,
                      showProgress: showProgress,
                      progressPercent: progressPercent,
                      alignCenter: true,
                      active: active,
                      done: done,
                    ),
                  ],
                ),
              ),
              if (i != steps.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Container(
                    width: _barWidth,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          i < activeStepIndex
                              ? AuroraDark.lime
                              : AuroraDark.borderStrong,
                          i + 1 < activeStepIndex
                              ? AuroraDark.lime
                              : (i + 1 == activeStepIndex
                                  ? AuroraDark.violet
                                  : AuroraDark.border),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatefulWidget {
  final bool done;
  final bool active;
  final IconData icon;

  const _StepDot({
    required this.done,
    required this.active,
    required this.icon,
  });

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StepDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon = widget.done ? Icons.check_rounded : widget.icon;
    final Color iconColor = widget.done || widget.active
        ? Colors.white
        : AuroraDark.textMuted;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, _) {
        final double t = _pulse.value;
        return SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: widget.done
                    ? const LinearGradient(
                        colors: <Color>[AuroraDark.lime, AuroraDark.success],
                      )
                    : widget.active
                        ? AppGradients.brand
                        : null,
                color: widget.done || widget.active
                    ? null
                    : AuroraDark.surfaceHigh,
                borderRadius: BorderRadius.circular(widget.active ? 12 : 19),
                border: Border.all(
                  color: widget.done || widget.active
                      ? Colors.transparent
                      : AuroraDark.border,
                ),
                boxShadow: <BoxShadow>[
                  if (widget.done)
                    BoxShadow(
                      color: AuroraDark.lime.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  if (widget.active)
                    BoxShadow(
                      color: AuroraDark.violet.withValues(alpha: 0.25 + 0.2 * t),
                      blurRadius: 10 + 4 * t,
                      spreadRadius: -2,
                    ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ),
        );
      },
    );
  }
}

class _StepBody extends StatelessWidget {
  final String label;
  final String sub;
  final bool showProgress;
  final int progressPercent;
  final bool alignCenter;
  final bool active;
  final bool done;

  const _StepBody({
    required this.label,
    required this.sub,
    required this.showProgress,
    required this.progressPercent,
    required this.alignCenter,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final TextAlign ta = alignCenter ? TextAlign.center : TextAlign.start;
    final Color labelColor = active
        ? AuroraDark.textPrimary
        : (done ? AuroraDark.textPrimary : AuroraDark.textSecondary);

    return Column(
      crossAxisAlignment:
          alignCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          textAlign: ta,
          style: AppType.titleSmall.copyWith(color: labelColor),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          textAlign: ta,
          style: AppType.bodySmall,
        ),
        if (showProgress) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            width: alignCenter ? 120 : double.infinity,
            child: Column(
              crossAxisAlignment: alignCenter
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.stretch,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        const ColoredBox(color: AuroraDark.surfaceAlt),
                        FractionallySizedBox(
                          widthFactor:
                              (progressPercent / 100).clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppGradients.brand,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: AuroraDark.violet
                                      .withValues(alpha: 0.6),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$progressPercent%',
                  textAlign: ta,
                  style: AppType.labelSmall.copyWith(
                    color: AuroraDark.cyanBright,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Stage details
// ─────────────────────────────────────────────────────────────────────

class _StageDetailsCard extends StatelessWidget {
  final ATSCheckReport? report;
  final JobMatchReport? jobMatch;
  final String stageTitle;
  final String stageBlurb;
  final int activeStepIndex;
  final VoidCallback onRefresh;
  final bool mobile;

  const _StageDetailsCard({
    required this.report,
    required this.jobMatch,
    required this.stageTitle,
    required this.stageBlurb,
    required this.activeStepIndex,
    required this.onRefresh,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final ATSCheckReport data = report ??
        ATSCheckReport(
          score: 0,
          status: 'Pending',
          checkedAt: DateTime.now(),
          keywordsChecked: 0,
          keywordsTotal: 0,
          formatScore: 0,
          sectionMatch: '0/0',
          estimatedSecondsLeft: 0,
        );
    final JobMatchReport? match = jobMatch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: GradientText(
                'Current stage: $stageTitle',
                style: AppType.headlineSmall,
              ),
            ),
            BlurPill(
              label: data.status.toUpperCase(),
              icon: Icons.flash_on_rounded,
              color: AuroraDark.cyanBright,
              dense: true,
            ),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          stageBlurb,
          style: AppType.bodyMedium,
        ),
        AppSpacing.gapMd,
        GridView.count(
          crossAxisCount: mobile ? 2 : 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: mobile ? 1.7 : 1.95,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: <Widget>[
            _MetricBox(
              numericValue: data.score,
              suffix: '/100',
              label: 'ATS score',
              icon: Icons.bar_chart_rounded,
              accent: AuroraDark.cyanBright,
            ),
            if (match != null)
              _MetricBox(
                numericValue: match.finalScore,
                suffix: '%',
                label: 'Job fit',
                icon: Icons.compare_arrows_rounded,
                accent: AuroraDark.lime,
              )
            else
              _MetricBox(
                numericValue: data.formatScore,
                suffix: '%',
                label: 'Format score',
                icon: Icons.format_align_left_rounded,
                accent: AuroraDark.lime,
              ),
            _MetricBox(
              numericValue: data.keywordsChecked,
              suffix: '/${data.keywordsTotal}',
              label: 'Keywords',
              icon: Icons.key_rounded,
              accent: AuroraDark.violet,
            ),
            _MetricBox(
              text: match != null && match.missingSkills.isNotEmpty
                  ? '${match.missingSkills.length} gaps'
                  : data.sectionMatch,
              label: match != null ? 'Skill gaps' : 'Sections',
              icon: Icons.view_agenda_rounded,
              accent: AuroraDark.pink,
            ),
          ],
        ),
        AppSpacing.gapMd,
        Align(
          alignment: Alignment.centerRight,
          child: GradientButton(
            label: 'Refresh Pipeline',
            icon: Icons.refresh_rounded,
            onPressed: onRefresh,
            size: GradientButtonSize.medium,
          ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatefulWidget {
  final int? numericValue;
  final String? text;
  final String prefix;
  final String suffix;
  final String label;
  final IconData icon;
  final Color accent;

  const _MetricBox({
    this.numericValue,
    this.text,
    this.prefix = '',
    this.suffix = '',
    required this.label,
    required this.icon,
    required this.accent,
  });

  @override
  State<_MetricBox> createState() => _MetricBoxState();
}

class _MetricBoxState extends State<_MetricBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppDurations.short,
        curve: AppCurves.standard,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          gradient: AppGradients.surfaceTint,
          borderRadius: AppRadii.rMd,
          border: Border.all(
            color: _hover
                ? widget.accent.withValues(alpha: 0.5)
                : AuroraDark.border,
          ),
          boxShadow: _hover
              ? <BoxShadow>[
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.16),
                borderRadius: AppRadii.rXs,
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(widget.icon, size: 14, color: widget.accent),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: widget.numericValue != null
                      ? AnimatedCounter(
                          value: widget.numericValue!,
                          prefix: widget.prefix,
                          suffix: widget.suffix,
                          style: AppType.headlineSmall.copyWith(
                            color: AuroraDark.textPrimary,
                          ),
                        )
                      : Text(
                          '${widget.prefix}${widget.text}${widget.suffix}',
                          style: AppType.headlineSmall.copyWith(
                            color: AuroraDark.textPrimary,
                          ),
                        ),
                ),
                Text(
                  widget.label,
                  style: AppType.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineSkeleton extends StatelessWidget {
  const _PipelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SkeletonCard(height: 200),
        AppSpacing.gapMd,
        const SkeletonCard(height: 260),
      ],
    );
  }
}
