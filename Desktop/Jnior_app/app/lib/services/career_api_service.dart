import 'dart:convert';
import 'dart:typed_data';

import 'package:app/common/api_config.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/services/auth_api_service.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// Authenticated CareerPath API — CV storage, ATS (heuristic), pipeline, GitHub, portfolio.
class CareerApiService extends GetxService {
  static CareerApiService get to => Get.find<CareerApiService>();

  AuthApiService get _auth => Get.find<AuthApiService>();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<List<CVDocument>> documentsList() async {
    final http.Response res = await http.get(
      _uri('/api/cv/documents'),
      headers: _auth.authorizedJsonHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load CVs (${res.statusCode})');
    }
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> list = body['documents'] as List<dynamic>? ?? <dynamic>[];
    return list
        .map((dynamic e) => CVDocument.fromApi(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> createDocument({
    required String originalFileName,
    required String fileType,
    required String extractedText,
  }) async {
    final http.Response res = await http.post(
      _uri('/api/cv/documents'),
      headers: _auth.authorizedJsonHeaders(),
      body: jsonEncode(<String, String>{
        'originalFileName': originalFileName,
        'fileType': fileType,
        'extractedText': extractedText,
        'documentStage': 'uploaded',
        'generatedBy': 'user',
      }),
    );
    final Map<String, dynamic>? body =
        jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 201) {
      throw Exception(body?['error'] as String? ?? 'Create failed');
    }
    return body!;
  }

  /// Upload file → Node ATS check (+ optional CV parser on :8001).
  /// Response: `{ document, profileId?, parsedCv?, parseEngine? }`.
  Future<Map<String, dynamic>> uploadFileAndAnalyze({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final Uri uri = _uri('/api/cv/documents/upload-analyze');
    final http.MultipartRequest req = http.MultipartRequest('POST', uri);
    final String? token = _auth.token;
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );
    final http.StreamedResponse streamed = await req.send();
    final String body = await streamed.stream.bytesToString();
    final Map<String, dynamic>? decoded =
        jsonDecode(body) as Map<String, dynamic>?;
    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception(decoded?['error'] as String? ?? 'Upload analysis failed');
    }
    return decoded!;
  }

  /// Save local ATS results to Hostinger. If `save-analysis` is missing (404),
  /// falls back to `upload-analyze` on Hostinger (same login token).
  Future<Map<String, dynamic>> saveLocalAnalysis({
    required String originalFileName,
    required String fileType,
    required Map<String, dynamic> ats,
    Map<String, dynamic>? parsedCv,
    String parseEngine = '',
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      return await _postSaveAnalysis(
        baseUrl: ApiConfig.baseUrl,
        originalFileName: originalFileName,
        fileType: fileType,
        ats: ats,
        parsedCv: parsedCv,
        parseEngine: parseEngine,
      );
    } catch (e) {
      final String msg = e.toString();
      if (_isAuthError(msg)) {
        throw Exception(
          'Session expired — log out and sign in again, then re-upload your CV.',
        );
      }

      final bool is404 = msg.contains('404') || msg.contains('Not found');

      // Hostinger upload-analyze (same JWT) when save-analysis not deployed yet.
      if (is404 &&
          fileBytes != null &&
          fileName != null &&
          fileName.isNotEmpty) {
        final Map<String, dynamic> uploaded = await uploadFileAndAnalyze(
          fileBytes: fileBytes,
          fileName: fileName,
        );
        uploaded['_saveVia'] = 'upload-analyze';
        return uploaded;
      }

      // Optional: local Node only when explicitly enabled AND JWT matches.
      if (is404 &&
          ApiConfig.useLocalNodeSaveFallback &&
          ApiConfig.baseUrl != ApiConfig.localStorageFallbackUrl) {
        try {
          return await _postSaveAnalysis(
            baseUrl: ApiConfig.localStorageFallbackUrl,
            originalFileName: originalFileName,
            fileType: fileType,
            ats: ats,
            parsedCv: parsedCv,
            parseEngine: parseEngine,
          );
        } catch (localErr) {
          final String localMsg = localErr.toString();
          if (_isAuthError(localMsg)) {
            throw Exception(
              'Local Node rejected your login token. Sign in with API_BASE=http://127.0.0.1:3003 '
              'or set the same JWT_SECRET on Hostinger and local backend/.env.',
            );
          }
          rethrow;
        }
      }

      if (is404) {
        throw Exception(
          'Server missing save-analysis route. Deploy latest backend to Hostinger '
          'or run Node on :3003 with LOCAL_NODE_SAVE=true and matching JWT_SECRET.',
        );
      }
      rethrow;
    }
  }

  bool _isAuthError(String msg) =>
      msg.contains('Invalid token') ||
      msg.contains('Unauthorized') ||
      msg.contains('401');

  Future<Map<String, dynamic>> _postSaveAnalysis({
    required String baseUrl,
    required String originalFileName,
    required String fileType,
    required Map<String, dynamic> ats,
    Map<String, dynamic>? parsedCv,
    String parseEngine = '',
  }) async {
    final Uri uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/cv/documents/save-analysis',
    );
    final http.Response res = await http.post(
      uri,
      headers: _auth.authorizedJsonHeaders(),
      body: jsonEncode(<String, dynamic>{
        'originalFileName': originalFileName,
        'fileType': fileType,
        'ats': ats,
        'parsedCv': ?parsedCv,
        if (parseEngine.isNotEmpty) 'parseEngine': parseEngine,
      }),
    );
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      body = null;
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      final String err = body?['error'] as String? ??
          'HTTP ${res.statusCode} from $uri';
      throw Exception(err);
    }
    return body!;
  }

  /// Stored parser JSON + portfolio field defaults from Mongo.
  Future<Map<String, dynamic>> fetchParsedProfile(String documentId) async {
    final http.Response res = await http.get(
      _uri('/api/cv/documents/$documentId/parsed-profile'),
      headers: _auth.authorizedJsonHeaders(),
    );
    final Map<String, dynamic>? body =
        jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 200) {
      throw Exception(body?['error'] as String? ?? 'Parsed profile not found');
    }
    return body!;
  }

  Future<Map<String, dynamic>> analyzeDocument(String documentId) async {
    final http.Response res = await http.post(
      _uri('/api/cv/documents/$documentId/analyze'),
      headers: _auth.authorizedJsonHeaders(),
    );
    final Map<String, dynamic>? body =
        jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 200) {
      throw Exception(body?['error'] as String? ?? 'Analyze failed');
    }
    return body!;
  }

  Future<Map<String, dynamic>> pipelineSummary() async {
    final http.Response res = await http.get(
      _uri('/api/pipeline/summary'),
      headers: _auth.authorizedJsonHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('Pipeline summary failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getGithub() async {
    final http.Response res = await http.get(
      _uri('/api/github'),
      headers: _auth.authorizedJsonHeaders(),
    );
    if (res.statusCode != 200) {
      return null;
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> linkGithub(String githubUsername) async {
    final http.Response res = await http.put(
      _uri('/api/github'),
      headers: _auth.authorizedJsonHeaders(),
      body: jsonEncode(<String, String>{'githubUsername': githubUsername}),
    );
    if (res.statusCode != 200) {
      final Map<String, dynamic>? body =
          jsonDecode(res.body) as Map<String, dynamic>?;
      throw Exception(body?['error'] as String? ?? 'GitHub link failed');
    }
  }

  Future<Map<String, dynamic>> upsertPortfolio({
    required String documentId,
    String templateId = 'classic',
    String portfolioUrl = '',
    String githubUsername = '',
    List<String> projects = const <String>[],
    Map<String, dynamic>? previewSnapshot,
  }) async {
    final Map<String, dynamic> bodyMap = <String, dynamic>{
      'documentId': documentId,
      'templateId': templateId,
      if (portfolioUrl.trim().isNotEmpty) 'portfolioUrl': portfolioUrl.trim(),
      'githubUsername': githubUsername.trim(),
      'projectRepos': projects,
      ...?previewSnapshot != null
          ? <String, dynamic>{'previewSnapshot': previewSnapshot}
          : null,
    };
    final http.Response res = await http.post(
      _uri('/api/portfolio'),
      headers: _auth.authorizedJsonHeaders(),
      body: jsonEncode(bodyMap),
    );
    final Map<String, dynamic>? body =
        jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(body?['error'] as String? ?? 'Portfolio save failed');
    }
    return body ?? <String, dynamic>{};
  }
}
