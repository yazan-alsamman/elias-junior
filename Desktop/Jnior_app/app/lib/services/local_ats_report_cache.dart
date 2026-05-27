import 'dart:convert';

import 'package:app/model/ats_check_report.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps real local ATS (:8000) scores across app reloads.
///
/// Mongo often stores heuristic score 28 when `extractedText` is a short placeholder.
class LocalAtsReportCache {
  LocalAtsReportCache._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'careerpath_ats_reports_v1';

  static Future<Map<String, dynamic>> _readStore() async {
    final String? raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{
        'byId': <String, dynamic>{},
        'byFileName': <String, dynamic>{},
      };
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      /* reset */
    }
    return <String, dynamic>{
      'byId': <String, dynamic>{},
      'byFileName': <String, dynamic>{},
    };
  }

  static Future<void> _writeStore(Map<String, dynamic> store) async {
    await _storage.write(key: _key, value: jsonEncode(store));
  }

  static Future<void> save({
    required ATSCheckReport report,
    String? documentId,
    String? fileName,
  }) async {
    if (!report.isRealAts) {
      return;
    }
    final Map<String, dynamic> store = await _readStore();
    final Map<String, dynamic> byId =
        Map<String, dynamic>.from(store['byId'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final Map<String, dynamic> byFileName = Map<String, dynamic>.from(
      store['byFileName'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final String encoded = jsonEncode(report.toJson());
    if (documentId != null && documentId.isNotEmpty) {
      byId[documentId] = encoded;
    }
    if (fileName != null && fileName.trim().isNotEmpty) {
      byFileName[fileName.trim()] = encoded;
    }
    store['byId'] = byId;
    store['byFileName'] = byFileName;
    await _writeStore(store);
  }

  static ATSCheckReport? _decodeEntry(Object? entry) {
    if (entry is! String || entry.trim().isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(entry) as Map<String, dynamic>;
      return ATSCheckReport.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<ATSCheckReport?> loadFor({
    String? documentId,
    String? fileName,
  }) async {
    final Map<String, dynamic> store = await _readStore();
    final Map<String, dynamic> byId =
        store['byId'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> byFileName =
        store['byFileName'] as Map<String, dynamic>? ?? <String, dynamic>{};

    if (documentId != null && documentId.isNotEmpty) {
      final ATSCheckReport? fromId = _decodeEntry(byId[documentId]);
      if (fromId != null) {
        return fromId;
      }
    }
    if (fileName != null && fileName.trim().isNotEmpty) {
      return _decodeEntry(byFileName[fileName.trim()]);
    }
    return null;
  }

  /// Replace heuristic / placeholder Mongo scores with cached local ATS results.
  static bool isPlaceholderScore(ATSCheckReport report) {
    return report.isFallback ||
        report.engine == 'heuristic-v1' ||
        report.score == 28 ||
        report.issuesSummary.toLowerCase().contains('heuristic scan');
  }

  static bool shouldPreferLocal(ATSCheckReport api, ATSCheckReport local) {
    if (!local.isRealAts) {
      return false;
    }
    if (isPlaceholderScore(api)) {
      return true;
    }
    if (api.isRealAts && api.score == 28 && local.score != 28) {
      return true;
    }
    return false;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
