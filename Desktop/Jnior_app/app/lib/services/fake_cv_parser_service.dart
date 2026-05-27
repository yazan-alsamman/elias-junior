import 'dart:typed_data';

import 'package:app/model/parsed_cv_profile.dart';
import 'package:app/services/cv_text_heuristic.dart';
import 'package:app/services/local_cv_json_store.dart';

/// Simulates the Llama CV parser: heuristic text → JSON file in `cv_parsed/`.
class FakeCvParserResult {
  FakeCvParserResult({
    required this.profile,
    required this.parsedCvMap,
    required this.parseEngine,
    required this.fromLocalJson,
  });

  final ParsedCvProfile profile;
  final Map<String, dynamic> parsedCvMap;
  final String parseEngine;
  final bool fromLocalJson;
}

class FakeCvParserService {
  FakeCvParserService._();
  static final FakeCvParserService instance = FakeCvParserService._();

  String get engine => LocalCvJsonStore.fakeParserEngine;

  /// Parse upload text, else reuse latest JSON on disk, else bundled sample.
  Future<FakeCvParserResult?> parseAndStore({
    required String fileName,
    String resumeText = '',
    Uint8List? fileBytes,
    String? documentId,
  }) {
    return _parse(
      fileName: fileName,
      resumeText: resumeText,
      persist: true,
      documentId: documentId,
    );
  }

  /// Portfolio preview when Mongo has nothing.
  Future<FakeCvParserResult?> loadForPortfolio() {
    return _parse(
      fileName: 'portfolio',
      resumeText: '',
      persist: false,
      documentId: null,
    );
  }

  Future<FakeCvParserResult?> _parse({
    required String fileName,
    required String resumeText,
    required bool persist,
    String? documentId,
  }) async {
    ParsedCvProfile? profile;
    bool fromLocalJson = false;

    final String text = resumeText.trim();
    if (text.length > 80) {
      profile = CvTextHeuristic.parseResumeText(text);
    }

    if (profile == null || !profile.hasPortfolioData) {
      profile = await LocalCvJsonStore.loadLatest();
      fromLocalJson = profile != null;
    }

    if (profile == null || !profile.hasPortfolioData) {
      await LocalCvJsonStore.ensureSeeded();
      profile = await LocalCvJsonStore.loadLatest();
      fromLocalJson = true;
    }

    if (profile == null || !profile.hasPortfolioData) {
      return null;
    }

    if (persist) {
      await LocalCvJsonStore.saveParsed(
        sourceFileName: fileName,
        profile: profile,
        documentId: documentId,
      );
    }

    final Map<String, dynamic> parsedCvMap = profile.toPortfolioJson();
    return FakeCvParserResult(
      profile: profile,
      parsedCvMap: parsedCvMap,
      parseEngine: engine,
      fromLocalJson: fromLocalJson,
    );
  }
}
