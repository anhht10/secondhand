import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Development-only HTTP logging interceptor that strictly redacts
/// tokens, passwords, and sensitive headers.
class SafeLoggingInterceptor extends Interceptor {
  const SafeLoggingInterceptor({required this.enabled});

  final bool enabled;

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'accessToken',
    'refreshToken',
    'access_token',
    'refresh_token',
    'token',
    'authorization',
    'imageBase64',
    'image_base64',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      debugPrint(
        '--> [HTTP] ${options.method.toUpperCase()} ${options.baseUrl}${options.path}'
        '${options.queryParameters.isNotEmpty ? ' ?${options.queryParameters}' : ''}',
      );
      if (options.data is Map<String, dynamic>) {
        debugPrint(
          '    Body: ${_redactMap(options.data as Map<String, dynamic>)}',
        );
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      debugPrint(
        '<-- [HTTP ${response.statusCode}] ${response.requestOptions.method.toUpperCase()} '
        '${response.requestOptions.path}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      debugPrint(
        '<-- [HTTP ERROR ${err.response?.statusCode ?? err.type.name}] '
        '${err.requestOptions.method.toUpperCase()} ${err.requestOptions.path}: '
        '${err.message}',
      );
    }
    handler.next(err);
  }

  static Map<String, dynamic> _redactMap(Map<String, dynamic> source) {
    final sanitized = <String, dynamic>{};
    for (final entry in source.entries) {
      if (_sensitiveKeys.contains(entry.key) ||
          _sensitiveKeys.contains(entry.key.toLowerCase())) {
        sanitized[entry.key] = '***REDACTED***';
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = _redactMap(entry.value as Map<String, dynamic>);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }
}
