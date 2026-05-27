import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the last uploaded PDF/DOCX on device so ATS can be re-run after reload.
class LocalCvFileCache {
  LocalCvFileCache._();

  static const int _maxBytes = 8 * 1024 * 1024;

  static Future<Directory?> _folder() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final Directory base = await getApplicationDocumentsDirectory();
      final Directory dir =
          Directory('${base.path}${Platform.pathSeparator}cv_files');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      debugPrint('[LocalCvFileCache] $e');
      return null;
    }
  }

  static String _safeName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  }

  static Future<void> save({
    required Uint8List bytes,
    required String fileName,
    String? documentId,
  }) async {
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      return;
    }
    final Directory? dir = await _folder();
    if (dir == null) {
      return;
    }
    final String safe = _safeName(fileName);
    final File byName =
        File('${dir.path}${Platform.pathSeparator}name_$safe');
    await byName.writeAsBytes(bytes, flush: true);
    if (documentId != null && documentId.isNotEmpty) {
      final File byId = File(
        '${dir.path}${Platform.pathSeparator}id_${documentId}_$safe',
      );
      await byId.writeAsBytes(bytes, flush: true);
    }
  }

  static Future<Uint8List?> load({
    String? documentId,
    String? fileName,
  }) async {
    final Directory? dir = await _folder();
    if (dir == null) {
      return null;
    }
    if (documentId != null && documentId.isNotEmpty && fileName != null) {
      final String safe = _safeName(fileName);
      final File byId = File(
        '${dir.path}${Platform.pathSeparator}id_${documentId}_$safe',
      );
      if (await byId.exists()) {
        return byId.readAsBytes();
      }
    }
    if (fileName != null && fileName.trim().isNotEmpty) {
      final File byName = File(
        '${dir.path}${Platform.pathSeparator}name_${_safeName(fileName)}',
      );
      if (await byName.exists()) {
        return byName.readAsBytes();
      }
    }
    return null;
  }

  static Future<void> clear() async {
    final Directory? dir = await _folder();
    if (dir == null || !await dir.exists()) {
      return;
    }
    await for (final FileSystemEntity e in dir.list()) {
      if (e is File) {
        await e.delete();
      }
    }
  }
}
