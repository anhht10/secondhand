import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository.dart';

final profileRemoteDataSourceProvider =
    Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSource(ref.watch(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    localPreferences: ref.watch(localPreferencesProvider),
  );
});

/// Fetches a seller's public profile (`GET /api/v1/users/:id`).
final publicSellerProfileProvider =
    FutureProvider.family<UserModel, String>((ref, sellerId) async {
  final repo = ref.watch(profileRepositoryProvider);
  final result = await repo.getPublicSellerProfile(sellerId);
  return result.when(
    success: (seller, _, _) => seller,
    failure: (error) => throw error,
  );
});
