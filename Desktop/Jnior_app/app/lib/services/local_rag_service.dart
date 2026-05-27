import 'dart:convert';

import 'package:app/common/api_config.dart';
import 'package:app/model/job_match_report.dart';
import 'package:app/model/parsed_cv_profile.dart';
import 'package:app/services/rag_role_mapper.dart';
import 'package:http/http.dart' as http;

/// Client for the CV RAG API (`RAG/` folder, default port 8002).
class LocalRagService {
  LocalRagService._();
  static final LocalRagService instance = LocalRagService._();

  Uri get _healthUri => Uri.parse('${ApiConfig.ragBaseUrl}/health');
  Uri get _analyzeUri => Uri.parse('${ApiConfig.ragBaseUrl}/analyze-cv');
  Uri get _rolesUri => Uri.parse('${ApiConfig.ragBaseUrl}/roles');

  Future<bool> isReady() async {
    try {
      final http.Response res = await http
          .get(_healthUri)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return false;
      }
      final Object? decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      return decoded['openai_configured'] == true &&
          decoded['chroma_ready'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<RagRoleOption>> fetchRoles() async {
    try {
      final http.Response res = await http
          .get(_rolesUri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return RagRoleMapper.knownRoles;
      }
      final Object? decoded = jsonDecode(res.body);
      if (decoded is! List) {
        return RagRoleMapper.knownRoles;
      }
      final List<RagRoleOption> out = <RagRoleOption>[];
      for (final Object item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final String role = (item['role'] as String?) ?? '';
        final String label = (item['label'] as String?) ?? role;
        if (role.isNotEmpty) {
          out.add(RagRoleOption(role, label));
        }
      }
      return out.isEmpty ? RagRoleMapper.knownRoles : out;
    } catch (_) {
      return RagRoleMapper.knownRoles;
    }
  }

  Future<JobMatchReport> analyzeCv({
    required ParsedCvProfile profile,
    required String jobTitle,
    String company = '',
    String jobDescription = '',
    String? targetRole,
  }) async {
    final String role = RagRoleMapper.inferTargetRole(
      jobTitle: jobTitle,
      jobDescription: jobDescription,
      overrideRole: targetRole,
    );
    final Map<String, dynamic> body = <String, dynamic>{
      'target_role': role,
      'parsed_cv': profile.toPortfolioJson(),
    };

    final http.Response res = await http
        .post(
          _analyzeUri,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode == 503) {
      throw RagServiceException(
        'RAG not ready. Start RAG on ${ApiConfig.ragBaseUrl}, set OPENAI_API_KEY, run ingest.',
      );
    }
    if (res.statusCode != 200) {
      String detail = res.body;
      try {
        final Object? err = jsonDecode(res.body);
        if (err is Map && err['detail'] != null) {
          detail = err['detail'].toString();
        }
      } catch (_) {
        /* keep body */
      }
      throw RagServiceException('RAG analyze failed (${res.statusCode}): $detail');
    }

    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    return JobMatchReport.fromJson(
      json,
      jobTitle: jobTitle,
      company: company,
      jobDescription: jobDescription,
    );
  }
}

class RagServiceException implements Exception {
  RagServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
