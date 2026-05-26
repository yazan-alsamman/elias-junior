import 'dart:convert';
import 'dart:typed_data';

import 'package:app/common/api_config.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:http/http.dart' as http;

/// Direct multipart call to the local Uvicorn ATS rule engine.
///
///   POST {atsBaseUrl}/ats-format/check    (field: file)
///
/// Returns the raw FastAPI JSON: `{ decision, failed_basic, failed_rules_count,
/// failures, recommendation: { message, improvements } ... }`.
class LocalAtsResult {
  LocalAtsResult({
    required this.decision,
    required this.failedBasic,
    required this.failedRulesCount,
    required this.failures,
    required this.improvements,
    required this.recommendationMessage,
    required this.raw,
  });

  /// "PASS" | "FAIL"
  final String decision;
  final bool failedBasic;
  final int failedRulesCount;
  final List<Map<String, dynamic>> failures;
  final List<String> improvements;
  final String recommendationMessage;
  final Map<String, dynamic> raw;

  bool get isPass => decision.toUpperCase() == 'PASS';

  /// Map FastAPI decision → numeric score the rest of the app already uses.
  /// 100 on PASS, otherwise 100 − 10·rules − 25 if any basic rule failed.
  int get score {
    if (isPass) return 100;
    final int penalty = failedRulesCount * 10 + (failedBasic ? 25 : 0);
    return (100 - penalty).clamp(5, 99);
  }

  List<String> get issueList =>
      failures.map((Map<String, dynamic> f) => (f['issue'] ?? '').toString()).where((String s) => s.isNotEmpty).toList();

  /// Map local FastAPI output to the report shape the Flutter UI expects.
  ATSCheckReport toAtsCheckReport() {
    return ATSCheckReport(
      score: score,
      status: isPass ? 'PASS' : 'FAIL',
      checkedAt: DateTime.now(),
      keywordsChecked: failedRulesCount,
      keywordsTotal: failedRulesCount + (isPass ? 0 : 1),
      formatScore: score,
      sectionMatch: isPass
          ? 'All format rules passed'
          : '$failedRulesCount format rule(s) failed',
      estimatedSecondsLeft: 0,
      missingKeywords: issueList,
      recommendations: improvements,
      suitabilityHeadline: recommendationMessage.isNotEmpty
          ? recommendationMessage
          : (isPass ? 'ATS format check passed' : 'ATS format issues found'),
      issuesSummary:
          'Local ATS — $decision, $failedRulesCount failed rule(s)',
      engine: 'fastapi-ats-format-v1',
      decision: decision,
      failedRulesCount: failedRulesCount,
      failedBasic: failedBasic,
      failures: failures.map(AtsRuleFailure.fromJson).toList(),
    );
  }
}

class LocalAtsService {
  LocalAtsService._();
  static final LocalAtsService instance = LocalAtsService._();

  String get _baseUrl => ApiConfig.atsBaseUrl.replaceAll(RegExp(r'/+$'), '');

  /// Quick `GET /` health check.
  Future<bool> ping({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final http.Response res = await http
          .get(Uri.parse('$_baseUrl/'))
          .timeout(timeout);
      if (res.statusCode != 200) return false;
      final Map<String, dynamic>? body =
          jsonDecode(res.body) as Map<String, dynamic>?;
      return body?['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<LocalAtsResult> analyzeFile({
    required Uint8List fileBytes,
    required String fileName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/ats-format/check');
    final http.MultipartRequest req = http.MultipartRequest('POST', uri);
    req.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );
    final http.StreamedResponse streamed = await req.send().timeout(timeout);
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception(
        'ATS HTTP ${streamed.statusCode}: ${body.substring(0, body.length.clamp(0, 240))}',
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(body) as Map<String, dynamic>;
    final Map<String, dynamic> rec =
        (json['recommendation'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final List<dynamic> failsRaw =
        (json['failures'] as List<dynamic>?) ?? const <dynamic>[];
    final List<Map<String, dynamic>> failures = failsRaw
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> m) => <String, dynamic>{
              'ruleId': m['rule_id']?.toString() ?? '',
              'severity': m['severity']?.toString() ?? '',
              'issue': m['issue']?.toString() ?? '',
              'fix': m['fix']?.toString() ?? '',
            })
        .toList();
    final List<dynamic> impRaw =
        (rec['improvements'] as List<dynamic>?) ?? const <dynamic>[];

    return LocalAtsResult(
      decision: (json['decision'] ?? 'FAIL').toString(),
      failedBasic: json['failed_basic'] == true,
      failedRulesCount: (json['failed_rules_count'] as num?)?.toInt() ?? 0,
      failures: failures,
      improvements: impRaw
          .map((dynamic e) => e.toString())
          .where((String s) => s.trim().isNotEmpty)
          .toList(),
      recommendationMessage: (rec['message'] ?? '').toString(),
      raw: json,
    );
  }
}
