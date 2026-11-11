import '../../../../core/network/network_result.dart';
import '../../../../core/storage/local_preferences.dart';
import '../datasources/product_remote_data_source.dart';
import '../models/product_model.dart';

/// Result of a product feed query including whether it was served from the
/// local offline cache (`F10 - Offline Cached Mode`).
class ProductFeedResponse {
  const ProductFeedResponse({
    required this.items,
    this.meta,
    this.isFromOfflineCache = false,
    this.cachedAt,
  });

  final List<ProductModel> items;
  final PaginationMeta? meta;
  final bool isFromOfflineCache;
  final DateTime? cachedAt;
}

/// Repository for Products (`GET/POST/PATCH/DELETE /api/v1/products`) and
/// offline feed caching (`SharedPreferences`).
class ProductRepository {
  const ProductRepository({
    required this.remoteDataSource,
    this.localPreferences,
  });

  final ProductRemoteDataSource remoteDataSource;
  final LocalPreferences? localPreferences;

  Future<NetworkResult<ProductFeedResponse>> getProducts(
    ProductFilterQuery query,
  ) async {
    final result = await remoteDataSource.getProducts(query);
    if (result is NetworkSuccess<List<ProductModel>>) {
      // Cache the first page of the default discovery feed for offline mode
      if (query.page == 1 && !query.hasActiveFilters) {
        await localPreferences?.saveCachedProductsJson(
          result.data.map((p) => p.toJson()).toList(growable: false),
        );
      }
      return NetworkSuccess<ProductFeedResponse>(
        data: ProductFeedResponse(
          items: result.data,
          meta: result.meta,
          isFromOfflineCache: false,
        ),
        message: result.message,
        meta: result.meta,
      );
    }

    final error = (result as NetworkFailure<List<ProductModel>>).error;
    final cachedJson = localPreferences?.readCachedProductsJson() ?? const [];
    final isOfflineError = error.isNetworkError ||
        error.code == 'NETWORK_ERROR' ||
        error.code == 'TIMEOUT_ERROR';
    if (isOfflineError && query.page == 1 && cachedJson.isNotEmpty) {
      final cachedItems =
          cachedJson.map(ProductModel.fromJson).toList(growable: false);
      return NetworkSuccess<ProductFeedResponse>(
        data: ProductFeedResponse(
          items: cachedItems,
          isFromOfflineCache: true,
          cachedAt: localPreferences?.readCachedProductsTimestamp(),
        ),
        message: 'Loaded from offline cache',
      );
    }

    return NetworkFailure<ProductFeedResponse>(error);
  }

  Future<NetworkResult<List<ProductModel>>> getMyListings({
    int page = 1,
    int limit = 20,
    ProductStatus? status,
  }) {
    return remoteDataSource.getMyListings(
      page: page,
      limit: limit,
      status: status,
    );
  }

  Future<NetworkResult<ProductModel>> getProductById(String id) {
    return remoteDataSource.getProductById(id);
  }

  Future<NetworkResult<ProductModel>> createProduct({
    required String title,
    required String description,
    required double price,
    double? originalPrice,
    required String categoryId,
    required ProductCondition condition,
    String? defectDisclosure,
    List<String> images = const <String>[],
    String? location,
    ProductStatus status = ProductStatus.active,
    ProductAiMetadata? aiMetadata,
  }) {
    return remoteDataSource.createProduct(
      title: title,
      description: description,
      price: price,
      originalPrice: originalPrice,
      categoryId: categoryId,
      condition: condition,
      defectDisclosure: defectDisclosure,
      images: images,
      location: location,
      status: status,
      aiMetadata: aiMetadata,
    );
  }

  Future<NetworkResult<ProductModel>> updateProduct({
    required String productId,
    String? title,
    String? description,
    double? price,
    double? originalPrice,
    String? categoryId,
    ProductCondition? condition,
    String? defectDisclosure,
    List<String>? images,
    String? location,
  }) {
    return remoteDataSource.updateProduct(
      productId: productId,
      title: title,
      description: description,
      price: price,
      originalPrice: originalPrice,
      categoryId: categoryId,
      condition: condition,
      defectDisclosure: defectDisclosure,
      images: images,
      location: location,
    );
  }

  Future<NetworkResult<ProductModel>> updateProductStatus({
    required String productId,
    required ProductStatus status,
  }) {
    return remoteDataSource.updateProductStatus(
      productId: productId,
      status: status,
    );
  }

  Future<NetworkResult<void>> deleteProduct(String productId) {
    return remoteDataSource.deleteProduct(productId);
  }

  Future<NetworkResult<List<String>>> uploadImages(
    List<UploadableImageFile> files,
  ) {
    return remoteDataSource.uploadImages(files);
  }
}
