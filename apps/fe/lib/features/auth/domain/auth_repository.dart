import '../../../../core/network/network_result.dart';
import '../../../../shared/models/user_model.dart';

/// Domain repository contract for Authentication & Session Management.
abstract class AuthRepository {
  Future<NetworkResult<UserModel>> login({
    required String email,
    required String password,
  });

  Future<NetworkResult<UserModel>> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? location,
  });

  /// Restores an existing session on app startup if valid tokens are stored.
  /// Returns `NetworkSuccess(data: null)` if no session exists or tokens expired.
  Future<NetworkResult<UserModel?>> restoreSession();

  /// Refreshes the current authenticated user's profile (`GET /api/v1/auth/me`).
  Future<NetworkResult<UserModel>> refreshProfile();

  /// Revokes refresh token on the server and clears local tokens & user snapshot.
  Future<void> logout();
}
