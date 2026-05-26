import 'dart:convert';

import 'package:app/model/parsed_cv_profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists last good portfolio parse on device (survives refresh; works when Mongo has no JSON).
class PortfolioProfileCache {
  PortfolioProfileCache._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'careerpath_portfolio_parsed_v1';

  static Future<void> save(ParsedCvProfile profile) async {
    if (!profile.hasPortfolioData) {
      return;
    }
    await _storage.write(
      key: _key,
      value: jsonEncode(profile.toPortfolioJson()),
    );
  }

  static Future<ParsedCvProfile?> load() async {
    final String? raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      final ParsedCvProfile p = ParsedCvProfile.fromJson(json);
      return p.hasPortfolioData ? p : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
