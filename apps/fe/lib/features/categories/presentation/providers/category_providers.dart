import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/category_remote_data_source.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

final categoryRemoteDataSourceProvider =
    Provider<CategoryRemoteDataSource>((ref) {
  return CategoryRemoteDataSource(ref.watch(apiClientProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    remoteDataSource: ref.watch(categoryRemoteDataSourceProvider),
    localPreferences: ref.watch(localPreferencesProvider),
  );
});

/// Loads active marketplace categories from `GET /api/v1/categories`.
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  final result = await repo.getCategories();
  return result.when(
    success: (categories, _, _) => categories,
    failure: (error) => throw error,
  );
});
