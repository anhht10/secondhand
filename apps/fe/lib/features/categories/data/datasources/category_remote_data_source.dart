import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../models/category_model.dart';

/// Remote data source for `/api/v1/categories`.
class CategoryRemoteDataSource {
  const CategoryRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /api/v1/categories`
  Future<NetworkResult<List<CategoryModel>>> getCategories({String? parentId}) {
    final query = <String, dynamic>{
      if (parentId != null && parentId.trim().isNotEmpty)
        'parentId': parentId.trim(),
    };
    return _apiClient.get<List<CategoryModel>>(
      ApiEndpoints.categories,
      queryParameters: query.isEmpty ? null : query,
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(CategoryModel.fromJson)
              .toList(growable: false);
        }
        return const <CategoryModel>[];
      },
    );
  }

  /// `GET /api/v1/categories/:id`
  Future<NetworkResult<CategoryModel>> getCategoryById(String id) {
    return _apiClient.get<CategoryModel>(
      ApiEndpoints.categoryById(id),
      parser: (rawData) =>
          CategoryModel.fromJson(rawData as Map<String, dynamic>),
    );
  }
}
