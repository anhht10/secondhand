import 'dart:async';

import 'package:dio/dio.dart';

import '../../storage/token_storage.dart';
import '../api_endpoints.dart';

typedef TokenRefreshExecutor = Future<bool> Function(String refreshToken);
typedef SessionExpiredCallback = FutureOr<void> Function();

/// Interceptor that:
/// 1. Injects `Authorization: Bearer <accessToken>` on outgoing requests.
/// 2. Handles `401 Unauthorized` by executing a single-flight Refresh Token Rotation
///    call (`POST /api/v1/auth/refresh`), queueing concurrent 401 requests so only
///    ONE refresh call hits the server.
/// 3. Clears stored tokens and notifies [onSessionExpired] when refresh fails.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.retryDio,
    required this.onRefreshToken,
    this.onSessionExpired,
  });

  final TokenStorage tokenStorage;
  final Dio retryDio;
  final TokenRefreshExecutor onRefreshToken;
  final SessionExpiredCallback? onSessionExpired;

  Completer<bool>? _refreshCompleter;

  static const String _retriedFlagKey = 'x_remarket_retried_after_refresh';

  static bool _isPublicAuthEndpoint(String path) {
    return path.endsWith(ApiEndpoints.authLogin) ||
        path.endsWith(ApiEndpoints.authRegister) ||
        path.endsWith(ApiEndpoints.authRefresh);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicAuthEndpoint(options.path) &&
        !options.headers.containsKey('Authorization')) {
      try {
        final accessToken = await tokenStorage.readAccessToken();
        if (accessToken != null && accessToken.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${accessToken.trim()}';
        }
      } catch (_) {
        // Proceed without Authorization header if token storage read fails
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final requestOptions = err.requestOptions;

    // Do not attempt refresh on 403 Forbidden, non-401 errors, login/register/refresh
    // endpoints, or a request that has already been retried once.
    if (statusCode != 401 ||
        _isPublicAuthEndpoint(requestOptions.path) ||
        requestOptions.extra[_retriedFlagKey] == true) {
      handler.next(err);
      return;
    }

    final refreshed = await _performSingleFlightRefresh();
    if (!refreshed) {
      await tokenStorage.clearTokens();
      await onSessionExpired?.call();
      handler.next(err);
      return;
    }

    final newAccessToken = await tokenStorage.readAccessToken();
    if (newAccessToken == null || newAccessToken.trim().isEmpty) {
      await tokenStorage.clearTokens();
      await onSessionExpired?.call();
      handler.next(err);
      return;
    }

    try {
      final updatedHeaders = Map<String, dynamic>.from(requestOptions.headers);
      updatedHeaders['Authorization'] = 'Bearer ${newAccessToken.trim()}';

      final updatedExtra = Map<String, dynamic>.from(requestOptions.extra);
      updatedExtra[_retriedFlagKey] = true;

      final retryOptions = requestOptions.copyWith(
        headers: updatedHeaders,
        extra: updatedExtra,
      );

      final response = await retryDio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Ensures concurrent 401 responses share a single token refresh call.
  Future<bool> _performSingleFlightRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        completer.complete(false);
        return false;
      }

      final success = await onRefreshToken(refreshToken.trim());
      completer.complete(success);
      return success;
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}
