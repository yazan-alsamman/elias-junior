import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:app/common/app_colors.dart';
import 'package:app/common/app_navigation.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/widgets/animated_counter.dart';
import 'package:app/common/widgets/aurora_background.dart';
import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/common/widgets/blur_pill.dart';
import 'package:app/common/widgets/dev_api_banner.dart';
import 'package:app/common/widgets/empty_state.dart';
import 'package:app/common/widgets/glow_card.dart';
import 'package:app/common/widgets/gradient_button.dart';
import 'package:app/common/widgets/gradient_text.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/view/widgets/app_drawer.dart';
import 'package:app/view/widgets/app_side_rail.dart';
import 'package:app/view/widgets/compare_cv_dialog.dart';
import 'package:app/view/widgets/post_upload_flow.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CVController>(
      builder: (CVController controller) {
        final bool desktop = MediaQuery.sizeOf(context).width >= 980;
        final EdgeInsets viewPad = MediaQuery.paddingOf(context);
        final double appBarH =
            Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;
        // Body draws behind the transparent AppBar on phone; push content below it.
        final double topScroll = desktop
            ? AppSpacing.lg
            : viewPad.top + appBarH + AppSpacing.md;
        final EdgeInsets scrollPadding = EdgeInsets.fromLTRB(
          desktop ? AppSpacing.xl : AppSpacing.md,
          topScroll,
          desktop ? AppSpacing.xl : AppSpacing.md,
          desktop ? AppSpacing.xl : 24 + viewPad.bottom,
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
                  title: GradientText(
                    'CareerPath AI',
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
              : const AppDrawer(current: AppDrawerPage.dashboard),
          body: AuroraBackground(
            intensity: 0.55,
            child: Stack(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (desktop)
                      const AppSideRail(current: AppDrawerPage.dashboard),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: scrollPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (desktop) AppSpacing.gapSm,
                            const DevApiBanner(),
                            const _DashboardHero(),
                            AppSpacing.gapXl,
                            _StatsRow(controller: controller),
                            AppSpacing.gapLg,
                            const _TargetJobSection(),
                            AppSpacing.gapLg,
                            _CVWorkspaceSection(
                                controller: controller, desktop: desktop),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (controller.isUploading)
                  Positioned.fill(
                    child: _UploadOverlay(
                      message: CVController
                          .progressMessages[controller.messageIndex],
                    ),
                  ),
                const PostUploadFlowOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Hero
// ─────────────────────────────────────────────────────────────────────

class _DashboardHero extends StatefulWidget {
  const _DashboardHero();

  @override
  State<_DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends State<_DashboardHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _avatar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _avatar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthApiService auth = Get.find<AuthApiService>();
    final String? firstName =
        AuthApiService.formatFirstName(auth.userFullName);
    final String greetingName = firstName ?? 'Guest';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              BlurPill(
                label: 'AI · CAREER INTELLIGENCE',
                icon: Icons.bolt_rounded,
                color: AuroraDark.cyanBright,
              ),
              AppSpacing.gapMd,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Hello,',
                    style: AppType.headlineMedium,
                  ),
                  AppSpacing.gapXs,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: GradientText(
                      '$greetingName 👋',
                      style: AppType.headlineLarge,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              Text(
                'Your career optimization workspace is ready.',
                style: AppType.bodyMedium,
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _avatar,
          builder: (BuildContext context, _) {
            return _OrbitAvatar(
              t: _avatar.value,
              initial:
                  greetingName.isNotEmpty ? greetingName[0].toUpperCase() : '?',
            );
          },
        ),
      ],
    );
  }
}

class _OrbitAvatar extends StatelessWidget {
  const _OrbitAvatar({required this.t, required this.initial});
  final double t;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: CustomPaint(
        painter: _AvatarHaloPainter(t: t),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
              boxShadow: AppNeon.violet,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: AppType.headlineMedium.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarHaloPainter extends CustomPainter {
  _AvatarHaloPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - 4;
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = const SweepGradient(
        colors: <Color>[
          AuroraDark.cyanBright,
          AuroraDark.violet,
          Colors.transparent,
          AuroraDark.cyanBright,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 2 * math.pi);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawCircle(c, r, p);
    canvas.restore();

    // Bright dot orbiting.
    final double angle = t * 2 * math.pi;
    final Offset dot = Offset(c.dx + r * math.cos(angle),
        c.dy + r * math.sin(angle));
    final Paint glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..color = AuroraDark.cyanBright;
    canvas.drawCircle(dot, 3, glow);
    canvas.drawCircle(dot, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AvatarHaloPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────
//  Stats
// ─────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final CVController controller;
  const _StatsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    final int avg = controller.avgAtsScore;
    final double screenW = MediaQuery.sizeOf(context).width;
    final bool stackVertical = screenW < 720;

    final List<Widget> cards = <Widget>[
      _StatCard(
        title: 'CVs Analyzed',
        value: controller.cvsAnalyzed,
        suffix: '',
        trend: '+3 this week',
        icon: Icons.description_rounded,
        accent: AuroraDark.cyanBright,
      ),
      _StatCard(
        title: 'Avg ATS Score',
        value: avg,
        suffix: '',
        trend: '+8 pts',
        icon: Icons.trending_up_rounded,
        accent: AuroraDark.lime,
      ),
      _StatCard(
        title: 'Skills Matched',
        value: controller.skillsMatched,
        suffix: '%',
        trend: '+5%',
        icon: Icons.track_changes_rounded,
        accent: AuroraDark.violet,
      ),
    ];

    if (stackVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) AppSpacing.gapSm,
            cards[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) AppSpacing.gapSm,
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final String suffix;
  final String trend;
  final IconData icon;
  final Color accent;

  const _StatCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.trend,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rXs,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent.withValues(alpha: 0.30),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              BlurPill(
                label: trend,
                icon: Icons.arrow_outward_rounded,
                color: accent,
                dense: true,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              AnimatedCounter(
                value: value,
                style: AppType.headlineLarge.copyWith(
                  color: AuroraDark.textPrimary,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: AppType.headlineSmall
                      .copyWith(color: AuroraDark.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(title, style: AppType.bodySmall),
          AppSpacing.gapSm,
          _Sparkline(color: accent),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        painter: _SparkPainter(color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const List<double> data = <double>[0.4, 0.55, 0.5, 0.7, 0.6, 0.85, 0.78, 0.95];
    final Path path = Path();
    for (int i = 0; i < data.length; i++) {
      final double x = i * (size.width / (data.length - 1));
      final double y = size.height - data[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    final Path fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────
//  Target Job
// ─────────────────────────────────────────────────────────────────────

class _TargetJobSection extends StatelessWidget {
  const _TargetJobSection();

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.violet,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rXs,
                  gradient: AppGradients.warm,
                  boxShadow: AppNeon.pink,
                ),
                child: const Icon(Icons.work_rounded,
                    size: 20, color: Colors.white),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: GradientText(
                  'Target Job',
                  style: AppType.headlineSmall,
                ),
              ),
              BlurPill(
                label: 'Optional',
                color: AuroraDark.textMuted,
                dense: true,
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            'Drop the job you are applying to and we will tune your CV to it.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool narrow = constraints.maxWidth < 520;
              if (narrow) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _JobInput(
                      label: 'Job Title',
                      hint: 'e.g. Senior Frontend Developer',
                    ),
                    SizedBox(height: AppSpacing.sm),
                    _JobInput(
                      label: 'Company',
                      hint: 'e.g. Google, Meta…',
                    ),
                  ],
                );
              }
              return const Row(
                children: <Widget>[
                  Expanded(
                    child: _JobInput(
                      label: 'Job Title',
                      hint: 'e.g. Senior Frontend Developer',
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _JobInput(
                      label: 'Company',
                      hint: 'e.g. Google, Meta…',
                    ),
                  ),
                ],
              );
            },
          ),
          AppSpacing.gapSm,
          const _JobInput(
            label: 'Job Description / Requirements',
            hint:
                'Paste the job description here so our AI can match your CV to the exact requirements…',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

class _JobInput extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;

  const _JobInput({
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.labelMedium),
        const SizedBox(height: 6),
        TextField(
          maxLines: maxLines,
          style: AppType.bodyLarge.copyWith(color: AuroraDark.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppType.bodyMedium.copyWith(color: AuroraDark.textMuted),
            filled: true,
            fillColor: AuroraDark.surfaceAlt,
          ),
          cursorColor: AuroraDark.cyanBright,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  CVs section
// ─────────────────────────────────────────────────────────────────────

class _CVWorkspaceSection extends StatelessWidget {
  final CVController controller;
  final bool desktop;

  const _CVWorkspaceSection({required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    if (!desktop) {
      return Column(
        children: <Widget>[
          _CVListPanel(controller: controller),
          AppSpacing.gapMd,
          _UploadTipsPanel(controller: controller),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: _CVListPanel(controller: controller)),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: 2, child: _UploadTipsPanel(controller: controller)),
      ],
    );
  }
}

class _CVListPanel extends StatelessWidget {
  final CVController controller;
  const _CVListPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: <Widget>[
            GradientText(
              'My CVs',
              style: AppType.headlineMedium,
            ),
            GradientButton(
              label: 'Compare versions',
              icon: Icons.compare_arrows_rounded,
              size: GradientButtonSize.small,
              gradient: AppGradients.cool,
              glowColor: AuroraDark.cyan,
              onPressed: () {
                if (controller.documents.length < 2) {
                  AuroraSnack.info(
                    'Compare',
                    'Upload at least 2 CVs to compare versions.',
                  );
                  return;
                }
                showCompareCvDialog(context);
              },
            ),
          ],
        ),
        AppSpacing.gapSm,
        if (controller.documents.isEmpty)
          EmptyState(
            icon: Icons.description_outlined,
            title: 'No CVs yet',
            message:
                'Upload your first CV to get an instant ATS score, skill gaps and tailored job matches.',
            actionLabel: 'Upload CV',
            onAction: controller.uploadCv,
            compact: true,
          )
        else
          ...List<Widget>.generate(controller.documents.length, (int i) {
            final CVDocument doc = controller.documents[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StaggerIn(
                index: i,
                child: _CVItemCard(document: doc),
              ),
            );
          }),
      ],
    );
  }
}

class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    final int delay = (widget.index * 70).clamp(0, 600);
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _CVItemCard extends StatelessWidget {
  final CVDocument document;
  const _CVItemCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final int score = document.report.score;
    final ATSCheckReport report = document.report;
    final Color color = report.listBadgeIsPositive
        ? AuroraDark.lime
        : report.listBadgeLabel.toUpperCase() == 'FAIL'
            ? AuroraDark.danger
            : score >= 50
                ? AuroraDark.warning
                : AuroraDark.danger;
    return GlowCard(
      glowColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: AppRadii.rXs,
              gradient: LinearGradient(
                colors: <Color>[
                  AuroraDark.indigo.withValues(alpha: 0.35),
                  AuroraDark.violet.withValues(alpha: 0.18),
                ],
              ),
              border: Border.all(color: AuroraDark.indigo.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: AuroraDark.cyanBright,
              size: 22,
            ),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  document.fileName,
                  style: AppType.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(document.uploadedAt),
                  style: AppType.bodySmall,
                ),
              ],
            ),
          ),
          BlurPill(
            label: report.listBadgeLabel,
            color: color,
            dense: true,
          ),
          AppSpacing.gapSm,
          _ScoreRing(score: score, color: color),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.color});
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: TweenAnimationBuilder<double>(
        duration: AppDurations.long,
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: score / 100),
        builder: (BuildContext context, double v, _) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: AuroraDark.surfaceAlt,
              ),
              Text(
                '$score',
                style: AppType.titleSmall.copyWith(
                  color: AuroraDark.textPrimary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UploadTipsPanel extends StatelessWidget {
  final CVController controller;
  const _UploadTipsPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GlowCard(
          glowColor: AuroraDark.cyanBright,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.cloud_upload_rounded,
                      color: AuroraDark.cyanBright),
                  AppSpacing.gapXs,
                  Text('Upload New', style: AppType.titleLarge),
                ],
              ),
              AppSpacing.gapSm,
              _DashedDropZone(onTap: controller.uploadCv),
              AppSpacing.gapSm,
              GradientButton(
                label: 'Upload New CV',
                icon: Icons.upload_rounded,
                fullWidth: true,
                size: GradientButtonSize.medium,
                onPressed: controller.uploadCv,
              ),
            ],
          ),
        ),
        AppSpacing.gapMd,
        GlowCard(
          glowColor: AuroraDark.violet,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.lightbulb_rounded,
                      color: AuroraDark.amber),
                  AppSpacing.gapXs,
                  Text('Quick Tips', style: AppType.titleLarge),
                ],
              ),
              AppSpacing.gapSm,
              const _TipBullet(text: 'Use keywords from the job description'),
              const _TipBullet(text: 'Keep formatting consistent'),
              const _TipBullet(text: 'Quantify your achievements'),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedDropZone extends StatefulWidget {
  final VoidCallback onTap;
  const _DashedDropZone({required this.onTap});

  @override
  State<_DashedDropZone> createState() => _DashedDropZoneState();
}

class _DashedDropZoneState extends State<_DashedDropZone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.short,
          curve: AppCurves.standard,
          decoration: BoxDecoration(
            borderRadius: AppRadii.rMd,
            color: _hover
                ? AuroraDark.cyanBright.withValues(alpha: 0.10)
                : AuroraDark.surfaceAlt,
            border: Border.all(
              color: _hover
                  ? AuroraDark.cyanBright
                  : AuroraDark.borderStrong,
              width: 1.4,
              style: BorderStyle.solid,
            ),
            boxShadow: _hover
                ? <BoxShadow>[
                    BoxShadow(
                      color: AuroraDark.cyan.withValues(alpha: 0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: CustomPaint(
            painter: _DashedRectPainter(
              color: _hover ? AuroraDark.cyanBright : AuroraDark.borderStrong,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.cool,
                      boxShadow: AppNeon.cyan,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'Drop your CV here',
                    style: AppType.titleMedium.copyWith(
                      color: AuroraDark.cyanBright,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF, DOCX up to 10 MB',
                    style: AppType.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 8;
    const double dashSpace = 6;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final Path path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final Path extract = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}

class _TipBullet extends StatelessWidget {
  final String text;
  const _TipBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 7),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AuroraDark.violet.withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Text(text, style: AppType.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Upload overlay
// ─────────────────────────────────────────────────────────────────────

class _UploadOverlay extends StatefulWidget {
  final String message;
  const _UploadOverlay({required this.message});

  @override
  State<_UploadOverlay> createState() => _UploadOverlayState();
}

class _UploadOverlayState extends State<_UploadOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.88,
      upperBound: 1.14,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ScaleTransition(
                      scale: _pulse,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppGradients.brand,
                          boxShadow: AppNeon.violet,
                        ),
                        child: const Icon(
                          Icons.psychology_alt_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    AppSpacing.gapMd,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: AppType.titleMedium.copyWith(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton(
                onPressed: () => Get.find<CVController>().cancelUpload(),
                child: Text(
                  'Back to dashboard',
                  style: AppType.labelMedium.copyWith(
                    color: AuroraDark.cyanBright,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
