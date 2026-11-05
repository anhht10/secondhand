import '../../../../core/network/network_result.dart';
import '../../../../core/storage/local_preferences.dart';
import '../../../../shared/models/user_model.dart';
import '../datasources/profile_remote_data_source.dart';

/// Repository for user profile operations (`/api/v1/users/*`).
class ProfileRepository {
  const ProfileRepository({
    required this.remoteDataSource,
    this.localPreferences,
  });

  final ProfileRemoteDataSource remoteDataSource;
  final LocalPreferences? localPreferences;

  Future<NetworkResult<UserModel>> getMyProfile() async {
    final result = await remoteDataSource.getMyProfile();
    if (result is NetworkSuccess<UserModel>) {
      await localPreferences?.saveUserSnapshot(result.data);
    }
    return result;
  }

  Future<NetworkResult<UserModel>> updateMyProfile({
    String? displayName,
    String? phone,
    String? avatarUrl,
    String? bio,
    String? location,
    UserBankInfoModel? bankInfo,
  }) async {
    final result = await remoteDataSource.updateMyProfile(
      displayName: displayName,
      phone: phone,
      avatarUrl: avatarUrl,
      bio: bio,
      location: location,
      bankInfo: bankInfo,
    );
    if (result is NetworkSuccess<UserModel>) {
      await localPreferences?.saveUserSnapshot(result.data);
    }
    return result;
  }

  Future<NetworkResult<UserModel>> getPublicSellerProfile(String sellerId) {
    return remoteDataSource.getPublicSellerProfile(sellerId);
  }
}
