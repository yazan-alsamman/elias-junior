import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/parsed_cv_profile.dart';
import 'package:app/services/cv_content_diff.dart';

/// One row in the metric-by-metric comparison table.
class MetricCompareRow {
  final String label;
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

/// Small, capped copy of CV data used for compare — avoids parsing large text.
class CvCompareSnapshot {
  const CvCompareSnapshot({
    required this.fileName,
    required this.uploadedAt,
    required this.score,
    required this.formatScore,
    required this.keywordsChecked,
    required this.keywordsTotal,
    required this.sectionMatch,
    required this.engine,
    required this.missingKeywords,
    required this.ruleIssues,
    required this.skills,
    required this.certifications,
    required this.experience,
    required this.education,
  });

  final String fileName;
  final DateTime uploadedAt;
  final int score;
  final int formatScore;
  final int keywordsChecked;
  final int keywordsTotal;
  final String sectionMatch;
  final String engine;
  final List<String> missingKeywords;
  final List<String> ruleIssues;
  final List<String> skills;
  final List<String> certifications;
  final List<String> experience;
  final List<String> education;

  String get engineLabel {
    if (engine == 'fastapi-ats-format-v1') return 'ATS';
    if (engine == 'heuristic-fallback-v1' ||
        engine == 'heuristic-v1' ||
        engine == 'ats-unavailable') {
      return 'Legacy';
    }
    return engine.isEmpty ? 'Unknown' : engine;
  }

  bool scoresAreComparableWith(CvCompareSnapshot other) {
    if (engine == 'ats-unavailable' || other.engine == 'ats-unavailable') {
      return false;
    }
    final bool aReal = engine == 'fastapi-ats-format-v1';
    final bool bReal = other.engine == 'fastapi-ats-format-v1';
    if (aReal && bReal) return true;
    final bool aLegacy = engine == 'heuristic-fallback-v1' ||
        engine == 'heuristic-v1';
    final bool bLegacy = other.engine == 'heuristic-fallback-v1' ||
        other.engine == 'heuristic-v1';
    return aLegacy && bLegacy;
  }

  ATSCheckReport toReport() {
    return ATSCheckReport(
      score: score,
      status: score > ATSCheckReport.passScoreThreshold ? 'PASS' : 'FAIL',
      checkedAt: uploadedAt,
      keywordsChecked: keywordsChecked,
      keywordsTotal: keywordsTotal,
      formatScore: formatScore,
      sectionMatch: sectionMatch,
      estimatedSecondsLeft: 0,
      missingKeywords: missingKeywords,
      engine: engine,
      decision: score > ATSCheckReport.passScoreThreshold ? 'PASS' : 'FAIL',
      failures: ruleIssues
          .map((String issue) => AtsRuleFailure(issue: issue))
          .toList(),
    );
  }

  static CvCompareSnapshot fromDocument(CVDocument doc) {
    final ATSCheckReport r = doc.report;
    final ParsedCvProfile? p = doc.parsedProfile;
    return CvCompareSnapshot(
      fileName: doc.fileName,
      uploadedAt: doc.uploadedAt,
      score: r.score,
      formatScore: r.formatScore,
      keywordsChecked: r.keywordsChecked,
      keywordsTotal: r.keywordsTotal,
      sectionMatch: r.sectionMatch,
      engine: r.engine,
      missingKeywords: _capStrings(r.missingKeywords, 120),
      ruleIssues: _capStrings(
        r.failures.map((AtsRuleFailure f) => f.issue.trim()).where((String s) => s.isNotEmpty),
        80,
      ),
      skills: _capStrings(p?.skills ?? const <String>[], 120),
      certifications: _capStrings(p?.certifications ?? const <String>[], 60),
      experience: _capStrings(_experienceLines(p), 40),
      education: _capStrings(_educationLines(p), 30),
    );
  }

  static List<String> _capStrings(Iterable<String> items, int max) {
    return items
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .take(max)
        .toList();
  }

  static List<String> _experienceLines(ParsedCvProfile? p) {
    if (p == null || p.experience.isEmpty) return const <String>[];
    return p.experience.map(_formatRole).where((String s) => s.isNotEmpty).toList();
  }

  static List<String> _educationLines(ParsedCvProfile? p) {
    if (p == null || p.education.isEmpty) return const <String>[];
    return p.education.map(_formatEdu).where((String s) => s.isNotEmpty).toList();
  }

  static String _formatRole(Map<String, dynamic> m) {
    final String title = '${m['title'] ?? m['role'] ?? ''}'.trim();
    final String company = '${m['company'] ?? m['employer'] ?? ''}'.trim();
    if (title.isEmpty && company.isEmpty) return '';
    if (company.isEmpty) return title;
    if (title.isEmpty) return company;
    return '$title @ $company';
  }

  static String _formatEdu(Map<String, dynamic> m) {
    final String degree = '${m['degree'] ?? m['qualification'] ?? ''}'.trim();
    final String school = '${m['school'] ?? m['institution'] ?? ''}'.trim();
    if (degree.isEmpty && school.isEmpty) return '';
    if (school.isEmpty) return degree;
    if (degree.isEmpty) return school;
    return '$degree — $school';
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

  int get scoreChangePercent {
    if (!scoresComparable) return 0;
    final int base = older.score;
    if (base <= 0) {
      if (newer.score <= 0) return 0;
      return 100;
    }
    return ((scoreDelta / base) * 100).round();
  }

  factory ComparisonStats.fromSnapshots(
    CvCompareSnapshot oldSnap,
    CvCompareSnapshot newSnap,
  ) {
    final Set<String> oldKw = oldSnap.missingKeywords
        .map((String s) => s.toLowerCase())
        .toSet();
    final Set<String> newKw = newSnap.missingKeywords
        .map((String s) => s.toLowerCase())
        .toSet();
    final List<String> resolved = oldSnap.missingKeywords
        .where((String k) => !newKw.contains(k.toLowerCase()))
        .toList();
    final List<String> newlyMissing = newSnap.missingKeywords
        .where((String k) => !oldKw.contains(k.toLowerCase()))
        .toList();

    final ({int num, int den}) oldSec = _parseFraction(oldSnap.sectionMatch);
    final ({int num, int den}) newSec = _parseFraction(newSnap.sectionMatch);
    final bool scoresComparable = oldSnap.scoresAreComparableWith(newSnap);
    final ATSCheckReport older = oldSnap.toReport();
    final ATSCheckReport newer = newSnap.toReport();

    final List<MetricCompareRow> rows = <MetricCompareRow>[
      MetricCompareRow(
        label: 'ATS score',
        iconKey: 'shield',
        oldVal: oldSnap.score,
        newVal: newSnap.score,
        oldDisplay: '${oldSnap.score}/100 (${oldSnap.engineLabel})',
        newDisplay: '${newSnap.score}/100 (${newSnap.engineLabel})',
        showDelta: scoresComparable,
      ),
      MetricCompareRow(
        label: 'Format score',
        iconKey: 'format',
        oldVal: oldSnap.formatScore,
        newVal: newSnap.formatScore,
        oldDisplay: '${oldSnap.formatScore}%',
        newDisplay: '${newSnap.formatScore}%',
      ),
      MetricCompareRow(
        label: 'Keywords matched',
        iconKey: 'key',
        oldVal: oldSnap.keywordsChecked,
        newVal: newSnap.keywordsChecked,
        oldDisplay: oldSnap.keywordsTotal > 0
            ? '${oldSnap.keywordsChecked}/${oldSnap.keywordsTotal}'
            : '${oldSnap.keywordsChecked}',
        newDisplay: newSnap.keywordsTotal > 0
            ? '${newSnap.keywordsChecked}/${newSnap.keywordsTotal}'
            : '${newSnap.keywordsChecked}',
      ),
      MetricCompareRow(
        label: 'Sections covered',
        iconKey: 'sections',
        oldVal: oldSec.num,
        newVal: newSec.num,
        oldDisplay: oldSnap.sectionMatch.isEmpty ? '—' : oldSnap.sectionMatch,
        newDisplay: newSnap.sectionMatch.isEmpty ? '—' : newSnap.sectionMatch,
      ),
      MetricCompareRow(
        label: 'Missing keywords',
        iconKey: 'warning',
        oldVal: oldSnap.missingKeywords.length,
        newVal: newSnap.missingKeywords.length,
        oldDisplay: '${oldSnap.missingKeywords.length}',
        newDisplay: '${newSnap.missingKeywords.length}',
        higherIsBetter: false,
      ),
    ];

    return ComparisonStats(
      older: older,
      newer: newer,
      scoresComparable: scoresComparable,
      scoreDelta: scoresComparable ? newSnap.score - oldSnap.score : 0,
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

class CvCompareResult {
  const CvCompareResult({
    required this.older,
    required this.newer,
    required this.stats,
    required this.contentDiff,
  });

  final CvCompareSnapshot older;
  final CvCompareSnapshot newer;
  final ComparisonStats stats;
  final CvContentDiff contentDiff;
}

/// Instant in-memory compare — no isolates, no text parsing, no async.
CvCompareResult compareDocuments(CVDocument a, CVDocument b) {
  final CvCompareSnapshot snapA = CvCompareSnapshot.fromDocument(a);
  final CvCompareSnapshot snapB = CvCompareSnapshot.fromDocument(b);
  final bool aIsOlder = snapA.uploadedAt.isBefore(snapB.uploadedAt);
  final CvCompareSnapshot older = aIsOlder ? snapA : snapB;
  final CvCompareSnapshot newer = aIsOlder ? snapB : snapA;
  return CvCompareResult(
    older: older,
    newer: newer,
    stats: ComparisonStats.fromSnapshots(older, newer),
    contentDiff: CvContentDiff.fromSnapshots(older, newer),
  );
}
