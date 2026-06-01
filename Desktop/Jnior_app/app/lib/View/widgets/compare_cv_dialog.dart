import 'package:app/common/app_colors.dart';
import 'package:app/common/app_spacing.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/common/widgets/aurora_feedback.dart';
import 'package:app/common/widgets/blur_pill.dart';
import 'package:app/common/widgets/gradient_button.dart';
import 'package:app/common/widgets/gradient_text.dart';
import 'package:app/controller/cv_controller.dart';
import 'package:app/services/cv_compare_engine.dart';
import 'package:app/services/cv_content_diff.dart';
import 'package:app/model/cv_document.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Entry point — full-screen picker (avoids bottom-sheet ANR on Android).
Future<void> showCompareCvDialog(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext _) => const _CompareCvPage(),
    ),
  );
}

class _CompareCvPage extends StatefulWidget {
  const _CompareCvPage();

  @override
  State<_CompareCvPage> createState() => _CompareCvPageState();
}

class _CompareCvPageState extends State<_CompareCvPage> {
  int? _firstIndex;
  int? _secondIndex;

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

  void _runCompare() {
    if (!_canCompare) return;
    final List<CVDocument> docs = List<CVDocument>.from(_docs);
    final CVDocument cvA = docs[_firstIndex!];
    final CVDocument cvB = docs[_secondIndex!];
    final CvCompareResult result = compareDocuments(cvA, cvB);
    final bool mobile = MediaQuery.sizeOf(context).width < 700;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => _CompareResultsPage(
          result: result,
          mobile: mobile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<CVDocument> docs = _docs;
    final bool mobile = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: AuroraDark.bg,
      appBar: AppBar(
        backgroundColor: AuroraDark.bgElevated,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Compare CV versions',
              style: AppType.titleLarge.copyWith(fontSize: 17),
            ),
            Text(
              'Pick any 2 different CVs from your list.',
              style: AppType.labelSmall.copyWith(color: AuroraDark.textMuted),
            ),
          ],
        ),
      ),
      body: docs.length < 2
          ? const Center(child: _NotEnoughCvsState())
          : Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? AppSpacing.md : AppSpacing.lg,
                      AppSpacing.md,
                      mobile ? AppSpacing.md : AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: _SelectionStep(
                      docs: docs,
                      selectionOrder: _selectionOrder,
                      onTapItem: _toggleSelect,
                      mobile: mobile,
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: GradientButton(
                      label: _canCompare
                          ? 'Compare these 2 CVs'
                          : 'Select 2 different CVs',
                      icon: Icons.compare_arrows_rounded,
                      fullWidth: true,
                      onPressed: _canCompare ? _runCompare : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CompareResultsPage extends StatelessWidget {
  final CvCompareResult result;
  final bool mobile;

  const _CompareResultsPage({
    required this.result,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraDark.bg,
      appBar: AppBar(
        backgroundColor: AuroraDark.bgElevated,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Comparison results',
          style: AppType.titleLarge.copyWith(fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? AppSpacing.md : AppSpacing.lg,
          AppSpacing.md,
          mobile ? AppSpacing.md : AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: _ComparisonResults(
          older: result.older,
          newer: result.newer,
          stats: result.stats,
          contentDiff: result.contentDiff,
          mobile: mobile,
        ),
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
        const SizedBox(height: 8),
        Text(
          'Tap two different rows below. They can have similar names if you uploaded different versions.',
          style: AppType.bodySmall.copyWith(color: AuroraDark.textSecondary),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rMd,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AuroraDark.surface,
            borderRadius: AppRadii.rMd,
            border: Border.all(
              color: selected
                  ? slotColor.withValues(alpha: 0.55)
                  : AuroraDark.border,
            ),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Comparison results widgets
// ─────────────────────────────────────────────────────────────────────

/// Lightweight card for compare results.
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
  final CvCompareSnapshot older;
  final CvCompareSnapshot newer;
  final ComparisonStats stats;
  final CvContentDiff contentDiff;
  final bool mobile;

  const _ComparisonResults({
    required this.older,
    required this.newer,
    required this.stats,
    required this.contentDiff,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _VerdictBanner(stats: stats, mobile: mobile),
        AppSpacing.gapMd,
        _SideBySideCvCards(
          older: older,
          newer: newer,
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
  final CvCompareSnapshot older;
  final CvCompareSnapshot newer;
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
            snap: older,
            slot: 'OLDER',
            color: AuroraDark.cyanBright,
            mobile: mobile,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CvSummaryCard(
            snap: newer,
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
  final CvCompareSnapshot snap;
  final String slot;
  final Color color;
  final bool mobile;

  const _CvSummaryCard({
    required this.snap,
    required this.slot,
    required this.color,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final int score = snap.score;
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
            snap.fileName,
            style: AppType.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _formatDate(snap.uploadedAt),
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
            'ATS score · ${snap.engineLabel}',
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

  static IconData _iconForKey(String key) {
    switch (key) {
      case 'shield':
        return Icons.shield_rounded;
      case 'format':
        return Icons.format_align_left_rounded;
      case 'key':
        return Icons.key_rounded;
      case 'sections':
        return Icons.view_agenda_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.analytics_outlined;
    }
  }

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
          Icon(_iconForKey(row.iconKey), color: AuroraDark.textMuted, size: 18),
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

  static const int _maxPills = 24;

  const _DeltaGroup({
    required this.title,
    required this.added,
    required this.removed,
    this.addedLabel = 'Added',
    this.removedLabel = 'Removed',
  });

  @override
  Widget build(BuildContext context) {
    final List<String> addedShown = added.take(_maxPills).toList();
    final List<String> removedShown = removed.take(_maxPills).toList();
    final int addedExtra = added.length - addedShown.length;
    final int removedExtra = removed.length - removedShown.length;

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
              children: addedShown
                  .map((String s) => _Pill(label: s, color: AuroraDark.lime))
                  .toList(),
            ),
            if (addedExtra > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$addedExtra more',
                  style: AppType.labelSmall.copyWith(color: AuroraDark.textMuted),
                ),
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
              children: removedShown
                  .map((String s) => _Pill(label: s, color: AuroraDark.danger))
                  .toList(),
            ),
            if (removedExtra > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$removedExtra more',
                  style: AppType.labelSmall.copyWith(color: AuroraDark.textMuted),
                ),
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
    const int maxPills = 24;
    final List<String> shown = keywords.take(maxPills).toList();
    final int extra = keywords.length - shown.length;

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
            children: shown
                .map((String k) => _Pill(label: k, color: color))
                .toList(),
          ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+$extra more keywords',
                style: AppType.labelSmall.copyWith(color: AuroraDark.textMuted),
              ),
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
