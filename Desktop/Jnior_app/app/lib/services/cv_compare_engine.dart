import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/parsed_cv_profile.dart';
import 'package:app/services/cv_content_diff.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

/// One row in the metric-by-metric comparison table.
class MetricCompareRow {
  final String label;
  final IconData icon;
  final num oldVal;
  final num newVal;
  final String oldDisplay;
  final String newDisplay;
  final bool higherIsBetter;
  final bool showDelta;

  const MetricCompareRow({
    required this.label,
    required this.icon,
    required this.oldVal,
    required this.newVal,
    required this.oldDisplay,
    required this.newDisplay,
    this.higherIsBetter = true,
    this.showDelta = true,
  });

  int get delta => (newVal - oldVal).round();

  /// Percent change relative to the older value (for display).
  int percentChange({required bool higherIsBetter}) {
    final num base = oldVal;
    if (base == 0) {
      if (newVal == 0) return 0;
      return higherIsBetter ? 100 : -100;
    }
    return ((delta / base) * 100).round();
  }
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
        icon: Icons.shield_rounded,
        oldVal: a.score,
        newVal: b.score,
        oldDisplay: '${a.score}/100 (${a.engineLabel})',
        newDisplay: '${b.score}/100 (${b.engineLabel})',
        showDelta: scoresComparable,
      ),
      MetricCompareRow(
        label: 'Format score',
        icon: Icons.format_align_left_rounded,
        oldVal: a.formatScore,
        newVal: b.formatScore,
        oldDisplay: '${a.formatScore}%',
        newDisplay: '${b.formatScore}%',
      ),
      MetricCompareRow(
        label: 'Keywords matched',
        icon: Icons.key_rounded,
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
        icon: Icons.view_agenda_rounded,
        oldVal: oldSec.num,
        newVal: newSec.num,
        oldDisplay: a.sectionMatch.isEmpty ? '—' : a.sectionMatch,
        newDisplay: b.sectionMatch.isEmpty ? '—' : b.sectionMatch,
      ),
      MetricCompareRow(
        label: 'Missing keywords',
        icon: Icons.warning_amber_rounded,
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

class _CompareBundle {
  const _CompareBundle({required this.stats, required this.contentDiff});

  final ComparisonStats stats;
  final CvContentDiff contentDiff;
}

const int _maxTextForCompare = 12000;

Map<String, dynamic> _cvDocumentToMap(CVDocument doc) {
  final String preview = doc.contentPreview.length > _maxTextForCompare
      ? doc.contentPreview.substring(0, _maxTextForCompare)
      : doc.contentPreview;
  final String extracted = doc.extractedText.length > _maxTextForCompare
      ? doc.extractedText.substring(0, _maxTextForCompare)
      : doc.extractedText;
  return <String, dynamic>{
    'fileName': doc.fileName,
    'uploadedAt': doc.uploadedAt.toIso8601String(),
    'contentPreview': preview,
    'extractedText': extracted,
    'report': doc.report.toJson(),
    if (doc.parsedProfile != null)
      'parsedCv': doc.parsedProfile!.toPortfolioJson(),
  };
}

CVDocument _cvDocumentFromMap(Map<String, dynamic> raw) {
  final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
  return CVDocument(
    fileName: m['fileName'] as String? ?? 'document',
    uploadedAt:
        DateTime.tryParse(m['uploadedAt'] as String? ?? '') ?? DateTime.now(),
    contentPreview: m['contentPreview'] as String? ?? '',
    extractedText: m['extractedText'] as String? ?? '',
    report: ATSCheckReport.fromJson(
      Map<String, dynamic>.from(m['report'] as Map<dynamic, dynamic>),
    ),
    parsedProfile: m['parsedCv'] is Map
        ? ParsedCvProfile.fromJson(
            Map<String, dynamic>.from(m['parsedCv'] as Map<dynamic, dynamic>),
          )
        : null,
  );
}

_CompareBundle _compareInIsolate(Map<String, dynamic> payload) {
  final CVDocument older =
      _cvDocumentFromMap(Map<String, dynamic>.from(payload['older'] as Map));
  final CVDocument newer =
      _cvDocumentFromMap(Map<String, dynamic>.from(payload['newer'] as Map));
  return _CompareBundle(
    stats: ComparisonStats.fromDocuments(older, newer),
    contentDiff: CvContentDiff.between(older, newer),
  );
}

/// Runs CV diff + stats off the UI thread to avoid ANR on large résumés.
Future<CvCompareResult> compareCvsAsync(CVDocument a, CVDocument b) async {
  final bool aIsOlder = a.uploadedAt.isBefore(b.uploadedAt);
  final CVDocument older = aIsOlder ? a : b;
  final CVDocument newer = aIsOlder ? b : a;

  final Map<String, dynamic> payload = <String, dynamic>{
    'older': _cvDocumentToMap(older),
    'newer': _cvDocumentToMap(newer),
  };

  final _CompareBundle bundle = await compute(_compareInIsolate, payload);
  return CvCompareResult(
    stats: bundle.stats,
    contentDiff: bundle.contentDiff,
  );
}
