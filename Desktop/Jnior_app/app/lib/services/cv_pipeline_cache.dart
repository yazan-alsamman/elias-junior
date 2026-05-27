import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persisted pipeline progress per CV document (by id or file name).
class CvPipelineSnapshot {
  CvPipelineSnapshot({
    required this.documentKey,
    this.fileName = '',
    this.activeStepIndex = 0,
    this.progressPercent = 0,
    this.targetJobDone = false,
    this.ragDone = false,
    this.resultsDone = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String documentKey;
  final String fileName;
  final int activeStepIndex;
  final int progressPercent;
  final bool targetJobDone;
  final bool ragDone;
  final bool resultsDone;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'documentKey': documentKey,
        'fileName': fileName,
        'activeStepIndex': activeStepIndex,
        'progressPercent': progressPercent,
        'targetJobDone': targetJobDone,
        'ragDone': ragDone,
        'resultsDone': resultsDone,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CvPipelineSnapshot.fromJson(Map<String, dynamic> json) {
    return CvPipelineSnapshot(
      documentKey: '${json['documentKey'] ?? ''}',
      fileName: '${json['fileName'] ?? ''}',
      activeStepIndex: (json['activeStepIndex'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      targetJobDone: json['targetJobDone'] == true,
      ragDone: json['ragDone'] == true,
      resultsDone: json['resultsDone'] == true,
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  CvPipelineSnapshot copyWith({
    int? activeStepIndex,
    int? progressPercent,
    bool? targetJobDone,
    bool? ragDone,
    bool? resultsDone,
    String? fileName,
  }) {
    return CvPipelineSnapshot(
      documentKey: documentKey,
      fileName: fileName ?? this.fileName,
      activeStepIndex: activeStepIndex ?? this.activeStepIndex,
      progressPercent: progressPercent ?? this.progressPercent,
      targetJobDone: targetJobDone ?? this.targetJobDone,
      ragDone: ragDone ?? this.ragDone,
      resultsDone: resultsDone ?? this.resultsDone,
      updatedAt: DateTime.now(),
    );
  }
}

class CvPipelineCache {
  CvPipelineCache._();

  static Future<Directory?> _folder() async {
    if (kIsWeb) return null;
    try {
      final Directory base = await getApplicationDocumentsDirectory();
      final Directory dir =
          Directory('${base.path}${Platform.pathSeparator}cv_parsed');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      debugPrint('[CvPipelineCache] $e');
      return null;
    }
  }

  static String _key({String? documentId, String? fileName}) {
    if (documentId != null && documentId.isNotEmpty) return 'id_$documentId';
    if (fileName != null && fileName.trim().isNotEmpty) {
      return 'file_${fileName.trim()}';
    }
    return 'unknown';
  }

  static Future<void> save(CvPipelineSnapshot snapshot) async {
    final Directory? dir = await _folder();
    if (dir == null) return;
    final File file = File(
      '${dir.path}${Platform.pathSeparator}pipeline_${snapshot.documentKey}.json',
    );
    await file.writeAsString(jsonEncode(snapshot.toJson()));
  }

  static Future<CvPipelineSnapshot?> load({
    String? documentId,
    String? fileName,
  }) async {
    final Directory? dir = await _folder();
    if (dir == null) return null;
    final String key = _key(documentId: documentId, fileName: fileName);
    final File file =
        File('${dir.path}${Platform.pathSeparator}pipeline_$key.json');
    if (!await file.exists()) return null;
    try {
      return CvPipelineSnapshot.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> reset({
    String? documentId,
    String? fileName,
  }) async {
    await save(
      CvPipelineSnapshot(
        documentKey: _key(documentId: documentId, fileName: fileName),
        fileName: fileName ?? '',
        activeStepIndex: 0,
        progressPercent: 5,
      ),
    );
  }
}
