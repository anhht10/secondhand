import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../../../products/data/models/product_model.dart';

/// Repository for Wishlist operations (`/api/v1/auth/wishlist`).
class WishlistRepository {
  const WishlistRepository(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /api/v1/auth/wishlist`
  Future<NetworkResult<List<ProductModel>>> getWishlist() {
    return _apiClient.get<List<ProductModel>>(
      ApiEndpoints.wishlist,
      parser: _parseProductsList,
    );
  }

  /// `POST /api/v1/auth/wishlist/:productId`
  Future<NetworkResult<List<ProductModel>>> addToWishlist(String productId) {
    return _apiClient.post<List<ProductModel>>(
      ApiEndpoints.wishlistItem(productId),
      parser: _parseProductsList,
    );
  }

  /// `DELETE /api/v1/auth/wishlist/:productId`
  Future<NetworkResult<List<ProductModel>>> removeFromWishlist(
    String productId,
  ) {
    return _apiClient.delete<List<ProductModel>>(
      ApiEndpoints.wishlistItem(productId),
      parser: _parseProductsList,
    );
  }

  static List<ProductModel> _parseProductsList(dynamic rawData) {
    if (rawData is List) {
      return rawData
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(growable: false);
    }
    return const <ProductModel>[];
  }
}
