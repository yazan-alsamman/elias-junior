import 'package:flutter/foundation.dart';

/// Three URLs used by the app:
///
/// 1. `baseUrl`        — Hostinger Express backend (auth, Mongo storage, portfolio).
/// 2. `atsBaseUrl`     — local Uvicorn ATS rule engine (port 8000) on your PC.
/// 3. `cvParserBaseUrl` — local Uvicorn CV parser (Llama 3.2 + LoRA, port 8001) on your PC.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE=...        \
///               --dart-define=ATS_URL=...         \
///               --dart-define=CV_PARSER_URL=...
class ApiConfig {
  ApiConfig._();

  /// Production Express API on Hostinger.
  static const String _productionBase =
      'https://rosybrown-jackal-732122.hostingersite.com';

  static const String _fromEnvBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: '',
  );
  static const String _fromEnvAts = String.fromEnvironment(
    'ATS_URL',
    defaultValue: '',
  );
  static const String _fromEnvParser = String.fromEnvironment(
    'CV_PARSER_URL',
    defaultValue: '',
  );

  /// Hostinger Express backend. Always remote (default) unless overridden.
  static String get baseUrl {
    if (_fromEnvBase.isNotEmpty) return _fromEnvBase;
    return _productionBase;
  }

  /// Local ATS engine (port 8000). Use `10.0.2.2` on Android emulator.
  static String get atsBaseUrl {
    if (_fromEnvAts.isNotEmpty) return _fromEnvAts;
    return _localLoopback(8000);
  }

  /// Local CV parser (port 8001). Use `10.0.2.2` on Android emulator.
  static String get cvParserBaseUrl {
    if (_fromEnvParser.isNotEmpty) return _fromEnvParser;
    return _localLoopback(8001);
  }

  /// 127.0.0.1 everywhere except Android emulator (which sees host as 10.0.2.2).
  static String _localLoopback(int port) {
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:$port';
      default:
        return 'http://127.0.0.1:$port';
    }
  }

  /// Local Node API used when Hostinger has not deployed save-analysis yet.
  /// Same MongoDB Atlas as production when backend/.env is configured.
  static String get localStorageFallbackUrl {
    if (_fromEnvBase.isNotEmpty && isLocalDev) return baseUrl;
    return _localLoopback(3003);
  }

  /// True when [baseUrl] points at a local Node instance (rare; we default to Hostinger).
  static bool get isLocalDev =>
      baseUrl.contains('10.0.2.2') ||
      baseUrl.contains('127.0.0.1') ||
      baseUrl.contains('localhost');
}
