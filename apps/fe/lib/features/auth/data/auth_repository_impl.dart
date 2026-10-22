import '../../../../core/network/network_result.dart';
import '../../../../core/storage/local_preferences.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/models/user_model.dart';
import '../domain/auth_repository.dart';
import 'auth_remote_data_source.dart';
import 'models/auth_response_model.dart';

/// Concrete implementation of [AuthRepository] coordinating
/// [AuthRemoteDataSource], [TokenStorage], and [LocalPreferences].
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStorage,
    this.localPreferences,
  });

  final AuthRemoteDataSource remoteDataSource;
  final TokenStorage tokenStorage;
  final LocalPreferences? localPreferences;

  @override
  Future<NetworkResult<UserModel>> login({
    required String email,
    required String password,
  }) async {
    final result = await remoteDataSource.login(
      email: email,
      password: password,
    );
    return _persistAuthResult(result);
  }

  @override
  Future<NetworkResult<UserModel>> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? location,
  }) async {
    final result = await remoteDataSource.register(
      email: email,
      password: password,
      displayName: displayName,
      phone: phone,
      location: location,
    );
    return _persistAuthResult(result);
  }

  Future<NetworkResult<UserModel>> _persistAuthResult(
    NetworkResult<AuthResponseModel> result,
  ) async {
    if (result is NetworkSuccess<AuthResponseModel>) {
      final payload = result.data;
      await tokenStorage.saveTokens(
        accessToken: payload.tokens.accessToken,
        refreshToken: payload.tokens.refreshToken,
      );
      await localPreferences?.saveUserSnapshot(payload.user);
      return NetworkSuccess<UserModel>(
        data: payload.user,
        message: result.message,
      );
    }
    return NetworkFailure<UserModel>((result as NetworkFailure).error);
  }

  @override
  Future<NetworkResult<UserModel?>> restoreSession() async {
    final hasTokens = await tokenStorage.hasValidTokenPair();
    if (!hasTokens) {
      await localPreferences?.clearUserSnapshot();
      return const NetworkSuccess<UserModel?>(data: null);
    }

    // If accessToken is missing but refreshToken exists, proactively refresh first.
    final accessToken = await tokenStorage.readAccessToken();
    final refreshToken = await tokenStorage.readRefreshToken();
    if ((accessToken == null || accessToken.trim().isEmpty) &&
        refreshToken != null &&
        refreshToken.trim().isNotEmpty) {
      final refreshResult = await remoteDataSource.refresh(
        refreshToken: refreshToken,
      );
      if (refreshResult is NetworkSuccess<AuthResponseModel>) {
        await tokenStorage.saveTokens(
          accessToken: refreshResult.data.tokens.accessToken,
          refreshToken: refreshResult.data.tokens.refreshToken,
        );
        await localPreferences?.saveUserSnapshot(refreshResult.data.user);
        return NetworkSuccess<UserModel?>(data: refreshResult.data.user);
      } else {
        await _clearLocalSession();
        return const NetworkSuccess<UserModel?>(data: null);
      }
    }

    // Fetch live profile via GET /api/v1/auth/me (AuthInterceptor handles 401 refresh rotation).
    final meResult = await remoteDataSource.getCurrentUser();
    if (meResult is NetworkSuccess<UserModel>) {
      await localPreferences?.saveUserSnapshot(meResult.data);
      return NetworkSuccess<UserModel?>(data: meResult.data);
    }

    final error = (meResult as NetworkFailure<UserModel>).error;
    if (error.isUnauthorized || error.isForbidden) {
      await _clearLocalSession();
      return const NetworkSuccess<UserModel?>(data: null);
    }

    // If offline/network error and we have a cached user snapshot, keep session alive.
    final cachedUser = localPreferences?.readUserSnapshot();
    if (error.isNetworkError && cachedUser != null) {
      return NetworkSuccess<UserModel?>(data: cachedUser);
    }

    await _clearLocalSession();
    return const NetworkSuccess<UserModel?>(data: null);
  }

  @override
  Future<NetworkResult<UserModel>> refreshProfile() async {
    final result = await remoteDataSource.getCurrentUser();
    if (result is NetworkSuccess<UserModel>) {
      await localPreferences?.saveUserSnapshot(result.data);
    }
    return result;
  }

  @override
  Future<void> logout() async {
    try {
      final accessToken = await tokenStorage.readAccessToken();
      if (accessToken != null && accessToken.trim().isNotEmpty) {
        await remoteDataSource.logout();
      }
    } catch (_) {
      // Always proceed to clear local tokens even if server is unreachable
    } finally {
      await _clearLocalSession();
    }
  }

  Future<void> _clearLocalSession() async {
    await tokenStorage.clearTokens();
    await localPreferences?.clearUserSnapshot();
  }
}
