import 'dart:convert';
import 'dart:io';

import 'package:app/model/job_match_report.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persists RAG job-fit reports next to `cv_parsed/` JSON.
class JobMatchCache {
  JobMatchCache._();

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
      debugPrint('[JobMatchCache] $e');
      return null;
    }
  }

  static String _safeName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static Future<void> save({
    required String fileName,
    required JobMatchReport report,
    String? documentId,
  }) async {
    final Directory? dir = await _folder();
    if (dir == null) {
      return;
    }
    final String safe = _safeName(fileName);
    final String idPart =
        documentId != null && documentId.isNotEmpty ? 'id_$documentId' : '';
    final File file = File(
      '${dir.path}${Platform.pathSeparator}job_match_${idPart}_$safe.json',
    );
    await file.writeAsString(jsonEncode(report.toJson()));
    final File latest =
        File('${dir.path}${Platform.pathSeparator}job_match_latest.json');
    await latest.writeAsString(jsonEncode(report.toJson()));
  }

  static Future<JobMatchReport?> load({
    String? fileName,
    String? documentId,
  }) async {
    final Directory? dir = await _folder();
    if (dir == null) {
      return null;
    }
    if (documentId != null && documentId.isNotEmpty) {
      for (final FileSystemEntity e in dir.listSync()) {
        if (e is! File || !e.path.contains('job_match_id_$documentId')) {
          continue;
        }
        try {
          return JobMatchReport.fromJson(
            jsonDecode(await e.readAsString()) as Map<String, dynamic>,
            jobTitle: '',
          );
        } catch (_) {
          continue;
        }
      }
    }
    if (fileName != null && fileName.trim().isNotEmpty) {
      final String safe = _safeName(fileName);
      for (final FileSystemEntity e in dir.listSync()) {
        if (e is! File || !e.path.contains('job_match_') || !e.path.contains(safe)) {
          continue;
        }
        try {
          return JobMatchReport.fromJson(
            jsonDecode(await e.readAsString()) as Map<String, dynamic>,
            jobTitle: '',
          );
        } catch (_) {
          continue;
        }
      }
    }
    final File latest =
        File('${dir.path}${Platform.pathSeparator}job_match_latest.json');
    if (await latest.exists()) {
      try {
        return JobMatchReport.fromJson(
          jsonDecode(await latest.readAsString()) as Map<String, dynamic>,
          jobTitle: '',
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clear() async {
    final Directory? dir = await _folder();
    if (dir == null) {
      return;
    }
    for (final FileSystemEntity e in dir.listSync()) {
      if (e is File && e.path.contains('job_match_')) {
        await e.delete();
      }
    }
  }
}
