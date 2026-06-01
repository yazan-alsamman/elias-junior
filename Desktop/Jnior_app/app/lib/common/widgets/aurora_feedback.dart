import 'dart:ui';

import 'package:app/common/app_colors.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/widgets/gradient_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Visual variant for [AuroraSnack] / [AuroraDialog].
/// Controls the accent color, icon, and left-bar tint.
enum AuroraFeedbackKind { info, success, warning, error, brand }

class _FeedbackStyle {
  const _FeedbackStyle({
    required this.accent,
    required this.icon,
  });
  final Color accent;
  final IconData icon;
}

_FeedbackStyle _styleFor(AuroraFeedbackKind kind) {
  switch (kind) {
    case AuroraFeedbackKind.success:
      return const _FeedbackStyle(
        accent: AuroraDark.lime,
        icon: Icons.check_circle_rounded,
      );
    case AuroraFeedbackKind.warning:
      return const _FeedbackStyle(
        accent: AuroraDark.amber,
        icon: Icons.warning_amber_rounded,
      );
    case AuroraFeedbackKind.error:
      return const _FeedbackStyle(
        accent: AuroraDark.danger,
        icon: Icons.error_outline_rounded,
      );
    case AuroraFeedbackKind.brand:
      return const _FeedbackStyle(
        accent: AuroraDark.violet,
        icon: Icons.auto_awesome_rounded,
      );
    case AuroraFeedbackKind.info:
      return const _FeedbackStyle(
        accent: AuroraDark.cyanBright,
        icon: Icons.info_outline_rounded,
      );
  }
}

/// Aurora-styled toast helper. Backed by [Get.snackbar] but with the unified
/// glass surface, accent left bar, and themed typography. Use this everywhere
/// instead of calling [Get.snackbar] directly so the visual language stays
/// consistent.
abstract final class AuroraSnack {
  static void show({
    required String title,
    required String message,
    AuroraFeedbackKind kind = AuroraFeedbackKind.info,
    Duration duration = const Duration(seconds: 3),
    SnackPosition position = SnackPosition.BOTTOM,
  }) {
    final _FeedbackStyle s = _styleFor(kind);
    HapticFeedback.lightImpact();

    Get.rawSnackbar(
      snackStyle: SnackStyle.FLOATING,
      snackPosition: position,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: EdgeInsets.zero,
      borderRadius: 0,
      duration: duration,
      maxWidth: 520,
      animationDuration: AppDurations.medium,
      forwardAnimationCurve: AppCurves.emphasizedDecel,
      reverseAnimationCurve: AppCurves.emphasized,
      messageText: ClipRRect(
        borderRadius: AppRadii.rMd,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: AuroraDark.surfaceHigh.withValues(alpha: 0.96),
            borderRadius: AppRadii.rMd,
            border: Border.all(color: s.accent.withValues(alpha: 0.55)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: s.accent.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ColoredBox(color: s.accent, child: const SizedBox(width: 4)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.accent.withValues(alpha: 0.18),
                            border: Border.all(
                              color: s.accent.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Icon(s.icon, color: s.accent, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (title.isNotEmpty)
                                Text(
                                  title,
                                  style: AppType.titleSmall.copyWith(
                                    color: AuroraDark.textPrimary,
                                  ),
                                ),
                              if (title.isNotEmpty && message.isNotEmpty)
                                const SizedBox(height: 4),
                              if (message.isNotEmpty)
                                Text(
                                  message,
                                  style: AppType.bodyMedium.copyWith(
                                    color: AuroraDark.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                            ],
                          ),
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

  static void info(String title, String message, {Duration? duration}) =>
      show(
        title: title,
        message: message,
        kind: AuroraFeedbackKind.info,
        duration: duration ?? const Duration(seconds: 3),
      );

  static void success(String title, String message, {Duration? duration}) =>
      show(
        title: title,
        message: message,
        kind: AuroraFeedbackKind.success,
        duration: duration ?? const Duration(seconds: 3),
      );

  static void warning(String title, String message, {Duration? duration}) =>
      show(
        title: title,
        message: message,
        kind: AuroraFeedbackKind.warning,
        duration: duration ?? const Duration(seconds: 4),
      );

  static void error(String title, String message, {Duration? duration}) =>
      show(
        title: title,
        message: message,
        kind: AuroraFeedbackKind.error,
        duration: duration ?? const Duration(seconds: 5),
      );

  static void brand(String title, String message, {Duration? duration}) =>
      show(
        title: title,
        message: message,
        kind: AuroraFeedbackKind.brand,
        duration: duration ?? const Duration(seconds: 3),
      );
}

/// Aurora-styled modal dialog. A glass card sits on top of a blurred dim
/// scrim. Used for confirmations and prompts that previously rendered as
/// flat [AlertDialog]s.
abstract final class AuroraDialog {
  /// Shows a confirmation dialog and returns the user's choice.
  ///
  /// Returns `true` when the user taps the confirm button, `false` when
  /// they tap cancel, and `null` if they dismiss by tapping outside.
  static Future<bool?> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    AuroraFeedbackKind kind = AuroraFeedbackKind.brand,
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    final _FeedbackStyle s = _styleFor(kind);
    return Get.dialog<bool>(
      _AuroraDialogShell(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        accent: s.accent,
        icon: icon ?? s.icon,
      ),
      barrierDismissible: barrierDismissible,
      barrierColor: const Color(0xCC020308),
      transitionDuration: AppDurations.medium,
      transitionCurve: AppCurves.emphasizedDecel,
    );
  }
}

class _AuroraDialogShell extends StatelessWidget {
  const _AuroraDialogShell({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: AppRadii.rLg,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppGradients.surfaceTint,
                    borderRadius: AppRadii.rLg,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.45),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                      ),
                      const BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  accent.withValues(alpha: 0.32),
                                  accent.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.55),
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: accent, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                title,
                                style: AppType.titleLarge.copyWith(
                                  color: AuroraDark.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        message,
                        style: AppType.bodyMedium.copyWith(
                          color: AuroraDark.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () {
                              if (Get.isDialogOpen == true) {
                                Get.back<bool>(result: false);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AuroraDark.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            child: Text(
                              cancelLabel,
                              style: AppType.labelLarge.copyWith(
                                color: AuroraDark.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          GradientButton(
                            label: confirmLabel,
                            onPressed: () {
                              if (Get.isDialogOpen == true) {
                                Get.back<bool>(result: true);
                              }
                            },
                            glowColor: accent,
                            size: GradientButtonSize.small,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
