import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Minimal score persistence — survives reload when full [ATSCheckReport] cache fails.
class AtsScoreLedgerEntry {
  const AtsScoreLedgerEntry({
    required this.score,
    required this.decision,
    this.engine = 'fastapi-ats-format-v1',
  });

  final int score;
  final String decision;
  final String engine;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'score': score,
        'decision': decision,
        'engine': engine,
      };

  factory AtsScoreLedgerEntry.fromJson(Map<String, dynamic> json) {
    return AtsScoreLedgerEntry(
      score: (json['score'] as num?)?.toInt() ?? 0,
      decision: (json['decision'] as String?) ?? 'FAIL',
      engine: (json['engine'] as String?) ?? 'fastapi-ats-format-v1',
    );
  }
}

abstract final class AtsScoreLedger {
  static const String _fileName = 'score_ledger.json';

  static Future<File?> _file() async {
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
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (e) {
      debugPrint('[AtsScoreLedger] $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _read() async {
    final File? f = await _file();
    if (f == null || !await f.exists()) {
      return <String, dynamic>{
        'byId': <String, dynamic>{},
        'byFileName': <String, dynamic>{},
      };
    }
    try {
      final Object? decoded = jsonDecode(await f.readAsString());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('[AtsScoreLedger] read: $e');
    }
    return <String, dynamic>{
      'byId': <String, dynamic>{},
      'byFileName': <String, dynamic>{},
    };
  }

  static Future<void> _write(Map<String, dynamic> data) async {
    final File? f = await _file();
    if (f == null) {
      return;
    }
    await f.writeAsString(jsonEncode(data), flush: true);
  }

  static Future<void> save({
    required int score,
    required String decision,
    String? documentId,
    String? fileName,
    String engine = 'fastapi-ats-format-v1',
  }) async {
    if (score <= 0) {
      return;
    }
    final Map<String, dynamic> data = await _read();
    final Map<String, dynamic> byId = Map<String, dynamic>.from(
      data['byId'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final Map<String, dynamic> byFileName = Map<String, dynamic>.from(
      data['byFileName'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final String blob = jsonEncode(
      AtsScoreLedgerEntry(score: score, decision: decision, engine: engine).toJson(),
    );
    if (documentId != null && documentId.isNotEmpty) {
      byId[documentId] = blob;
    }
    if (fileName != null && fileName.trim().isNotEmpty) {
      byFileName[fileName.trim()] = blob;
    }
    data['byId'] = byId;
    data['byFileName'] = byFileName;
    await _write(data);
  }

  static Future<AtsScoreLedgerEntry?> loadFor({
    String? documentId,
    String? fileName,
  }) async {
    final Map<String, dynamic> data = await _read();
    final Map<String, dynamic> byId =
        data['byId'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> byFileName =
        data['byFileName'] as Map<String, dynamic>? ?? <String, dynamic>{};

    if (documentId != null && documentId.isNotEmpty) {
      final Object? raw = byId[documentId];
      if (raw is String) {
        try {
          return AtsScoreLedgerEntry.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
        } catch (_) {
          /* continue */
        }
      }
    }
    if (fileName != null && fileName.trim().isNotEmpty) {
      final Object? raw = byFileName[fileName.trim()];
      if (raw is String) {
        try {
          return AtsScoreLedgerEntry.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static Future<Map<String, AtsScoreLedgerEntry>> loadAllByFileName() async {
    final Map<String, dynamic> data = await _read();
    final Map<String, dynamic> byFileName =
        data['byFileName'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, AtsScoreLedgerEntry> out = <String, AtsScoreLedgerEntry>{};
    for (final MapEntry<String, dynamic> e in byFileName.entries) {
      if (e.value is String) {
        try {
          out[e.key] = AtsScoreLedgerEntry.fromJson(
            jsonDecode(e.value as String) as Map<String, dynamic>,
          );
        } catch (_) {
          continue;
        }
      }
    }
    return out;
  }

  static Future<void> clear() async {
    final File? f = await _file();
    if (f != null && await f.exists()) {
      await f.delete();
    }
  }
}
