import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../../../../shared/models/user_model.dart';
import 'models/auth_response_model.dart';

/// Remote data source for Authentication endpoints (`/api/v1/auth/*`).
///
///Strictly adheres to `docs/api/AUTHENTICATION.md` and `docs/api/API_CONTRACT.md`.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /api/v1/auth/login`
  Future<NetworkResult<AuthResponseModel>> login({
    required String email,
    required String password,
  }) {
    return _apiClient.post<AuthResponseModel>(
      ApiEndpoints.authLogin,
      data: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      parser: (rawData) =>
          AuthResponseModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/auth/register`
  ///
  /// Only sends optional `phone` and `location` when non-empty to respect
  /// NestJS `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`.
  Future<NetworkResult<AuthResponseModel>> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? location,
  }) {
    final payload = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
      'displayName': displayName.trim(),
    };
    if (phone != null && phone.trim().isNotEmpty) {
      payload['phoneNumber'] = phone.trim();
    }
    if (location != null && location.trim().isNotEmpty) {
      payload['location'] = location.trim();
    }

    return _apiClient.post<AuthResponseModel>(
      ApiEndpoints.authRegister,
      data: payload,
      parser: (rawData) =>
          AuthResponseModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/auth/refresh`
  Future<NetworkResult<AuthResponseModel>> refresh({
    required String refreshToken,
  }) {
    return _apiClient.post<AuthResponseModel>(
      ApiEndpoints.authRefresh,
      data: <String, dynamic>{
        'refreshToken': refreshToken.trim(),
      },
      parser: (rawData) =>
          AuthResponseModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/auth/logout`
  Future<NetworkResult<void>> logout() {
    return _apiClient.post<void>(
      ApiEndpoints.authLogout,
      parser: (_) {},
    );
  }

  /// `GET /api/v1/auth/me`
  Future<NetworkResult<UserModel>> getCurrentUser() {
    return _apiClient.get<UserModel>(
      ApiEndpoints.authMe,
      parser: (rawData) => UserModel.fromJson(rawData as Map<String, dynamic>),
    );
  }
}
