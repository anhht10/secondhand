import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'network_result.dart';

/// Centralized HTTP Client for the ReMarket application.
///
/// Features do NOT instantiate their own [Dio] objects; they consume this
/// single configured [ApiClient] provided via Riverpod.
class ApiClient {
  ApiClient({
    required AppConfig config,
    required this.tokenStorage,
    Dio? dioOverride,
    Dio? refreshDioOverride,
    this.onSessionExpired,
  }) : _config = config {
    final baseOptions = BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: kIsWeb ? null : config.sendTimeout,
      headers: <String, dynamic>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio = dioOverride ?? Dio(baseOptions);
    _refreshDio = refreshDioOverride ?? Dio(baseOptions);

    _dio.interceptors.addAll([
      AuthInterceptor(
        tokenStorage: tokenStorage,
        retryDio: _dio,
        onRefreshToken: _executeTokenRefresh,
        onSessionExpired: () => onSessionExpired?.call(),
      ),
      SafeLoggingInterceptor(enabled: config.enableNetworkLogging),
    ]);
  }

  final AppConfig _config;
  final TokenStorage tokenStorage;
  SessionExpiredCallback? onSessionExpired;
  late final Dio _dio;
  late final Dio _refreshDio;

  Dio get rawDio => _dio;
  AppConfig get config => _config;

  /// Calls `POST /api/v1/auth/refresh` using the isolated [_refreshDio] instance
  /// and rotates both `accessToken` and `refreshToken` in [TokenStorage].
  Future<bool> _executeTokenRefresh(String refreshToken) async {
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.authRefresh,
        data: <String, dynamic>{'refreshToken': refreshToken},
      );

      final body = response.data;
      if (body == null || body['success'] != true) {
        return false;
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        return false;
      }

      final tokens = data['tokens'];
      if (tokens is! Map<String, dynamic>) {
        return false;
      }

      final newAccess = tokens['accessToken'] as String?;
      final newRefresh = tokens['refreshToken'] as String?;
      if (newAccess == null ||
          newAccess.trim().isEmpty ||
          newRefresh == null ||
          newRefresh.trim().isEmpty) {
        return false;
      }

      await tokenStorage.saveTokens(
        accessToken: newAccess.trim(),
        refreshToken: newRefresh.trim(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Executes a `GET` request and unwraps the NestJS `TransformInterceptor` envelope.
  Future<NetworkResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic rawData) parser,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  /// Executes a `POST` request and unwraps the NestJS `TransformInterceptor` envelope.
  Future<NetworkResult<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic rawData) parser,
    Options? options,
  }) {
    final resolvedOptions = _applyAiTimeoutIfNeeded(path, options);
    return _request<T>(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: resolvedOptions,
      ),
      parser: parser,
    );
  }

  /// Executes a `PATCH` request and unwraps the NestJS `TransformInterceptor` envelope.
  Future<NetworkResult<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic rawData) parser,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  /// Executes a `PUT` request and unwraps the NestJS `TransformInterceptor` envelope.
  Future<NetworkResult<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic rawData) parser,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  /// Executes a `DELETE` request and unwraps the NestJS `TransformInterceptor` envelope.
  Future<NetworkResult<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic rawData) parser,
    Options? options,
  }) {
    return _request<T>(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser: parser,
    );
  }

  Options? _applyAiTimeoutIfNeeded(String path, Options? existing) {
    if (!path.startsWith('/ai/')) {
      return existing;
    }
    return (existing ?? Options()).copyWith(
      receiveTimeout: _config.aiReceiveTimeout,
    );
  }

  Future<NetworkResult<T>> _request<T>(
    Future<Response<dynamic>> Function() call, {
    required T Function(dynamic rawData) parser,
  }) async {
    try {
      final response = await call();
      final body = response.data;

      if (body is Map<String, dynamic>) {
        if (body['success'] == false) {
          return NetworkFailure<T>(
            ApiException.fromErrorEnvelope(
              body,
              fallbackStatusCode: response.statusCode,
            ),
          );
        }

        final rawData = body.containsKey('data') ? body['data'] : body;
        final message = (body['message'] as String?) ?? 'Success';
        PaginationMeta? paginationMeta;
        final rawMeta = body['meta'];
        if (rawMeta is Map<String, dynamic> && rawMeta.containsKey('total')) {
          paginationMeta = PaginationMeta.fromJson(rawMeta);
        }

        return NetworkSuccess<T>(
          data: parser(rawData),
          message: message,
          meta: paginationMeta,
        );
      }

      return NetworkSuccess<T>(data: parser(body));
    } on DioException catch (dioError) {
      return NetworkFailure<T>(ApiException.fromDioException(dioError));
    } on ApiException catch (apiError) {
      return NetworkFailure<T>(apiError);
    } catch (error) {
      return NetworkFailure<T>(
        ApiException(
          message: 'Lỗi xử lý dữ liệu phản hồi từ máy chủ.',
          code: ApiErrorCodes.internalServerError,
          details: [error.toString()],
        ),
      );
    }
  }
}
