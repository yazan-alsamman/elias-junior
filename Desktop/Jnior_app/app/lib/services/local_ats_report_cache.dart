import 'dart:convert';
import 'dart:io';

import 'package:app/model/ats_check_report.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps real local ATS (:8000) scores across app reloads.
///
/// Mongo often stores heuristic score 28 when `extractedText` is a short placeholder.
/// We mirror scores to a JSON file under `cv_parsed/` because secure storage can fail on some devices.
class LocalAtsReportCache {
  LocalAtsReportCache._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _secureKey = 'careerpath_ats_reports_v1';
  static const String _diskFileName = 'ats_scores.json';

  static Future<Directory?> _folder() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final Directory base = await getApplicationDocumentsDirectory();
      final Directory dir =
          Directory('${base.path}${Platform.pathSeparator}cv_parsed');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      debugPrint('[LocalAtsReportCache] folder: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _readStore() async {
    final Directory? dir = await _folder();
    if (dir != null) {
      final File disk = File('${dir.path}${Platform.pathSeparator}$_diskFileName');
      if (await disk.exists()) {
        try {
          final Object? decoded = jsonDecode(await disk.readAsString());
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (e) {
          debugPrint('[LocalAtsReportCache] disk read: $e');
        }
      }
    }

    final String? raw = await _storage.read(key: _secureKey);
    if (raw == null || raw.trim().isEmpty) {
      return _emptyStore();
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      /* reset */
    }
    return _emptyStore();
  }

  static Map<String, dynamic> _emptyStore() => <String, dynamic>{
        'byId': <String, dynamic>{},
        'byFileName': <String, dynamic>{},
      };

  static Future<void> _writeStore(Map<String, dynamic> store) async {
    final String jsonStr = jsonEncode(store);
    await _storage.write(key: _secureKey, value: jsonStr);
    final Directory? dir = await _folder();
    if (dir != null) {
      final File disk = File('${dir.path}${Platform.pathSeparator}$_diskFileName');
      await disk.writeAsString(jsonStr, flush: true);
    }
  }

  /// Save any local ATS result (including PASS at 90/100).
  static Future<void> save({
    required ATSCheckReport report,
    String? documentId,
    String? fileName,
  }) async {
    if (report.isUnavailable || report.score <= 0) {
      return;
    }
    final Map<String, dynamic> store = await _readStore();
    final Map<String, dynamic> byId = Map<String, dynamic>.from(
      store['byId'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
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

  static Future<Map<String, ATSCheckReport>> loadAllByDocumentId() async {
    final Map<String, dynamic> store = await _readStore();
    final Map<String, dynamic> byId =
        store['byId'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, ATSCheckReport> out = <String, ATSCheckReport>{};
    for (final MapEntry<String, dynamic> e in byId.entries) {
      final ATSCheckReport? r = _decodeEntry(e.value);
      if (r != null) {
        out[e.key] = r;
      }
    }
    return out;
  }

  static Future<Map<String, ATSCheckReport>> loadAllByFileName() async {
    final Map<String, dynamic> store = await _readStore();
    final Map<String, dynamic> byFileName =
        store['byFileName'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, ATSCheckReport> out = <String, ATSCheckReport>{};
    for (final MapEntry<String, dynamic> e in byFileName.entries) {
      final ATSCheckReport? r = _decodeEntry(e.value);
      if (r != null) {
        out[e.key] = r;
      }
    }
    return out;
  }

  static bool isPlaceholderScore(ATSCheckReport report) {
    return report.isFallback ||
        report.engine == 'heuristic-v1' ||
        report.score == 28 ||
        report.issuesSummary.toLowerCase().contains('heuristic scan');
  }

  /// Always restore device-local ATS when we have a saved report for this CV.
  static bool shouldPreferLocal(ATSCheckReport api, ATSCheckReport local) {
    if (local.isUnavailable || local.score <= 0) {
      return false;
    }
    if (local.isRealAts) {
      return true;
    }
    return isPlaceholderScore(api) && local.score > api.score;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _secureKey);
    final Directory? dir = await _folder();
    if (dir != null) {
      final File disk = File('${dir.path}${Platform.pathSeparator}$_diskFileName');
      if (await disk.exists()) {
        await disk.delete();
      }
    }
  }
}
