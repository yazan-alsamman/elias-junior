import 'dart:convert';
import 'dart:typed_data';

import 'package:app/common/api_config.dart';
import 'package:http/http.dart' as http;

/// Direct call to the local CV parser (Llama 3.2 + LoRA Uvicorn).
///
///   GET  {cvParserBaseUrl}/health
///   POST {cvParserBaseUrl}/parse/pdf         (multipart file, PDF only)
///   POST {cvParserBaseUrl}/parse             (JSON: { resume_text })
class LocalCvParserService {
  LocalCvParserService._();
  static final LocalCvParserService instance = LocalCvParserService._();

  String get _baseUrl => ApiConfig.cvParserBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<bool> ping({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final http.Response res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(timeout);
      if (res.statusCode != 200) return false;
      final Map<String, dynamic>? body =
          jsonDecode(res.body) as Map<String, dynamic>?;
      return body?['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Parse PDF directly. Returns `make_portfolio_json` shape (profile/skills/…).
  Future<Map<String, dynamic>?> parsePdf({
    required Uint8List fileBytes,
    required String fileName,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/parse/pdf');
    final http.MultipartRequest req = http.MultipartRequest('POST', uri);
    req.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );
    final http.StreamedResponse streamed = await req.send().timeout(timeout);
    final String body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      return null;
    }
    return jsonDecode(body) as Map<String, dynamic>?;
  }

  /// Parse plain text (used as DOCX fallback after a server-side text extract).
  Future<Map<String, dynamic>?> parseText({
    required String resumeText,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/parse');
    final http.Response res = await http
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'resume_text': resumeText,
            'max_new_tokens': 512,
            'heuristic_fill': true,
            'refine': false,
          }),
        )
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }
    return jsonDecode(res.body) as Map<String, dynamic>?;
  }
}
