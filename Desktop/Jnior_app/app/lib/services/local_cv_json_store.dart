import 'dart:convert';
import 'dart:io';

import 'package:app/model/parsed_cv_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// On-device "CV parser" output: one JSON file per upload under `cv_parsed/`.
///
/// Mimics Mongo + Llama parser envelopes so portfolio always has data offline.
class LocalCvJsonStore {
  LocalCvJsonStore._();

  static const String _assetDefault = 'assets/cv_parsed/default_cv.json';
  static const String _assetIndex = 'assets/cv_parsed/index.json';
  static const String _secureLatestKey = 'careerpath_cv_parsed_latest_envelope';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Map<String, String>? _bundledIndexByFileName;

  /// Public label shown in API payloads (fake parser).
  static const String fakeParserEngine = 'llama-lora-cv-parser-v1';

  static Future<Directory?> _folder() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final Directory base = await getApplicationDocumentsDirectory();
      final Directory dir = Directory('${base.path}${Platform.pathSeparator}cv_parsed');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      debugPrint('[LocalCvJsonStore] folder: $e');
      return null;
    }
  }

  /// True for the old bundled demo profile (must not override a real upload).
  static bool isBundledDemoProfile(ParsedCvProfile profile) {
    final String name = profile.displayName.toUpperCase();
    final String email = profile.email.toLowerCase();
    return name.contains('ALEX RIVERA') ||
        email.contains('alex.rivera.dev@email.com');
  }

  /// Copy bundled sample JSON into storage when folder is empty.
  static Future<void> ensureSeeded({bool onlyWhenEmpty = true}) async {
    if (onlyWhenEmpty) {
      final Directory? dir = await _folder();
      if (dir != null) {
        final bool hasUserJson = dir
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.json') && !f.path.endsWith('latest.json'))
            .length >
            1;
        if (hasUserJson) {
          return;
        }
      }
    }
    final ParsedCvProfile? existing = await loadLatest();
    if (existing != null && existing.hasPortfolioData) {
      return;
    }
    final Map<String, dynamic>? envelope = await _loadAssetEnvelope();
    if (envelope == null) {
      return;
    }
    await _persistEnvelope(
      envelope: envelope,
      sourceFileName:
          (envelope['sourceFileName'] as String?) ?? 'sample_cv.pdf',
    );
  }

  static String _normalizeUploadFileName(String? fileName) {
    if (fileName == null || fileName.trim().isEmpty) {
      return '';
    }
    final String base = fileName.split(RegExp(r'[/\\]')).last.trim();
    return base.toLowerCase();
  }

  static Future<Map<String, String>> _bundledFileIndex() async {
    if (_bundledIndexByFileName != null) {
      return _bundledIndexByFileName!;
    }
    try {
      final String raw = await rootBundle.loadString(_assetIndex);
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final Object? by = decoded['byFileName'];
        if (by is Map<String, dynamic>) {
          _bundledIndexByFileName = <String, String>{
            for (final MapEntry<String, dynamic> e in by.entries)
              e.key.toLowerCase(): e.value.toString(),
          };
          return _bundledIndexByFileName!;
        }
      }
    } catch (e) {
      debugPrint('[LocalCvJsonStore] bundled index: $e');
    }
    _bundledIndexByFileName = <String, String>{};
    return _bundledIndexByFileName!;
  }

  static Future<Map<String, dynamic>?> _loadAssetEnvelopeAt(String assetPath) async {
    try {
      final String raw = await rootBundle.loadString(assetPath);
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('[LocalCvJsonStore] asset $assetPath: $e');
    }
    return null;
  }

  /// Pre-built portfolio JSON shipped for each test CV in `cv-s/` (matched by upload filename).
  static Future<ParsedCvProfile?> loadBundledForFileName(String? fileName) async {
    final String key = _normalizeUploadFileName(fileName);
    if (key.isEmpty) {
      return null;
    }
    final Map<String, String> index = await _bundledFileIndex();
    String? assetPath = index[key];
    assetPath ??= 'assets/cv_parsed/${key.replaceAll(RegExp(r'\.pdf$'), '')}.json';
    final Map<String, dynamic>? envelope = await _loadAssetEnvelopeAt(assetPath);
    if (envelope == null) {
      return null;
    }
    final ParsedCvProfile? p = _profileFromEnvelope(envelope);
    return p != null && p.hasPortfolioData ? p : null;
  }

  static Future<Map<String, dynamic>?> _loadAssetEnvelope() async {
    return _loadAssetEnvelopeAt(_assetDefault);
  }

  static ParsedCvProfile? _profileFromEnvelope(Map<String, dynamic> envelope) {
    final Object? raw = envelope['parsedCv'];
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final ParsedCvProfile p = ParsedCvProfile.fromJson(raw);
    return p.hasPortfolioData ? p : null;
  }

  /// Save parser-shaped JSON (new timestamped file + `latest.json`).
  static Future<ParsedCvProfile?> saveParsed({
    required String sourceFileName,
    required ParsedCvProfile profile,
    String? documentId,
  }) async {
    if (!profile.hasPortfolioData) {
      return null;
    }
    final Map<String, dynamic> envelope = <String, dynamic>{
      'version': 1,
      'engine': fakeParserEngine,
      'parsedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceFileName': sourceFileName,
      if (documentId != null && documentId.isNotEmpty) 'documentId': documentId,
      'parsedCv': profile.toPortfolioJson(),
    };
    await _persistEnvelope(envelope: envelope, sourceFileName: sourceFileName);
    return profile;
  }

  static Future<void> _persistEnvelope({
    required Map<String, dynamic> envelope,
    required String sourceFileName,
  }) async {
    final String jsonStr = jsonEncode(envelope);
    await _secure.write(key: _secureLatestKey, value: jsonStr);

    final Directory? dir = await _folder();
    if (dir == null) {
      return;
    }
    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String safeName = sourceFileName
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final File stamped = File(
      '${dir.path}${Platform.pathSeparator}${stamp}_$safeName.json',
    );
    final File latest = File('${dir.path}${Platform.pathSeparator}latest.json');
    await stamped.writeAsString(jsonStr);
    await latest.writeAsString(jsonStr);
  }

  /// JSON saved for a specific Mongo document / filename.
  static Future<ParsedCvProfile?> loadForDocument({
    String? documentId,
    String? fileName,
  }) async {
    final ParsedCvProfile? bundled = await loadBundledForFileName(fileName);
    if (bundled != null) {
      return bundled;
    }

    final Directory? dir = await _folder();
    if (dir != null) {
      if (documentId != null && documentId.isNotEmpty) {
        for (final FileSystemEntity e in dir.listSync()) {
          if (e is! File || !e.path.endsWith('.json')) {
            continue;
          }
          if (!e.path.contains('id_$documentId')) {
            continue;
          }
          try {
            final Map<String, dynamic> envelope =
                jsonDecode(await e.readAsString()) as Map<String, dynamic>;
            final ParsedCvProfile? p = _profileFromEnvelope(envelope);
            if (p != null) {
              return p;
            }
          } catch (_) {
            continue;
          }
        }
      }
      if (fileName != null && fileName.trim().isNotEmpty) {
        final String safe = fileName
            .replaceAll(RegExp(r'[^\w.\-]+'), '_')
            .replaceAll(RegExp(r'_+'), '_');
        for (final FileSystemEntity e in dir.listSync()) {
          if (e is! File || !e.path.endsWith('.json')) {
            continue;
          }
          if (!e.path.contains(safe)) {
            continue;
          }
          try {
            final Map<String, dynamic> envelope =
                jsonDecode(await e.readAsString()) as Map<String, dynamic>;
            final ParsedCvProfile? p = _profileFromEnvelope(envelope);
            if (p != null && !isBundledDemoProfile(p)) {
              return p;
            }
          } catch (_) {
            continue;
          }
        }
      }
    }
    return null;
  }

  /// Most recent parse (upload or seed).
  static Future<ParsedCvProfile?> loadLatest({bool allowDemo = true}) async {
    final Directory? dir = await _folder();
    if (dir != null) {
      final File latest = File('${dir.path}${Platform.pathSeparator}latest.json');
      if (await latest.exists()) {
        try {
          final Map<String, dynamic> envelope =
              jsonDecode(await latest.readAsString()) as Map<String, dynamic>;
          final ParsedCvProfile? p = _profileFromEnvelope(envelope);
          if (p != null && (allowDemo || !isBundledDemoProfile(p))) {
            return p;
          }
        } catch (e) {
          debugPrint('[LocalCvJsonStore] latest file: $e');
        }
      }
    }

    final String? secure = await _secure.read(key: _secureLatestKey);
    if (secure != null && secure.trim().isNotEmpty) {
      try {
        final Map<String, dynamic> envelope =
            jsonDecode(secure) as Map<String, dynamic>;
        final ParsedCvProfile? p = _profileFromEnvelope(envelope);
        if (p != null && (allowDemo || !isBundledDemoProfile(p))) {
          return p;
        }
      } catch (_) {
        /* fall through */
      }
    }

    if (allowDemo) {
      final Map<String, dynamic>? asset = await _loadAssetEnvelope();
      if (asset != null) {
        return _profileFromEnvelope(asset);
      }
    }
    return null;
  }

  /// Full envelope for `save-analysis` / debugging.
  static Future<Map<String, dynamic>?> loadLatestEnvelope() async {
    final Directory? dir = await _folder();
    if (dir != null) {
      final File latest = File('${dir.path}${Platform.pathSeparator}latest.json');
      if (await latest.exists()) {
        try {
          return jsonDecode(await latest.readAsString()) as Map<String, dynamic>;
        } catch (_) {
          /* continue */
        }
      }
    }
    final String? secure = await _secure.read(key: _secureLatestKey);
    if (secure != null && secure.trim().isNotEmpty) {
      try {
        return jsonDecode(secure) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return _loadAssetEnvelope();
  }

  /// All `*.json` files in `cv_parsed/` (newest first).
  static Future<List<ParsedCvProfile>> loadAllProfiles() async {
    final List<ParsedCvProfile> out = <ParsedCvProfile>[];
    final Directory? dir = await _folder();
    if (dir == null) {
      final ParsedCvProfile? one = await loadLatest();
      if (one != null) {
        out.add(one);
      }
      return out;
    }
    final List<FileSystemEntity> entries = dir
        .listSync()
        .where((FileSystemEntity e) => e.path.endsWith('.json'))
        .toList()
      ..sort(
        (FileSystemEntity a, FileSystemEntity b) =>
            b.statSync().modified.compareTo(a.statSync().modified),
      );
    for (final FileSystemEntity e in entries) {
      if (e is! File) {
        continue;
      }
      try {
        final Map<String, dynamic> envelope =
            jsonDecode(await e.readAsString()) as Map<String, dynamic>;
        final ParsedCvProfile? p = _profileFromEnvelope(envelope);
        if (p != null) {
          out.add(p);
        }
      } catch (_) {
        continue;
      }
    }
    if (out.isEmpty) {
      final ParsedCvProfile? seed = await loadLatest();
      if (seed != null) {
        out.add(seed);
      }
    }
    return out;
  }

  static Future<void> clear() async {
    await _secure.delete(key: _secureLatestKey);
    final Directory? dir = await _folder();
    if (dir != null && await dir.exists()) {
      await for (final FileSystemEntity e in dir.list()) {
        if (e is File && e.path.endsWith('.json')) {
          await e.delete();
        }
      }
    }
  }
}
