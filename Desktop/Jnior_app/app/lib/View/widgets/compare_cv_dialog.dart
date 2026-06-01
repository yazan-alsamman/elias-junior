import 'package:app/common/app_colors.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/common/widgets/blur_pill.dart';
import 'package:app/common/widgets/glow_card.dart';
import 'package:app/common/widgets/gradient_button.dart';
import 'package:app/common/widgets/gradient_text.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/services/cv_compare_engine.dart';
import 'package:app/services/cv_content_diff.dart';
import 'package:app/model/cv_document.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Entry point — opens the compare modal.
Future<void> showCompareCvDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext _) => const _CompareCvSheet(),
  );
}

class _CompareCvSheet extends StatefulWidget {
  const _CompareCvSheet();

  @override
  State<_CompareCvSheet> createState() => _CompareCvSheetState();
}

class _CompareCvSheetState extends State<_CompareCvSheet> {
  int? _firstIndex;
  int? _secondIndex;
  bool _showResults = false;
  bool _loadingCompare = false;
  CvCompareResult? _compareResult;

  List<CVDocument> get _docs {
    final CVController c = Get.find<CVController>();
    final List<CVDocument> sorted = List<CVDocument>.from(c.documents)
      ..sort((CVDocument a, CVDocument b) =>
          b.uploadedAt.compareTo(a.uploadedAt));
    return sorted;
  }

  bool get _canCompare =>
      _firstIndex != null &&
      _secondIndex != null &&
      _firstIndex != _secondIndex;

  void _toggleSelect(int idx) {
    setState(() {
      if (_firstIndex == idx) {
        _firstIndex = null;
      } else if (_secondIndex == idx) {
        _secondIndex = null;
      } else if (_firstIndex == null) {
        _firstIndex = idx;
      } else if (_secondIndex == null) {
        _secondIndex = idx;
      } else {
        _secondIndex = idx;
      }
    });
  }

  int? _selectionOrder(int idx) {
    if (_firstIndex == idx) return 1;
    if (_secondIndex == idx) return 2;
    return null;
  }

  Future<void> _runCompare() async {
    if (!_canCompare || _loadingCompare) return;
    final List<CVDocument> docs = List<CVDocument>.from(_docs);
    final CVDocument cvA = docs[_firstIndex!];
    final CVDocument cvB = docs[_secondIndex!];
    setState(() => _loadingCompare = true);
    try {
      final CvCompareResult result = await compareCvsAsync(cvA, cvB);
      if (!mounted) return;
      setState(() {
        _compareResult = result;
        _loadingCompare = false;
        _showResults = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCompare = false);
      AuroraSnack.error(
        'Compare failed',
        'Could not compare these CVs. Try again in a moment.',
      );
    }
  }

  void _backToSelection() {
    setState(() {
      _showResults = false;
      _compareResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<CVDocument> docs = _docs;
    final Size screen = MediaQuery.sizeOf(context);
    final bool mobile = screen.width < 700;

    // Fixed-height sheet avoids web hit-test errors from DraggableScrollableSheet.
    return FractionallySizedBox(
      heightFactor: mobile ? 0.92 : 0.94,
      child: Material(
        color: AuroraDark.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            _Handle(),
            _Header(
              onClose: () => Navigator.of(context).maybePop(),
              showResults: _showResults,
              onBack: _showResults ? _backToSelection : null,
            ),
            const Divider(height: 1, color: AuroraDark.border),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  mobile ? AppSpacing.md : AppSpacing.lg,
                  AppSpacing.md,
                  mobile ? AppSpacing.md : AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: docs.length < 2
                    ? const _NotEnoughCvsState()
                    : _loadingCompare
                        ? const _CompareLoadingState()
                        : _showResults && _compareResult != null
                            ? _ComparisonResults(
                                cvA: docs[_firstIndex!],
                                cvB: docs[_secondIndex!],
                                stats: _compareResult!.stats,
                                contentDiff: _compareResult!.contentDiff,
                                mobile: mobile,
                              )
                            : _SelectionStep(
                                docs: docs,
                                selectionOrder: _selectionOrder,
                                onTapItem: _toggleSelect,
                                mobile: mobile,
                              ),
              ),
            ),
            if (docs.length >= 2 && !_showResults && !_loadingCompare)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: GradientButton(
                    label: _canCompare
                        ? 'Compare these 2 CVs'
                        : 'Select 2 CVs to compare',
                    icon: Icons.compare_arrows_rounded,
                    fullWidth: true,
                    onPressed: _canCompare ? _runCompare : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Header / handle
// ─────────────────────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AuroraDark.borderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final bool showResults;

  const _Header({
    required this.onClose,
    required this.showResults,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 4, AppSpacing.sm, AppSpacing.md),
      child: Row(
        children: <Widget>[
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: AuroraDark.textPrimary,
              onPressed: onBack,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                GradientText(
                  showResults ? 'Comparison results' : 'Compare CV versions',
                  style: AppType.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  showResults
                      ? 'See how your CV improved between versions.'
                      : 'Pick two CVs to compare their ATS scores side by side.',
                  style: AppType.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AuroraDark.textPrimary,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step 1 — Selection
// ─────────────────────────────────────────────────────────────────────

class _SelectionStep extends StatelessWidget {
  final List<CVDocument> docs;
  final int? Function(int idx) selectionOrder;
  final void Function(int idx) onTapItem;
  final bool mobile;

  const _SelectionStep({
    required this.docs,
    required this.selectionOrder,
    required this.onTapItem,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _SlotChip(order: 1, label: _slotLabel(1)),
            const SizedBox(width: 8),
            _SlotChip(order: 2, label: _slotLabel(2)),
          ],
        ),
        AppSpacing.gapMd,
        ...List<Widget>.generate(docs.length, (int i) {
          final CVDocument doc = docs[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SelectableCvTile(
              doc: doc,
              order: selectionOrder(i),
              onTap: () => onTapItem(i),
              mobile: mobile,
            ),
          );
        }),
      ],
    );
  }

  String _slotLabel(int slot) {
    return slot == 1 ? 'Tap to pick CV #1' : 'Tap to pick CV #2';
  }
}

class _SlotChip extends StatelessWidget {
  final int order;
  final String label;

  const _SlotChip({
    required this.order,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        order == 1 ? AuroraDark.cyanBright : AuroraDark.violet;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: AppRadii.rSm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.25),
                border: Border.all(color: color),
              ),
              child: Text(
                '$order',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppType.labelMedium.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableCvTile extends StatelessWidget {
  final CVDocument doc;
  final int? order;
  final VoidCallback onTap;
  final bool mobile;

  const _SelectableCvTile({
    required this.doc,
    required this.order,
    required this.onTap,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final Color slotColor =
        order == 1 ? AuroraDark.cyanBright : AuroraDark.violet;
    final bool selected = order != null;
    final int score = doc.report.score;
    final Color scoreColor = score >= 75
        ? AuroraDark.lime
        : score >= 50
            ? AuroraDark.warning
            : AuroraDark.danger;
    return GlowCard(
      onTap: onTap,
      glowColor: selected ? slotColor : AuroraDark.indigo,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? slotColor.withValues(alpha: 0.25)
                  : AuroraDark.surfaceHigh,
              border: Border.all(
                color: selected ? slotColor : AuroraDark.borderStrong,
                width: 1.4,
              ),
            ),
            child: selected
                ? Text(
                    '$order',
                    style: TextStyle(
                      color: slotColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  )
                : const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AuroraDark.textMuted,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  doc.fileName,
                  style: AppType.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(doc.uploadedAt),
                  style: AppType.bodySmall,
                ),
              ],
            ),
          ),
          BlurPill(
            label: 'ATS $score',
            color: scoreColor,
            dense: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Step 2 — Comparison results
// ─────────────────────────────────────────────────────────────────────

class _CompareLoadingState extends StatelessWidget {
  const _CompareLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AuroraDark.violet,
            ),
          ),
          AppSpacing.gapMd,
          Text(
            'Comparing CV versions…',
            style: AppType.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Analyzing ATS scores, keywords, and content changes.',
            textAlign: TextAlign.center,
            style: AppType.bodyMedium.copyWith(color: AuroraDark.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Lightweight card for compare results — avoids many [GlowCard] animation controllers at once.
class _CompareSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor;

  const _CompareSurface({
    required this.child,
    this.padding,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? AuroraDark.indigo;
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AuroraDark.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _ComparisonResults extends StatelessWidget {
  final CVDocument cvA;
  final CVDocument cvB;
  final ComparisonStats stats;
  final CvContentDiff contentDiff;
  final bool mobile;

  const _ComparisonResults({
    required this.cvA,
    required this.cvB,
    required this.stats,
    required this.contentDiff,
    required this.mobile,
  });

  /// Order so [older] comes before [newer] based on uploadedAt.
  ({CVDocument older, CVDocument newer}) get _ordered {
    final bool aIsOlder = cvA.uploadedAt.isBefore(cvB.uploadedAt);
    return aIsOlder
        ? (older: cvA, newer: cvB)
        : (older: cvB, newer: cvA);
  }

  @override
  Widget build(BuildContext context) {
    final ({CVDocument older, CVDocument newer}) pair = _ordered;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _VerdictBanner(stats: stats, mobile: mobile),
        AppSpacing.gapMd,
        _SideBySideCvCards(
          older: pair.older,
          newer: pair.newer,
          mobile: mobile,
        ),
        AppSpacing.gapMd,
        _MetricsCompareCard(stats: stats, mobile: mobile),
        if (contentDiff.hasStructuredChanges) ...<Widget>[
          AppSpacing.gapMd,
          _ContentDeltaSection(diff: contentDiff, mobile: mobile),
        ],
        AppSpacing.gapMd,
        if (stats.keywordsResolved.isNotEmpty)
          _KeywordsDeltaCard(
            title: 'Keywords resolved',
            subtitle:
                'These were missing in the older CV but now present in the newer one.',
            keywords: stats.keywordsResolved,
            positive: true,
            mobile: mobile,
          ),
        if (stats.keywordsNewlyMissing.isNotEmpty) ...<Widget>[
          AppSpacing.gapMd,
          _KeywordsDeltaCard(
            title: 'New gaps appeared',
            subtitle:
                'These are missing in the newer CV but were not flagged in the older one.',
            keywords: stats.keywordsNewlyMissing,
            positive: false,
            mobile: mobile,
          ),
        ],
        AppSpacing.gapLg,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Verdict / overall summary
// ─────────────────────────────────────────────────────────────────────

class _VerdictBanner extends StatelessWidget {
  final ComparisonStats stats;
  final bool mobile;

  const _VerdictBanner({required this.stats, required this.mobile});

  @override
  Widget build(BuildContext context) {
    if (!stats.scoresComparable) {
      return _CompareSurface(
        accentColor: AuroraDark.warning,
        padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.info_outline_rounded,
              color: AuroraDark.warning,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Scores use different engines',
                    style: AppType.titleLarge.copyWith(
                      color: AuroraDark.textPrimary,
                      fontSize: mobile ? 16 : 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Older: ${stats.older.engineLabel} (${stats.older.score}/100) · '
                    'Newer: ${stats.newer.engineLabel} (${stats.newer.score}/100). '
                    'Re-upload both CVs with local ATS running on :8010 for a fair comparison.',
                    style: AppType.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final int delta = stats.scoreDelta;
    final int pct = stats.scoreChangePercent;
    final bool improved = delta > 0;
    final bool same = delta == 0;
    final Color color = same
        ? AuroraDark.textMuted
        : improved
            ? AuroraDark.lime
            : AuroraDark.danger;
    final IconData icon = same
        ? Icons.horizontal_rule_rounded
        : improved
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;
    final String pctLabel = same
        ? '0%'
        : '${pct >= 0 ? '+' : ''}$pct%';
    final String headline = same
        ? 'No change in ATS performance'
        : improved
            ? 'Newer CV improved by $pctLabel'
            : 'Newer CV declined by ${pct.abs()}%';
    final String sub = same
        ? 'Same ATS score (${stats.older.score}/100) — see added/removed content below.'
        : improved
            ? '${stats.older.score} → ${stats.newer.score} points ($delta pt change). Details below.'
            : '${stats.older.score} → ${stats.newer.score} points (${delta.abs()} pt drop). Review regressions below.';

    return _CompareSurface(
      accentColor: color,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[
                  color.withValues(alpha: 0.32),
                  color.withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  headline,
                  style: AppType.titleLarge.copyWith(
                    color: AuroraDark.textPrimary,
                    fontSize: mobile ? 16 : 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(sub, style: AppType.bodySmall),
              ],
            ),
          ),
          if (!same)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    pctLabel,
                    style: AppType.headlineMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: mobile ? 22 : 26,
                    ),
                  ),
                  Text(
                    '${improved ? '+' : ''}$delta pts',
                    style: AppType.labelSmall.copyWith(color: AuroraDark.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Side-by-side CV cards
// ─────────────────────────────────────────────────────────────────────

class _SideBySideCvCards extends StatelessWidget {
  final CVDocument older;
  final CVDocument newer;
  final bool mobile;

  const _SideBySideCvCards({
    required this.older,
    required this.newer,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _CvSummaryCard(
            doc: older,
            slot: 'OLDER',
            color: AuroraDark.cyanBright,
            mobile: mobile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CvSummaryCard(
            doc: newer,
            slot: 'NEWER',
            color: AuroraDark.violet,
            mobile: mobile,
          ),
        ),
      ],
    );
  }
}

class _CvSummaryCard extends StatelessWidget {
  final CVDocument doc;
  final String slot;
  final Color color;
  final bool mobile;

  const _CvSummaryCard({
    required this.doc,
    required this.slot,
    required this.color,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final int score = doc.report.score;
    final Color scoreColor = score >= 75
        ? AuroraDark.lime
        : score >= 50
            ? AuroraDark.warning
            : AuroraDark.danger;
    return _CompareSurface(
      accentColor: color,
      padding: EdgeInsets.all(mobile ? AppSpacing.sm : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BlurPill(
            label: slot,
            color: color,
            dense: true,
          ),
          AppSpacing.gapXs,
          Text(
            doc.fileName,
            style: AppType.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatDate(doc.uploadedAt),
            style: AppType.bodySmall,
          ),
          AppSpacing.gapSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$score',
                style: AppType.headlineLarge.copyWith(
                  color: scoreColor,
                  fontSize: mobile ? 28 : 34,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/100',
                style: AppType.bodySmall.copyWith(color: AuroraDark.textMuted),
              ),
            ],
          ),
          Text(
            'ATS score · ${doc.report.engineLabel}',
            style: AppType.labelSmall.copyWith(color: AuroraDark.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Metrics comparison table
// ─────────────────────────────────────────────────────────────────────

class _MetricsCompareCard extends StatelessWidget {
  final ComparisonStats stats;
  final bool mobile;

  const _MetricsCompareCard({required this.stats, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return _CompareSurface(
      accentColor: AuroraDark.cyanBright,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GradientText(
            'Metric-by-metric',
            style: AppType.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Older value → newer value, with the change shown in green or red.',
            style: AppType.bodySmall,
          ),
          AppSpacing.gapMd,
          ...stats.rows.map((MetricCompareRow r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MetricRow(row: r, mobile: mobile),
              )),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final MetricCompareRow row;
  final bool mobile;

  const _MetricRow({required this.row, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final Color deltaColor;
    final IconData deltaIcon;
    if (!row.showDelta) {
      deltaColor = AuroraDark.textMuted;
      deltaIcon = Icons.horizontal_rule_rounded;
    } else if (row.delta == 0) {
      deltaColor = AuroraDark.textMuted;
      deltaIcon = Icons.horizontal_rule_rounded;
    } else if ((row.delta > 0) == row.higherIsBetter) {
      deltaColor = AuroraDark.lime;
      deltaIcon = Icons.arrow_upward_rounded;
    } else {
      deltaColor = AuroraDark.danger;
      deltaIcon = Icons.arrow_downward_rounded;
    }
    final String deltaText = !row.showDelta
        ? 'N/A'
        : row.delta == 0
            ? '0'
            : (row.delta > 0 ? '+' : '') + row.delta.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuroraDark.surfaceAlt,
        borderRadius: AppRadii.rSm,
        border: Border.all(color: AuroraDark.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(row.icon, color: AuroraDark.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              row.label,
              style: AppType.titleSmall.copyWith(
                fontSize: mobile ? 13 : 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Flexible(
                  child: Text(
                    row.oldDisplay,
                    style: AppType.bodyMedium.copyWith(
                      color: AuroraDark.textSecondary,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_right_alt_rounded,
                      size: 16, color: AuroraDark.textMuted),
                ),
                Flexible(
                  child: Text(
                    row.newDisplay,
                    style: AppType.titleSmall.copyWith(
                      color: AuroraDark.textPrimary,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.14),
              borderRadius: AppRadii.rPill,
              border: Border.all(color: deltaColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(deltaIcon, size: 12, color: deltaColor),
                const SizedBox(width: 3),
                Text(
                  deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

// ─────────────────────────────────────────────────────────────────────
//  Content added / removed
// ─────────────────────────────────────────────────────────────────────

class _ContentDeltaSection extends StatelessWidget {
  final CvContentDiff diff;
  final bool mobile;

  const _ContentDeltaSection({required this.diff, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return _CompareSurface(
      accentColor: AuroraDark.indigo,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GradientText(
            'What changed between CVs',
            style: AppType.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Added in newer · removed from newer (compared oldest → newest upload).',
            style: AppType.bodySmall.copyWith(color: AuroraDark.textSecondary),
          ),
          AppSpacing.gapMd,
          if (diff.skillsAdded.isNotEmpty || diff.skillsRemoved.isNotEmpty)
            _DeltaGroup(
              title: 'Skills',
              added: diff.skillsAdded,
              removed: diff.skillsRemoved,
            ),
          if (diff.experienceAdded.isNotEmpty || diff.experienceRemoved.isNotEmpty)
            _DeltaGroup(
              title: 'Experience',
              added: diff.experienceAdded,
              removed: diff.experienceRemoved,
            ),
          if (diff.educationAdded.isNotEmpty || diff.educationRemoved.isNotEmpty)
            _DeltaGroup(
              title: 'Education',
              added: diff.educationAdded,
              removed: diff.educationRemoved,
            ),
          if (diff.certificationsAdded.isNotEmpty ||
              diff.certificationsRemoved.isNotEmpty)
            _DeltaGroup(
              title: 'Certifications',
              added: diff.certificationsAdded,
              removed: diff.certificationsRemoved,
            ),
          if (diff.rulesFixed.isNotEmpty || diff.rulesRegressed.isNotEmpty)
            _DeltaGroup(
              title: 'Format rules',
              added: diff.rulesFixed,
              removed: diff.rulesRegressed,
              addedLabel: 'Fixed',
              removedLabel: 'New issues',
            ),
        ],
      ),
    );
  }
}

class _DeltaGroup extends StatelessWidget {
  final String title;
  final List<String> added;
  final List<String> removed;
  final String addedLabel;
  final String removedLabel;

  const _DeltaGroup({
    required this.title,
    required this.added,
    required this.removed,
    this.addedLabel = 'Added',
    this.removedLabel = 'Removed',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppType.titleSmall),
          if (added.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              addedLabel,
              style: AppType.labelSmall.copyWith(color: AuroraDark.lime),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: added
                  .map((String s) => _Pill(label: s, color: AuroraDark.lime))
                  .toList(),
            ),
          ],
          if (removed.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              removedLabel,
              style: AppType.labelSmall.copyWith(color: AuroraDark.danger),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: removed
                  .map((String s) => _Pill(label: s, color: AuroraDark.danger))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Keyword delta card
// ─────────────────────────────────────────────────────────────────────

class _KeywordsDeltaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> keywords;
  final bool positive;
  final bool mobile;

  const _KeywordsDeltaCard({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.positive,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = positive ? AuroraDark.lime : AuroraDark.danger;
    return _CompareSurface(
      accentColor: color,
      padding: EdgeInsets.all(mobile ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                positive ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppType.titleLarge.copyWith(
                    color: AuroraDark.textPrimary,
                    fontSize: mobile ? 14.5 : 16,
                  ),
                ),
              ),
              BlurPill(
                label: '${keywords.length}',
                color: color,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppType.bodySmall),
          AppSpacing.gapSm,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keywords
                .map((String k) => _Pill(label: k, color: color))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────────────

class _NotEnoughCvsState extends StatelessWidget {
  const _NotEnoughCvsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
              boxShadow: AppNeon.violet,
            ),
            child: const Icon(Icons.compare_arrows_rounded,
                color: Colors.white, size: 32),
          ),
          AppSpacing.gapMd,
          Text(
            'Upload at least 2 CVs to compare',
            style: AppType.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Compare improvements between versions of your CV — ATS score, keyword gaps, format and more.',
              textAlign: TextAlign.center,
              style: AppType.bodyMedium,
            ),
          ),
          AppSpacing.gapMd,
          GradientButton(
            label: 'Got it',
            icon: Icons.check_rounded,
            onPressed: () {
              AuroraSnack.info(
                'Compare',
                'Upload one more CV from the dashboard, then come back.',
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────

String _formatDate(DateTime date) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
