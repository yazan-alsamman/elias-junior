import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/services/cv_content_diff.dart';
import 'package:flutter/scheduler.dart';

/// One row in the metric-by-metric comparison table.
class MetricCompareRow {
  final String label;
  /// Key used by the UI to pick an icon (`shield`, `format`, `key`, etc.).
  final String iconKey;
  final num oldVal;
  final num newVal;
  final String oldDisplay;
  final String newDisplay;
  final bool higherIsBetter;
  final bool showDelta;

  const MetricCompareRow({
    required this.label,
    required this.iconKey,
    required this.oldVal,
    required this.newVal,
    required this.oldDisplay,
    required this.newDisplay,
    this.higherIsBetter = true,
    this.showDelta = true,
  });

  int get delta => (newVal - oldVal).round();
}

/// Aggregated ATS / keyword deltas between an older and newer CV.
class ComparisonStats {
  final ATSCheckReport older;
  final ATSCheckReport newer;
  final bool scoresComparable;
  final int scoreDelta;
  final List<MetricCompareRow> rows;
  final List<String> keywordsResolved;
  final List<String> keywordsNewlyMissing;

  const ComparisonStats({
    required this.older,
    required this.newer,
    required this.scoresComparable,
    required this.scoreDelta,
    required this.rows,
    required this.keywordsResolved,
    required this.keywordsNewlyMissing,
  });

  /// ATS score change as a percentage of the older score.
  int get scoreChangePercent {
    if (!scoresComparable) return 0;
    final int base = older.score;
    if (base <= 0) {
      if (newer.score <= 0) return 0;
      return 100;
    }
    return ((scoreDelta / base) * 100).round();
  }

  factory ComparisonStats.fromDocuments(CVDocument oldDoc, CVDocument newDoc) {
    final ATSCheckReport a = oldDoc.report;
    final ATSCheckReport b = newDoc.report;

    final Set<String> oldKw = a.missingKeywords
        .map((String s) => s.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toSet();
    final Set<String> newKw = b.missingKeywords
        .map((String s) => s.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toSet();
    final List<String> resolved = a.missingKeywords.where((String k) {
      final String key = k.trim().toLowerCase();
      return key.isNotEmpty && !newKw.contains(key);
    }).toList();
    final List<String> newlyMissing = b.missingKeywords.where((String k) {
      final String key = k.trim().toLowerCase();
      return key.isNotEmpty && !oldKw.contains(key);
    }).toList();

    final ({int num, int den}) oldSec = _parseFraction(a.sectionMatch);
    final ({int num, int den}) newSec = _parseFraction(b.sectionMatch);
    final bool scoresComparable = a.scoresAreComparable(b);

    final List<MetricCompareRow> rows = <MetricCompareRow>[
      MetricCompareRow(
        label: 'ATS score',
        iconKey: 'shield',
        oldVal: a.score,
        newVal: b.score,
        oldDisplay: '${a.score}/100 (${a.engineLabel})',
        newDisplay: '${b.score}/100 (${b.engineLabel})',
        showDelta: scoresComparable,
      ),
      MetricCompareRow(
        label: 'Format score',
        iconKey: 'format',
        oldVal: a.formatScore,
        newVal: b.formatScore,
        oldDisplay: '${a.formatScore}%',
        newDisplay: '${b.formatScore}%',
      ),
      MetricCompareRow(
        label: 'Keywords matched',
        iconKey: 'key',
        oldVal: a.keywordsChecked,
        newVal: b.keywordsChecked,
        oldDisplay: a.keywordsTotal > 0
            ? '${a.keywordsChecked}/${a.keywordsTotal}'
            : '${a.keywordsChecked}',
        newDisplay: b.keywordsTotal > 0
            ? '${b.keywordsChecked}/${b.keywordsTotal}'
            : '${b.keywordsChecked}',
      ),
      MetricCompareRow(
        label: 'Sections covered',
        iconKey: 'sections',
        oldVal: oldSec.num,
        newVal: newSec.num,
        oldDisplay: a.sectionMatch.isEmpty ? '—' : a.sectionMatch,
        newDisplay: b.sectionMatch.isEmpty ? '—' : b.sectionMatch,
      ),
      MetricCompareRow(
        label: 'Missing keywords',
        iconKey: 'warning',
        oldVal: a.missingKeywords.length,
        newVal: b.missingKeywords.length,
        oldDisplay: '${a.missingKeywords.length}',
        newDisplay: '${b.missingKeywords.length}',
        higherIsBetter: false,
      ),
    ];

    return ComparisonStats(
      older: a,
      newer: b,
      scoresComparable: scoresComparable,
      scoreDelta: scoresComparable ? b.score - a.score : 0,
      rows: rows,
      keywordsResolved: resolved,
      keywordsNewlyMissing: newlyMissing,
    );
  }

  static ({int num, int den}) _parseFraction(String s) {
    final RegExpMatch? m = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(s);
    if (m == null) return (num: 0, den: 0);
    return (
      num: int.tryParse(m.group(1) ?? '') ?? 0,
      den: int.tryParse(m.group(2) ?? '') ?? 0,
    );
  }
}

/// Full comparison payload returned after async work completes.
class CvCompareResult {
  const CvCompareResult({
    required this.stats,
    required this.contentDiff,
  });

  final ComparisonStats stats;
  final CvContentDiff contentDiff;
}

/// Compare two CVs without blocking the UI thread.
///
/// Previous `compute()` usage froze the app: serializing large CV payloads and
/// returning objects with non-transferable types hung the main isolate.
Future<CvCompareResult> compareCvsAsync(CVDocument a, CVDocument b) async {
  // Let the loading spinner render before any work runs.
  await Future<void>.delayed(Duration.zero);
  await SchedulerBinding.instance.endOfFrame;

  final bool aIsOlder = a.uploadedAt.isBefore(b.uploadedAt);
  final CVDocument older = aIsOlder ? a : b;
  final CVDocument newer = aIsOlder ? b : a;

  final ComparisonStats stats = ComparisonStats.fromDocuments(older, newer);
  await Future<void>.delayed(Duration.zero);
  final CvContentDiff contentDiff = CvContentDiff.between(older, newer);

  return CvCompareResult(stats: stats, contentDiff: contentDiff);
}
