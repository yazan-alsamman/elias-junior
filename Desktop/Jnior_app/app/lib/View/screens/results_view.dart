import 'dart:io';
import 'dart:math' as math;

import 'package:app/common/app_colors.dart';
import 'package:app/common/app_navigation.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/ats_template_text.dart';
import 'package:app/common/widgets/aurora_background.dart';
import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/common/widgets/blur_pill.dart';
import 'package:app/common/widgets/empty_state.dart';
import 'package:app/common/widgets/glow_card.dart';
import 'package:app/common/widgets/gradient_button.dart';
import 'package:app/common/widgets/gradient_text.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/results_analysis.dart';
import 'package:app/view/widgets/app_drawer.dart';
import 'package:app/view/widgets/app_side_rail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

/// Results hub: CV summary, optimization chips, skill gaps, and course recommendations.
class ResultsView extends StatelessWidget {
  const ResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CVController>(
      builder: (CVController cv) {
        final double width = MediaQuery.sizeOf(context).width;
        final bool desktop = width >= 980;
        final bool mobile = width < 700;
        final bool stackLayout = width < 900;
        final EdgeInsets contentPad = EdgeInsets.fromLTRB(
          mobile ? AppSpacing.md : AppSpacing.xl,
          mobile ? AppSpacing.md : AppSpacing.lg,
          mobile ? AppSpacing.md : AppSpacing.xl,
          mobile ? AppSpacing.xl : AppSpacing.xxl +
              MediaQuery.paddingOf(context).bottom,
        );
        final CVDocument? doc = cv.latestDocument;
        final ResultsAnalysis analysis = ResultsAnalysis.fromDocument(
          doc,
          jobMatch: cv.jobMatchForDocument(doc) ?? cv.lastJobMatchReport,
        );

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
                    'Results',
                    style: AppType.titleLarge,
                  ),
                  iconTheme: const IconThemeData(
                      color: AuroraDark.textPrimary),
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
              : const AppDrawer(current: AppDrawerPage.results),
          body: AuroraBackground(
            intensity: 0.55,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (desktop)
                    const AppSideRail(current: AppDrawerPage.results),
                  Expanded(
                    child: doc == null
                        ? _EmptyResults(mobile: mobile)
                        : SingleChildScrollView(
                            padding: contentPad,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1280),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _ResultsHeader(mobile: mobile),
                                    SizedBox(height: mobile ? 14 : 22),
                                    if (stackLayout)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          _CvPreviewCard(
                                              analysis: analysis,
                                              mobile: mobile),
                                          if (analysis.atsScore < 65) ...<Widget>[
                                            const SizedBox(
                                                height: AppSpacing.md),
                                            _AtsTemplateCtaCard(
                                                mobile: mobile),
                                          ],
                                          const SizedBox(height: AppSpacing.md),
                                          _OptimizationCard(
                                              analysis: analysis,
                                              mobile: mobile),
                                          const SizedBox(height: AppSpacing.md),
                                          _SkillGapCard(
                                              analysis: analysis,
                                              mobile: mobile),
                                        ],
                                      )
                                    else
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: <Widget>[
                                                _CvPreviewCard(
                                                    analysis: analysis,
                                                    mobile: false),
                                                if (analysis.atsScore <
                                                    65) ...<Widget>[
                                                  const SizedBox(
                                                      height: AppSpacing.md),
                                                  _AtsTemplateCtaCard(
                                                      mobile: false),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.lg),
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: <Widget>[
                                                _OptimizationCard(
                                                    analysis: analysis,
                                                    mobile: false),
                                                const SizedBox(
                                                    height: AppSpacing.md),
                                                _SkillGapCard(
                                                    analysis: analysis,
                                                    mobile: false),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    SizedBox(height: mobile ? 22 : 28),
                                    _CoursesSection(
                                        analysis: analysis, mobile: mobile),
                                  ],
                                ),
                              ),
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
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  final bool mobile;
  const _ResultsHeader({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BlurPill(
          label: 'RESULTS HUB',
          icon: Icons.insights_rounded,
          color: AuroraDark.lime,
          dense: true,
        ),
        AppSpacing.gapSm,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Results ',
                style: mobile
                    ? AppType.headlineLarge
                    : AppType.headlineLarge.copyWith(fontSize: 38),
              ),
              GradientText(
                'Hub',
                style: mobile
                    ? AppType.headlineLarge
                    : AppType.headlineLarge.copyWith(fontSize: 38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Detailed analysis of your CV against market requirements.',
          style: AppType.bodyMedium,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  CV preview + ATS ring chart
// ─────────────────────────────────────────────────────────────────────

class _CvPreviewCard extends StatelessWidget {
  final ResultsAnalysis analysis;
  final bool mobile;

  const _CvPreviewCard({required this.analysis, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.cyanBright,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GradientText(
                'CV preview',
                style: AppType.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                analysis.documentLabel,
                style: AppType.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (analysis.atsScore > 0 ||
                  (analysis.jobFitFromRag && analysis.jobFitScore != null)) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    if (analysis.atsScore > 0)
                      _ScoreRingChart(
                        score: analysis.atsScore,
                        mobile: mobile,
                        label: 'ATS',
                      ),
                    if (analysis.jobFitFromRag && analysis.jobFitScore != null)
                      _ScoreRingChart(
                        score: analysis.jobFitScore!,
                        mobile: mobile,
                        label: 'Job fit',
                      ),
                  ],
                ),
              ],
            ],
          ),
          AppSpacing.gapMd,
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(mobile ? AppSpacing.sm : AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF0E1428),
                  Color(0xFF131A33),
                ],
              ),
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AuroraDark.border),
            ),
            child: analysis.documentLabel.isEmpty
                ? SelectableText(
                    analysis.cvPreviewMarkdown,
                    style: AppType.bodyMedium.copyWith(
                      color: AuroraDark.textSecondary,
                      fontSize: mobile ? 12.5 : 14,
                      height: 1.55,
                    ),
                  )
                : SelectionArea(
                    child: _CvPreviewStyledBody(
                      raw: analysis.cvPreviewMarkdown,
                      mobile: mobile,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Animated radial ring chart (0 → score on entry).
class _ScoreRingChart extends StatelessWidget {
  final int score;
  final bool mobile;
  final String label;

  const _ScoreRingChart({
    required this.score,
    required this.mobile,
    this.label = 'ATS',
  });

  Color get _color => score >= 75
      ? AuroraDark.lime
      : score >= 50
          ? AuroraDark.amber
          : AuroraDark.danger;

  @override
  Widget build(BuildContext context) {
    final double stroke = mobile ? 7.0 : 9.0;
    final double size = mobile ? 84 : 110;
    final double pad = stroke + 2;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double v, _) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(pad),
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: v,
                    color: _color,
                    trackColor: AuroraDark.surfaceHigh,
                    strokeWidth: stroke,
                  ),
                  size: Size.square(size - pad * 2),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    (v * 100).round().toString(),
                    style: AppType.headlineMedium.copyWith(
                      color: AuroraDark.textPrimary,
                      fontSize: mobile ? 22 : 28,
                    ),
                  ),
                  Text(
                    label,
                    style: AppType.labelSmall.copyWith(color: _color),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - strokeWidth;

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(c, r, track);

    if (progress <= 0) {
      canvas.restore();
      return;
    }

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + progress * 2 * math.pi,
        colors: <Color>[
          color,
          AuroraDark.cyanBright,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      arc,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _CvPreviewStyledBody extends StatelessWidget {
  final String raw;
  final bool mobile;

  const _CvPreviewStyledBody({required this.raw, required this.mobile});

  static const Set<String> _sectionHeaders = <String>{
    'PROFESSIONAL SUMMARY',
    'WORK EXPERIENCE',
    'EDUCATION',
    'SKILLS',
  };

  static bool _isSectionHeader(String line) =>
      _sectionHeaders.contains(line.trim());

  static bool _isBulletLine(String line) {
    final String t = line.trimLeft();
    if (t.startsWith('•') || t.startsWith('·')) return true;
    return t.startsWith('- ') || t == '-';
  }

  static bool _isEmphasisLine(String line) {
    if (_isBulletLine(line)) return false;
    final String t = line.trim();
    return t.contains('—') || t.contains('–') || RegExp(r'\s-\s').hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    final List<String> lines = raw.split('\n');
    bool pendingSkills = false;
    bool firstSection = true;

    for (int i = 0; i < lines.length; i++) {
      final String trimmed = lines[i].trim();
      if (trimmed.isEmpty) {
        children.add(SizedBox(height: mobile ? 6 : 8));
        continue;
      }
      if (_isSectionHeader(trimmed)) {
        pendingSkills = trimmed == 'SKILLS';
        children.add(_CvSectionHeader(
            text: trimmed, mobile: mobile, isFirst: firstSection));
        firstSection = false;
        continue;
      }
      if (pendingSkills) {
        pendingSkills = false;
        if (trimmed.contains(',')) {
          children.add(_CvSkillsWrap(text: trimmed, mobile: mobile));
        } else {
          children.add(_CvBodyLine(text: trimmed, mobile: mobile));
        }
        continue;
      }
      if (_isBulletLine(trimmed)) {
        children.add(_CvBulletLine(text: trimmed, mobile: mobile));
      } else if (_isEmphasisLine(trimmed)) {
        children.add(_CvEmphasisLine(text: trimmed, mobile: mobile));
      } else {
        children.add(_CvBodyLine(text: trimmed, mobile: mobile));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _CvSectionHeader extends StatelessWidget {
  final String text;
  final bool mobile;
  final bool isFirst;

  const _CvSectionHeader({
    required this.text,
    required this.mobile,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : (mobile ? 12 : 14),
        bottom: mobile ? 6 : 8,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: mobile ? 18 : 20,
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: BorderRadius.circular(2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AuroraDark.violet.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          SizedBox(width: mobile ? 10 : 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AuroraDark.cyanBright,
                fontWeight: FontWeight.w800,
                fontSize: mobile ? 11.5 : 12.5,
                letterSpacing: 1.2,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CvEmphasisLine extends StatelessWidget {
  final String text;
  final bool mobile;
  const _CvEmphasisLine({required this.text, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: mobile ? 4 : 6, bottom: mobile ? 2 : 4),
      child: Text(
        text,
        style: AppType.titleSmall.copyWith(
          color: AuroraDark.textPrimary,
          fontSize: mobile ? 13 : 14,
        ),
      ),
    );
  }
}

class _CvBodyLine extends StatelessWidget {
  final String text;
  final bool mobile;
  const _CvBodyLine({required this.text, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: mobile ? 6 : 8),
      child: Text(
        text,
        style: AppType.bodyMedium.copyWith(
          color: AuroraDark.textSecondary,
          fontSize: mobile ? 12.5 : 14,
          height: 1.55,
        ),
      ),
    );
  }
}

class _CvBulletLine extends StatelessWidget {
  final String text;
  final bool mobile;
  const _CvBulletLine({required this.text, required this.mobile});

  String get _body {
    String s = text.trimLeft();
    if (s.startsWith('•')) {
      s = s.substring(1);
    } else if (s.startsWith('·')) {
      s = s.substring(1);
    } else if (s.startsWith('- ')) {
      s = s.substring(2);
    } else if (s.startsWith('-')) {
      s = s.substring(1);
    }
    return s.trimLeft();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: mobile ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: mobile ? 7 : 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuroraDark.lime,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AuroraDark.lime.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: mobile ? 10 : 12),
          Expanded(
            child: Text(
              _body,
              style: AppType.bodyMedium.copyWith(
                color: AuroraDark.textPrimary,
                fontSize: mobile ? 12.5 : 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CvSkillsWrap extends StatelessWidget {
  final String text;
  final bool mobile;
  const _CvSkillsWrap({required this.text, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final List<String> parts = text
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: mobile ? 4 : 6),
      child: Wrap(
        spacing: mobile ? 8 : 10,
        runSpacing: mobile ? 8 : 10,
        children: parts
            .map((String skill) => BlurPill(
                  label: skill,
                  color: AuroraDark.cyanBright,
                  dense: mobile,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  ATS template CTA + sheet
// ─────────────────────────────────────────────────────────────────────

class _AtsTemplateCtaCard extends StatelessWidget {
  final bool mobile;
  const _AtsTemplateCtaCard({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.amber,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.description_rounded,
                color: AuroraDark.amber,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CV template (good for ATS)',
                  style: AppType.titleLarge.copyWith(
                      fontSize: mobile ? 15 : 17),
                ),
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            'If your ATS score looks weak, use this outline — open it, edit, then export as PDF.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          GradientButton(
            label: 'View & download template',
            icon: Icons.download_rounded,
            fullWidth: true,
            gradient: const LinearGradient(
              colors: <Color>[AuroraDark.amber, AuroraDark.pink],
            ),
            glowColor: AuroraDark.amber,
            onPressed: () => _showAtsTemplateSheet(context),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAtsTemplateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AuroraDark.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext ctx) {
      final bool narrow = MediaQuery.sizeOf(ctx).width < 400;
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.paddingOf(ctx).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuroraDark.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppSpacing.gapMd,
            Row(
              children: <Widget>[
                Expanded(
                  child: GradientText(
                    'ATS-friendly CV template',
                    style: AppType.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            AppSpacing.gapXs,
            Text(
              'Copy this structure into your own file. Download saves a .txt you can edit.',
              style: AppType.bodyMedium,
            ),
            AppSpacing.gapMd,
            SizedBox(
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.surfaceTint,
                  borderRadius: AppRadii.rMd,
                  border: Border.all(color: AuroraDark.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      AtsTemplateText.body,
                      style: AppType.bodyMedium.copyWith(
                        color: AuroraDark.textSecondary,
                        fontSize: narrow ? 12 : 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AppSpacing.gapMd,
            GradientButton(
              label: 'Download',
              icon: Icons.download_rounded,
              fullWidth: true,
              onPressed: () async {
                try {
                  final Directory dir =
                      await getApplicationDocumentsDirectory();
                  final File f = File(
                      '${dir.path}/ats_friendly_cv_template.txt');
                  await f.writeAsString(AtsTemplateText.body);
                  if (!ctx.mounted) return;
                  AuroraSnack.success('Saved', f.path);
                } catch (e) {
                  if (!ctx.mounted) return;
                  AuroraSnack.error('Download', 'Could not save: $e');
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────
//  Optimization
// ─────────────────────────────────────────────────────────────────────

class _OptimizationCard extends StatelessWidget {
  final ResultsAnalysis analysis;
  final bool mobile;
  const _OptimizationCard({required this.analysis, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.violet,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.tips_and_updates_rounded,
                  color: AuroraDark.violet, size: 22),
              AppSpacing.gapXs,
              Expanded(
                child: GradientText(
                  'Critical optimization',
                  style: AppType.headlineSmall,
                ),
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            analysis.suitabilityHeadline.isNotEmpty
                ? analysis.suitabilityHeadline
                : 'Strengths to keep highlighting vs. skills to add for your target roles.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          Text(
            'Aligned with your CV',
            style: AppType.labelMedium.copyWith(color: AuroraDark.lime),
          ),
          AppSpacing.gapXs,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: analysis.strengths
                .map((String s) => _ChipPill(
                      label: s,
                      positive: true,
                      compact: mobile,
                    ))
                .toList(),
          ),
          AppSpacing.gapMd,
          Text(
            'Market gaps to close',
            style: AppType.labelMedium.copyWith(color: AuroraDark.danger),
          ),
          AppSpacing.gapXs,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: analysis.gaps
                .map((String s) => _ChipPill(
                      label: s,
                      positive: false,
                      compact: mobile,
                    ))
                .toList(),
          ),
          if (analysis.recommendations.isNotEmpty) ...<Widget>[
            AppSpacing.gapMd,
            Text(
              'ATS recommendations',
              style: AppType.labelMedium.copyWith(color: AuroraDark.cyanBright),
            ),
            AppSpacing.gapXs,
            ...analysis.recommendations.take(5).map(
                  (String tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: AuroraDark.cyanBright,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppType.bodyMedium.copyWith(
                              color: AuroraDark.textSecondary,
                              fontSize: mobile ? 12.5 : 13.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String label;
  final bool positive;
  final bool compact;

  const _ChipPill({
    required this.label,
    required this.positive,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = positive ? AuroraDark.lime : AuroraDark.danger;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            positive ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: compact ? 14 : 16,
            color: color,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Skill gaps
// ─────────────────────────────────────────────────────────────────────

class _SkillGapCard extends StatelessWidget {
  final ResultsAnalysis analysis;
  final bool mobile;
  const _SkillGapCard({required this.analysis, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.lime,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GradientText(
            'Skill gap analysis',
            style: AppType.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Scores out of 100 — your CV strength vs typical market demand per skill.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          ...analysis.skillGaps.map(
            (SkillGapEntry e) => Padding(
              padding: EdgeInsets.only(bottom: mobile ? 12 : 14),
              child: _DualSkillBar(entry: e, mobile: mobile),
            ),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const <Widget>[
              _LegendDot(color: AuroraDark.lime, label: 'Your skills'),
              _LegendDot(color: AuroraDark.cyanBright, label: 'Market demand'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.7),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        AppSpacing.gapXs,
        Text(label, style: AppType.bodySmall),
      ],
    );
  }
}

class _DualSkillBar extends StatelessWidget {
  final SkillGapEntry entry;
  final bool mobile;
  const _DualSkillBar({required this.entry, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final double your = (entry.proficiencyScore / 100).clamp(0.0, 1.0);
    final double market = (entry.marketDemand / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                entry.name,
                style: AppType.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.proficiencyScore} / ${entry.marketDemand}',
              style: AppType.labelMedium.copyWith(
                color: AuroraDark.textSecondary,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double t, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: mobile ? 12 : 14,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const ColoredBox(color: AuroraDark.surfaceHigh),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: market * t,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AuroraDark.cyanBright
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: your * t,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[
                                AuroraDark.lime,
                                AuroraDark.success,
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AuroraDark.lime.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Courses
// ─────────────────────────────────────────────────────────────────────

class _CoursesSection extends StatelessWidget {
  final ResultsAnalysis analysis;
  final bool mobile;
  const _CoursesSection({required this.analysis, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.menu_book_rounded,
                color: AuroraDark.cyanBright, size: 26),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GradientText(
                    'Recommended courses',
                    style: mobile
                        ? AppType.headlineSmall
                        : AppType.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on your skill gaps — curated picks to boost CV and interview readiness.',
                    style: AppType.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        AppSpacing.gapLg,
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double w = c.maxWidth;
            final int cols = w >= 1200 ? 3 : (w >= 720 ? 2 : 1);
            const double gap = 14;
            if (cols == 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List<Widget>.generate(analysis.courses.length, (int i) {
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i == analysis.courses.length - 1 ? 0 : gap),
                    child:
                        _CourseCard(course: analysis.courses[i], mobile: mobile),
                  );
                }),
              );
            }
            final double tileW = (w - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: analysis.courses
                  .map(
                    (CourseRecommendation course) => SizedBox(
                      width: tileW,
                      child: _CourseCard(course: course, mobile: mobile),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CourseCard extends StatefulWidget {
  final CourseRecommendation course;
  final bool mobile;
  const _CourseCard({required this.course, required this.mobile});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _hover = false;

  void _onOpen(BuildContext context) {
    AuroraSnack.info(
      widget.course.platform,
      'Open “${widget.course.title}” on ${widget.course.platform}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _onOpen(context),
        child: AnimatedContainer(
          duration: AppDurations.short,
          curve: AppCurves.standard,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            gradient: AppGradients.surfaceTint,
            borderRadius: AppRadii.rLg,
            border: Border.all(
              color: _hover
                  ? AuroraDark.cyanBright.withValues(alpha: 0.5)
                  : AuroraDark.border,
            ),
            boxShadow: _hover
                ? <BoxShadow>[
                    BoxShadow(
                      color: AuroraDark.cyan.withValues(alpha: 0.32),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 5,
                  decoration: const BoxDecoration(gradient: AppGradients.brand),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.mobile ? 14 : 16,
                      widget.mobile ? 14 : 18,
                      widget.mobile ? 14 : 16,
                      widget.mobile ? 14 : 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        BlurPill(
                          label: widget.course.category,
                          color: AuroraDark.cyanBright,
                          dense: widget.mobile,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.course.title,
                          style: AppType.titleLarge.copyWith(
                            fontSize: widget.mobile ? 16 : 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.school_outlined,
                              size: 16,
                              color: AuroraDark.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.course.platform,
                                style: AppType.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapMd,
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.star_rounded,
                                    color: AuroraDark.amber, size: 18),
                                Text(
                                  widget.course.rating.toStringAsFixed(1),
                                  style: AppType.titleSmall.copyWith(
                                    color: AuroraDark.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            BlurPill(
                              label: widget.course.durationLabel,
                              color: AuroraDark.textMuted,
                              dense: true,
                            ),
                            TextButton.icon(
                              onPressed: () => _onOpen(context),
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 16),
                              label: const Text('View'),
                              style: TextButton.styleFrom(
                                foregroundColor: AuroraDark.cyanBright,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Empty
// ─────────────────────────────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  final bool mobile;
  const _EmptyResults({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(mobile ? 20 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: EmptyState(
            icon: Icons.description_rounded,
            title: 'No CV to analyze yet',
            message:
                'Upload a CV from your dashboard to unlock skill gaps, optimization tips, and personalized course picks.',
            actionLabel: 'Go to dashboard',
            onAction: AppNavigation.toDashboard,
          ),
        ),
      ),
    );
  }
}
