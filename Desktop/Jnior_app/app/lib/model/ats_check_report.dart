class AtsRuleFailure {
  final String ruleId;
  final String severity;
  final String issue;
  final String fix;

  const AtsRuleFailure({
    this.ruleId = '',
    this.severity = '',
    this.issue = '',
    this.fix = '',
  });

  factory AtsRuleFailure.fromJson(Map<String, dynamic> j) {
    return AtsRuleFailure(
      ruleId: j['ruleId'] as String? ?? j['rule_id'] as String? ?? '',
      severity: j['severity'] as String? ?? '',
      issue: j['issue'] as String? ?? '',
      fix: j['fix'] as String? ?? '',
    );
  }
}

class ATSCheckReport {
  final int score;
  final String status;
  final DateTime checkedAt;
  final int keywordsChecked;
  final int keywordsTotal;
  final int formatScore;
  final String sectionMatch;
  final int estimatedSecondsLeft;
  /// Format-rule issues or keyword gaps from the ATS engine.
  final List<String> missingKeywords;
  final List<String> recommendations;
  final String suitabilityHeadline;
  final String issuesSummary;
  /// fastapi-ats-format-v1 | heuristic-fallback-v1 | heuristic-v1
  final String engine;
  final String decision;
  final int failedRulesCount;
  final bool failedBasic;
  final List<AtsRuleFailure> failures;

  /// ATS pass threshold: score above this counts as success.
  static const int passScoreThreshold = 70;

  /// True when [score] is above [passScoreThreshold].
  bool get isPassByScore => score > passScoreThreshold;

  /// PASS/FAIL derived from [score], not raw engine rules.
  String get scoreDecision => isPassByScore ? 'PASS' : 'FAIL';

  bool get isRealAts => engine == 'fastapi-ats-format-v1';

  bool get isUnavailable => engine == 'ats-unavailable';

  bool get isFallback =>
      engine == 'heuristic-fallback-v1' ||
      engine == 'heuristic-v1' ||
      isUnavailable;

  /// Short label for compare UI (legacy heuristic vs real ATS engine).
  String get engineLabel {
    if (isRealAts) return 'ATS';
    if (isFallback) return 'Legacy';
    return engine.isEmpty ? 'Unknown' : engine;
  }

  /// Whether [other] was scored with the same engine family (apples-to-apples).
  bool scoresAreComparable(ATSCheckReport other) {
    if (isUnavailable || other.isUnavailable) return false;
    if (isRealAts && other.isRealAts) return true;
    if (isFallback && other.isFallback) return true;
    return false;
  }

  /// Pill text on dashboard CV rows — driven by ATS score threshold.
  String get listBadgeLabel => scoreDecision;

  bool get listBadgeIsPositive => isPassByScore;

  factory ATSCheckReport.fromJson(Map<String, dynamic> j) {
    final List<String> miss = (j['missingKeywords'] as List<dynamic>?)
            ?.map((dynamic e) => e.toString())
            .toList() ??
        <String>[];
    final List<String> rec = (j['recommendations'] as List<dynamic>?)
            ?.map((dynamic e) => e.toString())
            .toList() ??
        <String>[];
    final List<AtsRuleFailure> fails = (j['failures'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(AtsRuleFailure.fromJson)
            .toList() ??
        <AtsRuleFailure>[];
    final String? checked = j['checkedAt'] as String?;
    final String engine = j['engine'] as String? ?? '';
    return ATSCheckReport(
      score: (j['score'] as num?)?.toInt() ?? 0,
      status: j['status'] as String? ?? '',
      checkedAt: DateTime.tryParse(checked ?? '') ?? DateTime.now(),
      keywordsChecked: (j['keywordsChecked'] as num?)?.toInt() ?? 0,
      keywordsTotal: (j['keywordsTotal'] as num?)?.toInt() ?? 0,
      formatScore: (j['formatScore'] as num?)?.toInt() ?? 0,
      sectionMatch: j['sectionMatch'] as String? ?? '',
      estimatedSecondsLeft:
          (j['estimatedSecondsLeft'] as num?)?.toInt() ?? 0,
      missingKeywords: miss,
      recommendations: rec,
      suitabilityHeadline: j['suitabilityHeadline'] as String? ?? '',
      issuesSummary: j['issuesSummary'] as String? ?? '',
      engine: engine,
      decision: j['decision'] as String? ?? '',
      failedRulesCount: (j['failedRulesCount'] as num?)?.toInt() ?? 0,
      failedBasic: j['failedBasic'] == true,
      failures: fails,
    );
  }

  static ATSCheckReport pending() {
    return ATSCheckReport(
      score: 0,
      status: 'Pending',
      checkedAt: DateTime.now(),
      keywordsChecked: 0,
      keywordsTotal: 0,
      formatScore: 0,
      sectionMatch: '—',
      estimatedSecondsLeft: 0,
      suitabilityHeadline: 'Analysis not run yet',
    );
  }

  /// Replace score/decision (e.g. restore from local ledger after Mongo returns 28).
  ATSCheckReport withScore(int newScore, {String? engineOverride}) {
    final String d =
        newScore > passScoreThreshold ? 'PASS' : 'FAIL';
    return ATSCheckReport(
      score: newScore,
      status: d,
      checkedAt: checkedAt,
      keywordsChecked: keywordsChecked,
      keywordsTotal: keywordsTotal,
      formatScore: newScore,
      sectionMatch: sectionMatch,
      estimatedSecondsLeft: estimatedSecondsLeft,
      missingKeywords: missingKeywords,
      recommendations: recommendations,
      suitabilityHeadline: suitabilityHeadline,
      issuesSummary: issuesSummary,
      engine: engineOverride ?? 'fastapi-ats-format-v1',
      decision: d,
      failedRulesCount: failedRulesCount,
      failedBasic: failedBasic,
      failures: failures,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'score': score,
        'status': status,
        'checkedAt': checkedAt.toIso8601String(),
        'keywordsChecked': keywordsChecked,
        'keywordsTotal': keywordsTotal,
        'formatScore': formatScore,
        'sectionMatch': sectionMatch,
        'estimatedSecondsLeft': estimatedSecondsLeft,
        'missingKeywords': missingKeywords,
        'recommendations': recommendations,
        'suitabilityHeadline': suitabilityHeadline,
        'issuesSummary': issuesSummary,
        'engine': engine,
        'decision': decision,
        'failedRulesCount': failedRulesCount,
        'failedBasic': failedBasic,
        'failures': failures
            .map(
              (AtsRuleFailure f) => <String, dynamic>{
                'ruleId': f.ruleId,
                'severity': f.severity,
                'issue': f.issue,
                'fix': f.fix,
              },
            )
            .toList(),
      };

  const ATSCheckReport({
    required this.score,
    required this.status,
    required this.checkedAt,
    required this.keywordsChecked,
    required this.keywordsTotal,
    required this.formatScore,
    required this.sectionMatch,
    required this.estimatedSecondsLeft,
    this.missingKeywords = const <String>[],
    this.recommendations = const <String>[],
    this.suitabilityHeadline = '',
    this.issuesSummary = '',
    this.engine = '',
    this.decision = '',
    this.failedRulesCount = 0,
    this.failedBasic = false,
    this.failures = const <AtsRuleFailure>[],
  });
}
