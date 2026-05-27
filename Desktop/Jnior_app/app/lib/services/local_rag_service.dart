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
      cvProfile: profile,
    );
    final Map<String, dynamic> body = _buildAnalyzeBody(profile, role);

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

  /// Rich shape so RAG normalizes skills, years, and education from real CV JSON.
  static Map<String, dynamic> _buildAnalyzeBody(
    ParsedCvProfile profile,
    String targetRole,
  ) {
    return <String, dynamic>{
      'target_role': targetRole,
      'name': profile.displayName,
      'skills': profile.skills,
      'certifications': profile.certifications,
      'work_experience': profile.experience
          .map(
            (Map<String, dynamic> e) => <String, dynamic>{
              'position': e['position'] ?? '',
              'company': e['company'] ?? '',
              'duration': e['period'] ?? e['duration'] ?? '',
              'description': e['description'] ?? '',
            },
          )
          .toList(),
      'education': profile.education,
      'projects': profile.projects,
      'parsed_cv': profile.toPortfolioJson(),
    };
  }

  static String previewTargetRole({
    required String jobTitle,
    String jobDescription = '',
    String? overrideRole,
    ParsedCvProfile? cvProfile,
  }) {
    return RagRoleMapper.labelForRole(
      RagRoleMapper.inferTargetRole(
        jobTitle: jobTitle,
        jobDescription: jobDescription,
        overrideRole: overrideRole,
        cvProfile: cvProfile,
      ),
    );
  }
}

class RagServiceException implements Exception {
  RagServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
