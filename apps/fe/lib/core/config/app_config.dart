import 'package:flutter/foundation.dart';

/// Execution environments supported by ReMarket Flutter.
enum AppEnvironment {
  development,
  production;

  static AppEnvironment fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      default:
        return AppEnvironment.development;
    }
  }
}

/// Centralized application & environment configuration.
///
/// Base URL can be overridden at build/run time using:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1`
/// `flutter run --dart-define=APP_ENV=production`
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableNetworkLogging,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 15),
    this.aiReceiveTimeout = const Duration(seconds: 35),
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableNetworkLogging;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Duration aiReceiveTimeout;

  bool get isDevelopment => environment == AppEnvironment.development;
  bool get isProduction => environment == AppEnvironment.production;

  /// Compile-time environment name (`development` or `production`).
  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// Compile-time override for `API_BASE_URL`.
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Resolves the default API Base URL according to the current target platform
  /// when `--dart-define=API_BASE_URL` is not explicitly provided.
  ///
  /// - Android Emulator (AVD): `http://10.0.2.2:3000/api/v1`
  /// - Web / Windows / macOS / iOS Simulator: `http://localhost:3000/api/v1`
  static String resolveDefaultBaseUrl({TargetPlatform? platformOverride, bool? isWebOverride}) {
    if (_rawApiBaseUrl.trim().isNotEmpty) {
      return _normalizeBaseUrl(_rawApiBaseUrl.trim());
    }
    final isWeb = isWebOverride ?? kIsWeb;
    final platform = platformOverride ?? defaultTargetPlatform;
    if (!isWeb && platform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  static String _normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Creates the default [AppConfig] from compile-time `--dart-define` values
  /// and platform conventions.
  factory AppConfig.fromEnvironment({
    String? baseUrlOverride,
    AppEnvironment? environmentOverride,
    bool? enableLoggingOverride,
  }) {
    final env = environmentOverride ?? AppEnvironment.fromString(_rawEnv);
    final resolvedBaseUrl = baseUrlOverride != null && baseUrlOverride.trim().isNotEmpty
        ? _normalizeBaseUrl(baseUrlOverride)
        : resolveDefaultBaseUrl();

    return AppConfig(
      environment: env,
      apiBaseUrl: resolvedBaseUrl,
      enableNetworkLogging:
          enableLoggingOverride ?? (env == AppEnvironment.development && kDebugMode),
    );
  }

  /// Extracts the HTTP(S) origin (e.g., `http://localhost:3000` or `http://10.0.2.2:3000`)
  /// from [apiBaseUrl].
  String get serverOrigin {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final portPart = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portPart';
    }
    return 'http://localhost:3000';
  }

  /// Resolves relative `/uploads/...` paths against [serverOrigin] and rewrites
  /// `http://localhost:3000/...` image URLs to `http://10.0.2.2:3000/...`
  /// when running on an Android Emulator so local Multer uploads render properly.
  String resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return '';
    }
    var trimmed = rawUrl.trim();
    if (trimmed.startsWith('/')) {
      trimmed = '$serverOrigin$trimmed';
    }
    if (apiBaseUrl.contains('10.0.2.2') && trimmed.contains('localhost:3000')) {
      return trimmed.replaceFirst('localhost:3000', '10.0.2.2:3000');
    }
    return trimmed;
  }
}
