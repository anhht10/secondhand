import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/core/config/app_config.dart';
import 'package:remarket_fe/core/errors/api_exception.dart';
import 'package:remarket_fe/core/network/dio_client.dart';
import 'package:remarket_fe/core/network/network_result.dart';
import 'package:remarket_fe/core/storage/token_storage.dart';

/// Custom [HttpClientAdapter] for deterministic Dio unit testing without live sockets.
class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  group('ApiClient & AuthInterceptor', () {
    const testConfig = AppConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: 'http://localhost:3000/api/v1',
      enableNetworkLogging: false,
    );

    test('unwraps TransformInterceptor success envelope and pagination meta', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'access-123',
        initialRefreshToken: 'refresh-123',
      );

      final dio = Dio(BaseOptions(baseUrl: testConfig.apiBaseUrl));
      String? capturedAuthHeader;

      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        capturedAuthHeader = options.headers['Authorization'] as String?;
        return _jsonResponse(<String, dynamic>{
          'success': true,
          'message': 'Success',
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'p1', 'title': 'Keychron K6'},
          ],
          'meta': <String, dynamic>{
            'total': 15,
            'page': 1,
            'limit': 10,
            'totalPages': 2,
            'hasNextPage': true,
            'hasPrevPage': false,
          },
        });
      });

      final apiClient = ApiClient(
        config: testConfig,
        tokenStorage: tokenStorage,
        dioOverride: dio,
      );

      final result = await apiClient.get<List<String>>(
        '/products',
        parser: (rawData) => (rawData as List<dynamic>)
            .map((item) => (item as Map<String, dynamic>)['title'] as String)
            .toList(),
      );

      expect(capturedAuthHeader, equals('Bearer access-123'));
      expect(result.isSuccess, isTrue);
      final success = result as NetworkSuccess<List<String>>;
      expect(success.data, equals(<String>['Keychron K6']));
      expect(success.meta, isNotNull);
      expect(success.meta!.total, equals(15));
      expect(success.meta!.hasNextPage, isTrue);
    });

    test('parses GlobalExceptionFilter error envelope into ApiException', () async {
      final tokenStorage = InMemoryTokenStorage();
      final dio = Dio(BaseOptions(baseUrl: testConfig.apiBaseUrl));

      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return _jsonResponse(
          <String, dynamic>{
            'success': false,
            'statusCode': 400,
            'message': 'price must not be less than 0',
            'error': <String, dynamic>{
              'code': 'VALIDATION_ERROR',
              'details': <String>[
                'price must not be less than 0',
                'title must be longer than or equal to 5 characters',
              ],
              'requestId': 'req-unit-001',
            },
          },
          statusCode: 400,
        );
      });

      final apiClient = ApiClient(
        config: testConfig,
        tokenStorage: tokenStorage,
        dioOverride: dio,
      );

      final result = await apiClient.post<void>(
        '/products',
        data: <String, dynamic>{'price': -10},
        parser: (_) {},
      );

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull!;
      expect(error.statusCode, equals(400));
      expect(error.code, equals(ApiErrorCodes.validationError));
      expect(error.message, equals('price must not be less than 0'));
      expect(error.details.length, equals(2));
      expect(error.requestId, equals('req-unit-001'));
    });

    test(
      'executes single-flight refresh token rotation on concurrent 401 responses',
      () async {
        final tokenStorage = InMemoryTokenStorage(
          initialAccessToken: 'expired-access-token',
          initialRefreshToken: 'valid-refresh-token',
        );

        int refreshCallCount = 0;
        final dio = Dio(BaseOptions(baseUrl: testConfig.apiBaseUrl));
        final refreshDio = Dio(BaseOptions(baseUrl: testConfig.apiBaseUrl));

        refreshDio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          refreshCallCount++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return _jsonResponse(<String, dynamic>{
            'success': true,
            'message': 'Success',
            'data': <String, dynamic>{
              'user': <String, dynamic>{
                'id': 'u1',
                'email': 'nguyen.an@student.edu.vn',
                'displayName': 'Nguyễn Văn An',
              },
              'tokens': <String, dynamic>{
                'accessToken': 'rotated-access-token',
                'refreshToken': 'rotated-refresh-token',
              },
            },
            'meta': <String, dynamic>{},
          });
        });

        dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          final authHeader = options.headers['Authorization'] as String?;
          if (authHeader == 'Bearer expired-access-token') {
            return _jsonResponse(
              <String, dynamic>{
                'success': false,
                'statusCode': 401,
                'message': 'Unauthorized',
                'error': <String, dynamic>{
                  'code': 'UNAUTHORIZED',
                  'details': <String>['Unauthorized'],
                },
              },
              statusCode: 401,
            );
          }

          return _jsonResponse(<String, dynamic>{
            'success': true,
            'message': 'Success',
            'data': <String, dynamic>{'path': options.path, 'auth': authHeader},
            'meta': <String, dynamic>{},
          });
        });

        final apiClient = ApiClient(
          config: testConfig,
          tokenStorage: tokenStorage,
          dioOverride: dio,
          refreshDioOverride: refreshDio,
        );

        // Fire 3 concurrent requests that all fail initially with 401
        final results = await Future.wait([
          apiClient.get<Map<String, dynamic>>(
            '/auth/me',
            parser: (d) => d as Map<String, dynamic>,
          ),
          apiClient.get<Map<String, dynamic>>(
            '/users/me',
            parser: (d) => d as Map<String, dynamic>,
          ),
          apiClient.get<Map<String, dynamic>>(
            '/auth/wishlist',
            parser: (d) => d as Map<String, dynamic>,
          ),
        ]);

        // Refresh endpoint must have been called ONLY ONCE
        expect(refreshCallCount, equals(1));
        expect(results.every((r) => r.isSuccess), isTrue);
        expect(
          await tokenStorage.readAccessToken(),
          equals('rotated-access-token'),
        );
        expect(
          await tokenStorage.readRefreshToken(),
          equals('rotated-refresh-token'),
        );
      },
    );

    test('clears tokens and triggers onSessionExpired when refresh fails', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'expired-access-token',
        initialRefreshToken: 'revoked-refresh-token',
      );

      bool sessionExpiredCalled = false;
      final dio = Dio(BaseOptions(baseUrl: testConfig.apiBaseUrl));
      final refreshDio = Dio(BaseOptions(baseUrl: testConfig.apiBaseUrl));

      refreshDio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return _jsonResponse(
          <String, dynamic>{
            'success': false,
            'statusCode': 401,
            'message': 'Refresh token is no longer valid',
            'error': <String, dynamic>{
              'code': 'UNAUTHORIZED',
              'details': <String>['Refresh token is no longer valid'],
            },
          },
          statusCode: 401,
        );
      });

      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return _jsonResponse(
          <String, dynamic>{
            'success': false,
            'statusCode': 401,
            'message': 'Unauthorized',
            'error': <String, dynamic>{
              'code': 'UNAUTHORIZED',
              'details': <String>['Unauthorized'],
            },
          },
          statusCode: 401,
        );
      });

      final apiClient = ApiClient(
        config: testConfig,
        tokenStorage: tokenStorage,
        dioOverride: dio,
        refreshDioOverride: refreshDio,
        onSessionExpired: () {
          sessionExpiredCalled = true;
        },
      );

      final result = await apiClient.get<void>(
        '/auth/me',
        parser: (_) {},
      );

      expect(result.isFailure, isTrue);
      expect(sessionExpiredCalled, isTrue);
      expect(await tokenStorage.hasValidTokenPair(), isFalse);
    });
  });
}
