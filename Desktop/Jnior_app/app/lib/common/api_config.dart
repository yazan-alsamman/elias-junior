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

  /// Set false to skip Llama CV parser during upload (ATS-only mode).
  /// Re-enable later with `--dart-define=CV_PARSER_ENABLED=true`.
  static const bool cvParserEnabled = bool.fromEnvironment(
    'CV_PARSER_ENABLED',
    defaultValue: false,
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

  /// Local Node on :3003 — only used when [useLocalNodeSaveFallback] is true.
  static String get localStorageFallbackUrl {
    if (_fromEnvBase.isNotEmpty && isLocalDev) return baseUrl;
    return _localLoopback(3003);
  }

  /// Retry save on local Node after Hostinger 404. Off by default because the
  /// Hostinger JWT will not validate on local Node (different JWT_SECRET).
  /// Enable with `--dart-define=LOCAL_NODE_SAVE=true` after syncing JWT_SECRET.
  static const bool useLocalNodeSaveFallback = bool.fromEnvironment(
    'LOCAL_NODE_SAVE',
    defaultValue: false,
  );

  /// True when [baseUrl] points at a local Node instance (rare; we default to Hostinger).
  static bool get isLocalDev =>
      baseUrl.contains('10.0.2.2') ||
      baseUrl.contains('127.0.0.1') ||
      baseUrl.contains('localhost');
}
