import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/core/config/app_config.dart';
import 'package:remarket_fe/core/errors/api_exception.dart';
import 'package:remarket_fe/core/network/dio_client.dart';
import 'package:remarket_fe/core/storage/local_preferences.dart';
import 'package:remarket_fe/core/storage/token_storage.dart';
import 'package:remarket_fe/features/auth/data/auth_remote_data_source.dart';
import 'package:remarket_fe/features/auth/data/auth_repository_impl.dart';
import 'package:remarket_fe/features/auth/domain/auth_state.dart';
import 'package:remarket_fe/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> map, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(map),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'http://localhost:3000/api/v1',
    enableNetworkLogging: false,
  );

  final sampleUserJson = <String, dynamic>{
    '_id': '672b3a9f8e1b2c0012345678',
    'id': '672b3a9f8e1b2c0012345678',
    'email': 'nguyen.an@student.edu.vn',
    'displayName': 'Nguyễn Văn An',
    'phone': '0901234567',
    'location': 'Thủ Đức, TP.HCM',
    'role': 'user',
    'isEmailVerified': true,
    'status': 'ACTIVE',
    'wishlist': <String>[],
    'stats': <String, dynamic>{
      'activeListingsCount': 5,
      'soldListingsCount': 2,
      'rating': 4.9,
      'transparencyRate': 98,
    },
  };

  group('AuthRepository & AuthController', () {
    test('login success saves tokens and updates AuthState to authenticated', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final tokenStorage = InMemoryTokenStorage();
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));

      dio.httpClientAdapter = _TestAdapter((options) async {
        expect(options.path, equals('/auth/login'));
        return _json(<String, dynamic>{
          'success': true,
          'message': 'Success',
          'data': <String, dynamic>{
            'user': sampleUserJson,
            'tokens': <String, dynamic>{
              'accessToken': 'jwt-access-login',
              'refreshToken': 'jwt-refresh-login',
            },
          },
          'meta': <String, dynamic>{},
        });
      });

      final apiClient = ApiClient(
        config: config,
        tokenStorage: tokenStorage,
        dioOverride: dio,
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(apiClient),
        tokenStorage: tokenStorage,
        localPreferences: LocalPreferences(prefs),
      );
      final controller = AuthController(
        repository: repository,
        autoRestore: false,
      );

      final ok = await controller.login(
        email: 'nguyen.an@student.edu.vn',
        password: 'Password123!',
      );

      expect(ok, isTrue);
      expect(controller.state.status, equals(AuthStatus.authenticated));
      expect(controller.state.user?.displayName, equals('Nguyễn Văn An'));
      expect(controller.state.user?.stats?.activeListingsCount, equals(5));
      expect(await tokenStorage.readAccessToken(), equals('jwt-access-login'));
      expect(await tokenStorage.readRefreshToken(), equals('jwt-refresh-login'));
    });

    test('login failure sets AuthState error and keeps status unauthenticated', () async {
      final tokenStorage = InMemoryTokenStorage();
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));

      dio.httpClientAdapter = _TestAdapter((options) async {
        return _json(
          <String, dynamic>{
            'success': false,
            'statusCode': 401,
            'message': 'Invalid email or password',
            'error': <String, dynamic>{
              'code': 'UNAUTHORIZED',
              'details': <String>['Invalid email or password'],
            },
          },
          statusCode: 401,
        );
      });

      final apiClient = ApiClient(
        config: config,
        tokenStorage: tokenStorage,
        dioOverride: dio,
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(apiClient),
        tokenStorage: tokenStorage,
      );
      final controller = AuthController(
        repository: repository,
        autoRestore: false,
      );

      final ok = await controller.login(
        email: 'wrong@student.edu.vn',
        password: 'WrongPassword1',
      );

      expect(ok, isFalse);
      expect(controller.state.status, equals(AuthStatus.unauthenticated));
      expect(controller.state.error?.code, equals(ApiErrorCodes.unauthorized));
      expect(controller.state.error?.message, equals('Invalid email or password'));
    });

    test('restoreSession authenticates user when valid tokens exist and /auth/me succeeds', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'stored-access-token',
        initialRefreshToken: 'stored-refresh-token',
      );
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));

      dio.httpClientAdapter = _TestAdapter((options) async {
        expect(options.path, equals('/auth/me'));
        return _json(<String, dynamic>{
          'success': true,
          'message': 'Success',
          'data': sampleUserJson,
          'meta': <String, dynamic>{},
        });
      });

      final apiClient = ApiClient(
        config: config,
        tokenStorage: tokenStorage,
        dioOverride: dio,
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(apiClient),
        tokenStorage: tokenStorage,
      );
      final controller = AuthController(
        repository: repository,
        autoRestore: false,
      );

      await controller.restoreSession();

      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.user?.email, equals('nguyen.an@student.edu.vn'));
    });

    test('logout revokes token on backend and clears local session', () async {
      final tokenStorage = InMemoryTokenStorage(
        initialAccessToken: 'active-access',
        initialRefreshToken: 'active-refresh',
      );
      bool logoutCalled = false;
      final dio = Dio(BaseOptions(baseUrl: config.apiBaseUrl));

      dio.httpClientAdapter = _TestAdapter((options) async {
        if (options.path == '/auth/logout') {
          logoutCalled = true;
        }
        return _json(<String, dynamic>{
          'success': true,
          'message': 'Logged out successfully',
          'data': <String, dynamic>{'message': 'Logged out successfully'},
          'meta': <String, dynamic>{},
        });
      });

      final apiClient = ApiClient(
        config: config,
        tokenStorage: tokenStorage,
        dioOverride: dio,
      );
      final repository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSource(apiClient),
        tokenStorage: tokenStorage,
      );
      final controller = AuthController(
        repository: repository,
        autoRestore: false,
      );

      await controller.logout();

      expect(logoutCalled, isTrue);
      expect(controller.state.status, equals(AuthStatus.unauthenticated));
      expect(await tokenStorage.hasValidTokenPair(), isFalse);
    });
  });
}
