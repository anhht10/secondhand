import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../models/product_model.dart';

/// Represents an image file selected by the user for upload (`POST /api/v1/upload/images`).
class UploadableImageFile {
  const UploadableImageFile({
    required this.bytes,
    required this.fileName,
    this.mimeType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

/// Remote data source for Products (`/api/v1/products`) and Image Uploads (`/api/v1/upload/images`).
class ProductRemoteDataSource {
  const ProductRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /api/v1/products`
  Future<NetworkResult<List<ProductModel>>> getProducts(
    ProductFilterQuery query,
  ) {
    return _apiClient.get<List<ProductModel>>(
      ApiEndpoints.products,
      queryParameters: query.toQueryParameters(),
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList(growable: false);
        }
        return const <ProductModel>[];
      },
    );
  }

  /// `GET /api/v1/products/me/listings`
  Future<NetworkResult<List<ProductModel>>> getMyListings({
    int page = 1,
    int limit = 20,
    ProductStatus? status,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status.apiValue,
    };
    return _apiClient.get<List<ProductModel>>(
      ApiEndpoints.myListings,
      queryParameters: query,
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList(growable: false);
        }
        return const <ProductModel>[];
      },
    );
  }

  /// `GET /api/v1/products/:id`
  Future<NetworkResult<ProductModel>> getProductById(String id) {
    return _apiClient.get<ProductModel>(
      ApiEndpoints.productById(id),
      parser: (rawData) =>
          ProductModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/products`
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
    final resolvedLocation =
        (location != null && location.trim().length >= 2)
            ? location.trim()
            : 'Toàn quốc';
    final transparencyNote = aiMetadata?.priceReasoning?.trim().isNotEmpty == true
        ? aiMetadata!.priceReasoning!.trim()
        : aiMetadata?.aiGeneratedDescription?.trim();

    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'price': price.round(),
      if (originalPrice != null && originalPrice > 0)
        'originalPrice': originalPrice.round(),
      'categoryId': categoryId.trim(),
      'condition': condition.apiValue,
      if (defectDisclosure != null && defectDisclosure.trim().isNotEmpty)
        'defectDisclosure': defectDisclosure.trim(),
      if (images.isNotEmpty) 'images': images,
      'location': resolvedLocation,
      'status': status == ProductStatus.draft
          ? ProductStatus.draft.apiValue
          : ProductStatus.active.apiValue,
      if (transparencyNote != null && transparencyNote.isNotEmpty)
        'transparencyNote': transparencyNote,
    };

    return _apiClient.post<ProductModel>(
      ApiEndpoints.products,
      data: payload,
      parser: (rawData) =>
          ProductModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/products/:id`
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
    final payload = <String, dynamic>{
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (price != null) 'price': price.round(),
      if (originalPrice != null) 'originalPrice': originalPrice.round(),
      if (categoryId != null && categoryId.trim().isNotEmpty)
        'categoryId': categoryId.trim(),
      if (condition != null) 'condition': condition.apiValue,
      if (defectDisclosure != null)
        'defectDisclosure': defectDisclosure.trim(),
      'images': ?images,
      if (location != null && location.trim().length >= 2)
        'location': location.trim(),
    };

    return _apiClient.patch<ProductModel>(
      ApiEndpoints.productById(productId),
      data: payload,
      parser: (rawData) =>
          ProductModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/products/:id/status`
  Future<NetworkResult<ProductModel>> updateProductStatus({
    required String productId,
    required ProductStatus status,
  }) {
    return _apiClient.patch<ProductModel>(
      ApiEndpoints.productStatus(productId),
      data: <String, dynamic>{'status': status.apiValue},
      parser: (rawData) =>
          ProductModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `DELETE /api/v1/products/:id`
  Future<NetworkResult<void>> deleteProduct(String productId) {
    return _apiClient.delete<void>(
      ApiEndpoints.productById(productId),
      parser: (_) {},
    );
  }

  /// `POST /api/v1/upload/images` (`multipart/form-data`, field `images`)
  Future<NetworkResult<List<String>>> uploadImages(
    List<UploadableImageFile> files,
  ) {
    final formData = FormData();
    for (final file in files) {
      final parts = file.mimeType.split('/');
      final mediaType = parts.length == 2
          ? DioMediaType(parts[0], parts[1])
          : DioMediaType('image', 'jpeg');
      formData.files.add(
        MapEntry(
          'images',
          MultipartFile.fromBytes(
            file.bytes,
            filename: file.fileName,
            contentType: mediaType,
          ),
        ),
      );
    }

    return _apiClient.post<List<String>>(
      ApiEndpoints.uploadImages,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return (item['url'] ?? '').toString();
                }
                return item.toString();
              })
              .where((url) => url.trim().isNotEmpty)
              .map(_apiClient.config.resolveMediaUrl)
              .toList(growable: false);
        }
        if (rawData is Map<String, dynamic> && rawData['urls'] is List) {
          return (rawData['urls'] as List)
              .map((e) => e.toString())
              .where((url) => url.trim().isNotEmpty)
              .map(_apiClient.config.resolveMediaUrl)
              .toList(growable: false);
        }
        return const <String>[];
      },
    );
  }
}
