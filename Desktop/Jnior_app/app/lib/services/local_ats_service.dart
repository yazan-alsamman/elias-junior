import 'dart:convert';
import 'dart:typed_data';

import 'package:app/common/api_config.dart';
import 'package:app/model/ats_check_report.dart';
import 'package:http/http.dart' as http;

/// Thrown when the ATS engine is unreachable or the wrong service is on the port.
class AtsServiceException implements Exception {
  AtsServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Result of probing the local ATS health endpoint.
class AtsPingResult {
  const AtsPingResult({required this.ok, this.reason});

  final bool ok;
  final String? reason;
}

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
    required this.extractedText,
    required this.raw,
  });

  /// "PASS" | "FAIL"
  final String decision;
  final bool failedBasic;
  final int failedRulesCount;
  final List<Map<String, dynamic>> failures;
  final List<String> improvements;
  final String recommendationMessage;
  /// Full résumé plain text from the local ATS engine (for portfolio heuristics).
  final String extractedText;
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
    final int computedScore = score;
    final String scoreDecision =
        computedScore > ATSCheckReport.passScoreThreshold ? 'PASS' : 'FAIL';
    return ATSCheckReport(
      score: computedScore,
      status: scoreDecision,
      checkedAt: DateTime.now(),
      keywordsChecked: failedRulesCount,
      keywordsTotal: failedRulesCount + (scoreDecision == 'PASS' ? 0 : 1),
      formatScore: computedScore,
      sectionMatch: scoreDecision == 'PASS'
          ? 'All format rules passed'
          : '$failedRulesCount format rule(s) failed',
      estimatedSecondsLeft: 0,
      missingKeywords: issueList,
      recommendations: improvements,
      suitabilityHeadline: recommendationMessage.isNotEmpty
          ? recommendationMessage
          : (scoreDecision == 'PASS'
              ? 'ATS format check passed'
              : 'ATS format issues found'),
      issuesSummary:
          'Local ATS — $decision, $failedRulesCount failed rule(s)',
      engine: 'fastapi-ats-format-v1',
      decision: scoreDecision,
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

  /// Quick health check — verifies the real ATS Rule Engine is listening.
  Future<bool> ping({Duration timeout = const Duration(seconds: 5)}) async {
    final AtsPingResult result = await diagnose(timeout: timeout);
    return result.ok;
  }

  /// Explains why ATS is offline (wrong port owner vs engine not started).
  Future<AtsPingResult> diagnose({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final Uri root = Uri.parse('$_baseUrl/');
    try {
      final http.Response res = await http.get(root).timeout(timeout);
      final String body = res.body.trim();

      if (res.statusCode == 404 &&
          body.contains('"success"') &&
          body.contains('Not found')) {
        return AtsPingResult(
          ok: false,
          reason:
              'Port ${ApiConfig.atsPort} is used by another app (not ATS). '
              'Stop that process or run: .\\start-ats-uvicorn.cmd',
        );
      }

      if (res.statusCode != 200) {
        return AtsPingResult(
          ok: false,
          reason: 'ATS HTTP ${res.statusCode} at $_baseUrl/',
        );
      }

      final Map<String, dynamic>? json =
          jsonDecode(body) as Map<String, dynamic>?;
      if (json?['service'] == 'ATS Rule Engine' && json?['status'] == 'ok') {
        return const AtsPingResult(ok: true);
      }

      return AtsPingResult(
        ok: false,
        reason:
            'Unexpected service on $_baseUrl/ — run .\\start-ats-uvicorn.cmd',
      );
    } catch (e) {
      return AtsPingResult(
        ok: false,
        reason:
            'Cannot reach ATS at $_baseUrl — run .\\start-local-dev.cmd (or .\\start-ats-uvicorn.cmd). '
            '$e',
      );
    }
  }

  Future<LocalAtsResult> analyzeFile({
    required Uint8List fileBytes,
    required String fileName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final AtsPingResult probe = await diagnose(timeout: const Duration(seconds: 5));
    if (!probe.ok) {
      throw AtsServiceException(
        probe.reason ??
            'ATS engine offline. Start: .\\start-ats-uvicorn.cmd (${ApiConfig.atsBaseUrl})',
      );
    }

    final Uri uri = Uri.parse('$_baseUrl/ats-format/check');
    final http.MultipartRequest req = http.MultipartRequest('POST', uri);
    req.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );
    final http.StreamedResponse streamed = await req.send().timeout(timeout);
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      if (streamed.statusCode == 404) {
        throw AtsServiceException(
          'ATS endpoint missing on ${ApiConfig.atsBaseUrl}. '
          'Wrong service on this port — run .\\start-ats-uvicorn.cmd',
        );
      }
      throw AtsServiceException(
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
      extractedText: (json['extracted_text'] ?? '').toString().trim(),
      raw: json,
    );
  }
}
