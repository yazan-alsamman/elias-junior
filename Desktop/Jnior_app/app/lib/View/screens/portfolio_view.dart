import 'dart:async';

import 'package:app/common/app_colors.dart';
import 'package:app/common/app_navigation.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/widgets/aurora_background.dart';
import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/common/widgets/blur_pill.dart';
import 'package:app/common/widgets/glow_card.dart';
import 'package:app/common/widgets/gradient_button.dart';
import 'package:app/common/widgets/gradient_text.dart';
import 'package:app/controller/portfolio_controller.dart';
import 'package:app/model/portfolio_preview_data.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:app/view/widgets/app_drawer.dart';
import 'package:app/view/widgets/app_side_rail.dart';
import 'package:app/view/widgets/portfolio_preview_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// GitHub-based portfolio builder with a live-style preview below the form.
class PortfolioView extends StatefulWidget {
  const PortfolioView({super.key});

  @override
  State<PortfolioView> createState() => _PortfolioViewState();
}

class _PortfolioViewState extends State<PortfolioView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<PortfolioController>()) {
        return;
      }
      final PortfolioController port = Get.find<PortfolioController>();
      unawaited(
        port
            .hydrateFromLatestCv(tryReparseLastUpload: true)
            .then((_) => port.refreshPreviewFromCv()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PortfolioController>(
      builder: (PortfolioController c) {
        final double width = MediaQuery.sizeOf(context).width;
        final bool desktop = width >= 980;
        final bool mobile = width < 700;
        final EdgeInsets pad = EdgeInsets.fromLTRB(
          mobile ? AppSpacing.md : AppSpacing.xl,
          mobile ? AppSpacing.md : AppSpacing.lg,
          mobile ? AppSpacing.md : AppSpacing.xl,
          (mobile ? AppSpacing.xl : AppSpacing.xxl) +
              MediaQuery.paddingOf(context).bottom,
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
                    'Portfolio',
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
              : const AppDrawer(current: AppDrawerPage.portfolio),
          body: AuroraBackground(
            intensity: 0.55,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (desktop)
                    const AppSideRail(current: AppDrawerPage.portfolio),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: pad,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _PortfolioPageHeader(mobile: mobile),
                              SizedBox(height: mobile ? 16 : 22),
                              _GitHubLinkCard(
                                  controller: c, mobile: mobile),
                              const SizedBox(height: AppSpacing.md),
                              _ProjectsListCard(
                                  controller: c, mobile: mobile),
                              const SizedBox(height: AppSpacing.md),
                              _PortfolioTemplatePicker(
                                  controller: c, mobile: mobile),
                              SizedBox(height: mobile ? 14 : 18),
                              GradientButton(
                                label: c.loading
                                    ? 'Generating…'
                                    : 'Generate portfolio preview',
                                icon: Icons.auto_awesome_rounded,
                                fullWidth: true,
                                size: GradientButtonSize.large,
                                isLoading: c.loading,
                                onPressed:
                                    c.loading ? null : c.fetchPortfolio,
                              ),
                              if (c.loading) ...<Widget>[
                                AppSpacing.gapMd,
                                const ClipRRect(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(4)),
                                  child: LinearProgressIndicator(
                                    color: AuroraDark.cyanBright,
                                    backgroundColor:
                                        AuroraDark.surfaceAlt,
                                  ),
                                ),
                                AppSpacing.gapXs,
                                Text(
                                  'Building preview…',
                                  textAlign: TextAlign.center,
                                  style: AppType.bodySmall,
                                ),
                              ],
                              _PortfolioGitHubSignupLink(mobile: mobile),
                              if (c.showPreview && c.previewData != null) ...<Widget>[
                                SizedBox(height: mobile ? 22 : 28),
                                _LivePortfolioPreview(
                                  data: c.previewData!,
                                  mobile: mobile,
                                  controller: c,
                                ),
                              ],
                              if (Get.isRegistered<AuthApiService>() &&
                                  Get.find<AuthApiService>().isLoggedIn)
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: mobile ? 22 : 28),
                                  child: _PublicPortfolioLinkSection(
                                    controller: c,
                                    mobile: mobile,
                                  ),
                                ),
                              if (!c.showPreview && !c.loading)
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: mobile ? 22 : 28),
                                  child: Text(
                                    'Paste your GitHub profile or username, list the repositories you have on GitHub, choose a layout, then generate.',
                                    textAlign: TextAlign.center,
                                    style: AppType.bodyMedium,
                                  ),
                                ),
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

class _PortfolioPageHeader extends StatelessWidget {
  final bool mobile;
  const _PortfolioPageHeader({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BlurPill(
          label: 'PORTFOLIO BUILDER',
          icon: Icons.layers_rounded,
          color: AuroraDark.pink,
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
                'Portfolio ',
                style: mobile
                    ? AppType.headlineLarge
                    : AppType.headlineLarge.copyWith(fontSize: 38),
              ),
              GradientText(
                'Builder',
                gradient: AppGradients.warm,
                style: mobile
                    ? AppType.headlineLarge
                    : AppType.headlineLarge.copyWith(fontSize: 38),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Connect your GitHub, pick a layout, and ship a portfolio in minutes.',
          style: AppType.bodyMedium,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  GitHub link
// ─────────────────────────────────────────────────────────────────────

class _GitHubLinkCard extends StatelessWidget {
  final PortfolioController controller;
  final bool mobile;
  const _GitHubLinkCard({required this.controller, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.cyanBright,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rXs,
                  gradient: AppGradients.cool,
                  boxShadow: AppNeon.cyan,
                ),
                child: const Icon(Icons.link_rounded,
                    size: 20, color: Colors.white),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  'GitHub username or URL',
                  style: AppType.titleLarge,
                ),
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            'Plain username, https://github.com/username, or any repo URL — we detect your login.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          TextField(
            controller: controller.githubLinkController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            cursorColor: AuroraDark.cyanBright,
            style: AppType.bodyLarge.copyWith(color: AuroraDark.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. https://github.com/octocat',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              filled: true,
              fillColor: AuroraDark.surfaceAlt,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Projects list
// ─────────────────────────────────────────────────────────────────────

class _ProjectsListCard extends StatelessWidget {
  final PortfolioController controller;
  final bool mobile;
  const _ProjectsListCard({required this.controller, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.violet,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rXs,
                  gradient: AppGradients.brand,
                  boxShadow: AppNeon.violet,
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    size: 18, color: Colors.white),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Text('Your repositories', style: AppType.titleLarge),
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            'Type each repo name exactly as it appears on github.com. Use the picture icon per chip to attach a custom cover.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller.projectInputController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => controller.addProjectFromField(),
                  autocorrect: false,
                  cursorColor: AuroraDark.cyanBright,
                  style: AppType.bodyLarge
                      .copyWith(color: AuroraDark.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Repo name…',
                    isDense: true,
                    filled: true,
                    fillColor: AuroraDark.surfaceAlt,
                  ),
                ),
              ),
              AppSpacing.gapXs,
              GradientButton(
                label: 'Add',
                icon: Icons.add_rounded,
                size: GradientButtonSize.medium,
                onPressed: controller.addProjectFromField,
              ),
            ],
          ),
          if (controller.projectNames.isNotEmpty) ...<Widget>[
            AppSpacing.gapMd,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  List<Widget>.generate(controller.projectNames.length, (int i) {
                final String name = controller.projectNames[i];
                final String key = portfolioProjectKey(name);
                final bool hasCustom = controller.projectCustomCoverPaths
                        .containsKey(key) ||
                    controller.projectCustomCoverMemory.containsKey(key);
                return _ProjectChip(
                  name: name,
                  hasCustom: hasCustom,
                  onPickCover: () => controller.pickCoverForProject(name),
                  onRemoveCover: hasCustom
                      ? () => controller.clearCoverForProject(name)
                      : null,
                  onDelete: () => controller.removeProject(i),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    required this.name,
    required this.hasCustom,
    required this.onPickCover,
    required this.onDelete,
    this.onRemoveCover,
  });

  final String name;
  final bool hasCustom;
  final VoidCallback onPickCover;
  final VoidCallback onDelete;
  final VoidCallback? onRemoveCover;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuroraDark.surfaceAlt,
        borderRadius: AppRadii.rPill,
        border: Border.all(color: AuroraDark.border),
      ),
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasCustom)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.image_rounded,
                size: 14,
                color: AuroraDark.cyanBright,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              name,
              style: AppType.labelMedium.copyWith(
                color: AuroraDark.textPrimary,
              ),
            ),
          ),
          AppSpacing.gapXxs,
          IconButton(
            tooltip: hasCustom ? 'Change cover image' : 'Add cover image',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onPickCover,
            icon: Icon(
              hasCustom
                  ? Icons.edit_rounded
                  : Icons.add_photo_alternate_outlined,
              size: 16,
              color: AuroraDark.textSecondary,
            ),
          ),
          if (onRemoveCover != null)
            IconButton(
              tooltip: 'Remove cover image',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: onRemoveCover,
              icon: const Icon(
                Icons.no_photography_outlined,
                size: 16,
                color: AuroraDark.textMuted,
              ),
            ),
          IconButton(
            tooltip: 'Remove repo',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onDelete,
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AuroraDark.danger,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Templates
// ─────────────────────────────────────────────────────────────────────

class _PortfolioTemplatePicker extends StatelessWidget {
  final PortfolioController controller;
  final bool mobile;
  const _PortfolioTemplatePicker(
      {required this.controller, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowColor: AuroraDark.pink,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rXs,
                  gradient: AppGradients.warm,
                  boxShadow: AppNeon.pink,
                ),
                child: const Icon(Icons.style_rounded,
                    size: 18, color: Colors.white),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Text('Portfolio template', style: AppType.titleLarge),
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            'Five built-in layouts. You can regenerate after switching.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final PortfolioTemplate t in PortfolioTemplate.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TemplateChoiceChip(
                      template: t,
                      selected: controller.selectedTemplate == t,
                      narrow: mobile,
                      onTap: () => controller.setTemplate(t),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateChoiceChip extends StatelessWidget {
  const _TemplateChoiceChip({
    required this.template,
    required this.selected,
    required this.narrow,
    required this.onTap,
  });

  final PortfolioTemplate template;
  final bool selected;
  final bool narrow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double width = narrow ? 168 : 188;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadii.rMd,
        child: AnimatedContainer(
          duration: AppDurations.short,
          curve: AppCurves.standard,
          width: width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: AppRadii.rMd,
            border: Border.all(
              color: selected
                  ? AuroraDark.pink
                  : AuroraDark.border,
              width: selected ? 1.6 : 1,
            ),
            gradient: selected
                ? LinearGradient(
                    colors: <Color>[
                      AuroraDark.pink.withValues(alpha: 0.18),
                      AuroraDark.violet.withValues(alpha: 0.06),
                    ],
                  )
                : AppGradients.surfaceTint,
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AuroraDark.pink.withValues(alpha: 0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TemplateThumbnail(template: template, selected: selected),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      template.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.titleSmall.copyWith(
                        color: selected
                            ? AuroraDark.textPrimary
                            : AuroraDark.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AuroraDark.pink),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                template.shortDescription,
                maxLines: narrow ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small painted preview that hints at each template's layout.
class _TemplateThumbnail extends StatelessWidget {
  const _TemplateThumbnail({required this.template, required this.selected});
  final PortfolioTemplate template;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.rXs,
          color: AuroraDark.bg,
          border: Border.all(
            color: selected
                ? AuroraDark.pink.withValues(alpha: 0.5)
                : AuroraDark.border,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AuroraDark.bgElevated,
              AuroraDark.surface,
            ],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _ThumbnailPainter(template: template),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter({required this.template});
  final PortfolioTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint accent = Paint()..color = AuroraDark.cyanBright;
    final Paint dim = Paint()
      ..color = AuroraDark.borderStrong.withValues(alpha: 0.6);
    final Paint card = Paint()..color = AuroraDark.surfaceHigh;

    final double w = size.width;
    final double h = size.height;
    final double m = 6;

    switch (template.label) {
      case String l when l.toLowerCase().contains('grid'):
        // 2x2 grid of cards.
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < 2; c++) {
            final Rect rect = Rect.fromLTWH(
              m + c * ((w - m * 3) / 2 + m),
              m + 8 + r * ((h - m * 3 - 8) / 2 + m),
              (w - m * 3) / 2,
              (h - m * 3 - 8) / 2,
            );
            canvas.drawRRect(
                RRect.fromRectAndRadius(rect, const Radius.circular(2)), card);
          }
        }
        canvas.drawRect(Rect.fromLTWH(m, m, w * 0.4, 4), accent);
        break;
      case String l when l.toLowerCase().contains('cover'):
        // Big cover top, small cards bottom.
        canvas.drawRect(Rect.fromLTWH(m, m, w - m * 2, h * 0.55), card);
        for (int i = 0; i < 3; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              m + i * ((w - m * 4) / 3 + m),
              h * 0.65,
              (w - m * 4) / 3,
              h * 0.3,
            ),
            dim,
          );
        }
        break;
      case String l when l.toLowerCase().contains('list'):
      case String l when l.toLowerCase().contains('timeline'):
        // Stacked rows.
        for (int i = 0; i < 4; i++) {
          canvas.drawRect(
            Rect.fromLTWH(m, m + 2 + i * (h - m * 2) / 4, w - m * 2, 6),
            i == 0 ? accent : card,
          );
        }
        break;
      case String l when l.toLowerCase().contains('split'):
        // Left sidebar + cards.
        canvas.drawRect(Rect.fromLTWH(m, m, w * 0.3, h - m * 2), card);
        for (int i = 0; i < 2; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              w * 0.35 + m,
              m + i * ((h - m * 2 - 4) / 2 + 4),
              w - w * 0.35 - m * 2,
              (h - m * 2 - 4) / 2,
            ),
            dim,
          );
        }
        canvas.drawRect(Rect.fromLTWH(m + 4, m + 6, w * 0.18, 4), accent);
        break;
      default:
        // Hero + project tiles.
        canvas.drawRect(Rect.fromLTWH(m, m, w - m * 2, 18), card);
        for (int i = 0; i < 3; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              m + i * ((w - m * 4) / 3 + m),
              m + 24,
              (w - m * 4) / 3,
              h - m - 26,
            ),
            dim,
          );
        }
        canvas.drawRect(Rect.fromLTWH(m + 4, m + 4, w * 0.3, 4), accent);
    }
  }

  @override
  bool shouldRepaint(_ThumbnailPainter old) => old.template != template;
}

// ─────────────────────────────────────────────────────────────────────
//  Live preview
// ─────────────────────────────────────────────────────────────────────

class _LivePortfolioPreview extends StatelessWidget {
  const _LivePortfolioPreview({
    required this.data,
    required this.mobile,
    required this.controller,
  });

  final PortfolioPreviewData data;
  final bool mobile;
  final PortfolioController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.visibility_rounded,
                size: 22, color: AuroraDark.cyanBright),
            AppSpacing.gapSm,
            Expanded(
              child: GradientText(
                'Live preview · ${data.template.label}',
                style: AppType.headlineSmall,
              ),
            ),
            const PulsingDot(color: AuroraDark.lime),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          'Each card is one repo. Tap a card opens the repo on GitHub.',
          style: AppType.bodyMedium,
        ),
        AppSpacing.gapMd,
        Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.rLg,
            border: Border.all(color: AuroraDark.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AuroraDark.violet.withValues(alpha: 0.3),
                blurRadius: 32,
                offset: const Offset(0, 16),
                spreadRadius: -8,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: PortfolioTemplatePreviewRoot(
            data: data,
            mobile: mobile,
            localCoverFilePaths: controller.projectCustomCoverPaths,
            localCoverMemoryBytes: controller.projectCustomCoverMemory,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Public link
// ─────────────────────────────────────────────────────────────────────

class _PublicPortfolioLinkSection extends StatelessWidget {
  final PortfolioController controller;
  final bool mobile;
  const _PublicPortfolioLinkSection(
      {required this.controller, required this.mobile});

  Future<void> _openPublishedLink(String raw) async {
    final String normalized = normalizePublishedPortfolioUrl(raw);
    final Uri? uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      _toast('Invalid link', 'The portfolio URL could not be read.');
      return;
    }
    try {
      bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok) {
        _toast('Could not open browser', 'Paste the URL manually.');
      }
    } catch (_) {
      _toast(
          'Could not open browser', 'Copy the link and paste it in a browser.');
    }
  }

  void _toast(String title, String msg) {
    AuroraSnack.info(title, msg);
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AuthApiService>()) return const SizedBox.shrink();
    if (!Get.find<AuthApiService>().isLoggedIn) return const SizedBox.shrink();

    return GlowCard(
      glowColor: AuroraDark.lime,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.rXs,
                  gradient: const LinearGradient(
                    colors: <Color>[AuroraDark.lime, AuroraDark.success],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AuroraDark.lime.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.public_rounded,
                    size: 18, color: Colors.white),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Text('Public portfolio link', style: AppType.titleLarge),
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            'Save your CV details, GitHub repos and chosen layout. Anyone with the link can view it.',
            style: AppType.bodyMedium,
          ),
          AppSpacing.gapMd,
          GradientButton(
            label: controller.publishing
                ? 'Saving…'
                : 'Save and get public link',
            icon: Icons.link_rounded,
            isLoading: controller.publishing,
            fullWidth: true,
            gradient: const LinearGradient(
              colors: <Color>[AuroraDark.lime, AuroraDark.cyanBright],
            ),
            glowColor: AuroraDark.lime,
            onPressed: controller.publishing
                ? null
                : controller.publishPortfolioLink,
          ),
          if (controller.publishedPortfolioUrl != null &&
              controller.publishedPortfolioUrl!.isNotEmpty) ...<Widget>[
            AppSpacing.gapMd,
            _GlassLinkPill(
              url: controller.publishedPortfolioUrl!,
              onOpen: () =>
                  _openPublishedLink(controller.publishedPortfolioUrl!),
              onCopy: () async {
                final String normalized = normalizePublishedPortfolioUrl(
                    controller.publishedPortfolioUrl);
                await Clipboard.setData(ClipboardData(text: normalized));
                HapticFeedback.lightImpact();
                _toast('Copied', 'Link copied to clipboard.');
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassLinkPill extends StatelessWidget {
  const _GlassLinkPill({
    required this.url,
    required this.onOpen,
    required this.onCopy,
  });

  final String url;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AuroraDark.lime.withValues(alpha: 0.16),
            AuroraDark.cyanBright.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: AppRadii.rPill,
        border: Border.all(color: AuroraDark.lime.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.link_rounded,
              size: 18, color: AuroraDark.lime),
          AppSpacing.gapXs,
          Expanded(
            child: SelectableText(
              url,
              maxLines: 1,
              style: AppType.labelMedium.copyWith(
                color: AuroraDark.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Open',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded,
                size: 18, color: AuroraDark.cyanBright),
            constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded,
                size: 18, color: AuroraDark.cyanBright),
            constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  GitHub signup link
// ─────────────────────────────────────────────────────────────────────

class _PortfolioGitHubSignupLink extends StatelessWidget {
  final bool mobile;
  const _PortfolioGitHubSignupLink({required this.mobile});

  static final Uri _signupUri = Uri.parse('https://github.com/signup');

  Future<void> _openSignup() async {
    if (await canLaunchUrl(_signupUri)) {
      await launchUrl(_signupUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: mobile ? 14 : 16),
      child: Center(
        child: TextButton.icon(
          onPressed: _openSignup,
          icon: const Icon(Icons.open_in_new_rounded,
              size: 18, color: AuroraDark.cyanBright),
          label: Text(
            'No GitHub account? Create one',
            style: AppType.labelMedium.copyWith(
              color: AuroraDark.cyanBright,
              decoration: TextDecoration.underline,
              decorationColor: AuroraDark.cyanBright,
            ),
          ),
        ),
      ),
    );
  }
}
