import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../../../../shared/models/user_model.dart';

/// Remote data source for `/api/v1/users`.
class ProfileRemoteDataSource {
  const ProfileRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /api/v1/users/me`
  Future<NetworkResult<UserModel>> getMyProfile() {
    return _apiClient.get<UserModel>(
      ApiEndpoints.usersMe,
      parser: (rawData) => UserModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/users/me`
  ///
  /// Only sends non-null fields matching `UpdateUserDto` (`displayName`, `phone`,
  /// `avatarUrl`, `bio`, `location`).
  Future<NetworkResult<UserModel>> updateMyProfile({
    String? displayName,
    String? phone,
    String? avatarUrl,
    String? bio,
    String? location,
    UserBankInfoModel? bankInfo,
  }) {
    final payload = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      if (phone != null && phone.trim().isNotEmpty)
        'phoneNumber': phone.trim(),
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
        'avatarUrl': avatarUrl.trim(),
      if (bio != null) 'bio': bio.trim(),
      if (location != null) 'location': location.trim(),
      if (bankInfo != null && bankInfo.isConfigured)
        'bankInfo': bankInfo.toJson(),
    };

    return _apiClient.patch<UserModel>(
      ApiEndpoints.usersMe,
      data: payload,
      parser: (rawData) => UserModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/users/:id`
  Future<NetworkResult<UserModel>> getPublicSellerProfile(String sellerId) {
    return _apiClient.get<UserModel>(
      ApiEndpoints.userPublicProfile(sellerId),
      parser: (rawData) => UserModel.fromJson(rawData as Map<String, dynamic>),
    );
  }
}
