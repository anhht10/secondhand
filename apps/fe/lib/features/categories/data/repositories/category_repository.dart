import '../../../../core/network/network_result.dart';
import '../../../../core/storage/local_preferences.dart';
import '../datasources/category_remote_data_source.dart';
import '../models/category_model.dart';

/// Repository for marketplace categories with offline cache support.
class CategoryRepository {
  const CategoryRepository({
    required this.remoteDataSource,
    this.localPreferences,
  });

  final CategoryRemoteDataSource remoteDataSource;
  final LocalPreferences? localPreferences;

  Future<NetworkResult<List<CategoryModel>>> getCategories({
    String? parentId,
  }) async {
    final result = await remoteDataSource.getCategories(parentId: parentId);
    if (result is NetworkSuccess<List<CategoryModel>>) {
      if (parentId == null) {
        await localPreferences?.saveCachedCategoriesJson(
          result.data.map((c) => c.toJson()).toList(growable: false),
        );
      }
      return result;
    }

    final error = (result as NetworkFailure<List<CategoryModel>>).error;
    final cachedJson = localPreferences?.readCachedCategoriesJson() ?? const [];
    if (error.isNetworkError && cachedJson.isNotEmpty) {
      return NetworkSuccess<List<CategoryModel>>(
        data: cachedJson.map(CategoryModel.fromJson).toList(growable: false),
        message: 'Loaded from offline cache',
      );
    }
    return result;
  }

  Future<NetworkResult<CategoryModel>> getCategoryById(String id) {
    return remoteDataSource.getCategoryById(id);
  }
}
