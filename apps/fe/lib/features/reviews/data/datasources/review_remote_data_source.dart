import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../models/review_models.dart';

class ReviewRemoteDataSource {
  const ReviewRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /api/v1/reviews`
  Future<NetworkResult<ReviewModel>> createReview({
    required String orderId,
    required int rating,
    required String comment,
    List<String> images = const <String>[],
  }) {
    final payload = <String, dynamic>{
      'orderId': orderId.trim(),
      'rating': rating,
      'comment': comment.trim(),
      if (images.isNotEmpty) 'images': images,
    };

    return _apiClient.post<ReviewModel>(
      ApiEndpoints.reviews,
      data: payload,
      parser: (rawData) =>
          ReviewModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/reviews/:id`
  Future<NetworkResult<ReviewModel>> getReviewById(String reviewId) {
    return _apiClient.get<ReviewModel>(
      ApiEndpoints.reviewById(reviewId),
      parser: (rawData) =>
          ReviewModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/orders/:orderId/review`
  Future<NetworkResult<ReviewModel?>> getReviewByOrderId(String orderId) {
    return _apiClient.get<ReviewModel?>(
      ApiEndpoints.orderReview(orderId),
      parser: (rawData) {
        if (rawData is Map<String, dynamic> &&
            (rawData['id'] != null || rawData['_id'] != null)) {
          return ReviewModel.fromJson(rawData);
        }
        return null;
      },
    );
  }

  /// `PATCH /api/v1/reviews/:id`
  Future<NetworkResult<ReviewModel>> updateReview({
    required String reviewId,
    int? rating,
    String? comment,
    List<String>? images,
  }) {
    final payload = <String, dynamic>{
      'rating': ?rating,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
      'images': ?images,
    };

    return _apiClient.patch<ReviewModel>(
      ApiEndpoints.reviewById(reviewId),
      data: payload,
      parser: (rawData) =>
          ReviewModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/reviews/:id/reply`
  Future<NetworkResult<ReviewModel>> replyToReview({
    required String reviewId,
    required String reply,
  }) {
    return _apiClient.post<ReviewModel>(
      ApiEndpoints.reviewReply(reviewId),
      data: <String, dynamic>{'reply': reply.trim()},
      parser: (rawData) =>
          ReviewModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/reviews/:id/report`
  Future<NetworkResult<Map<String, dynamic>>> reportReview({
    required String reviewId,
    required String reason,
    String? description,
  }) {
    return _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reviewReport(reviewId),
      data: <String, dynamic>{
        'reason': reason.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
      parser: (rawData) =>
          rawData is Map<String, dynamic> ? rawData : <String, dynamic>{},
    );
  }

  /// `GET /api/v1/sellers/:sellerId/reviews`
  Future<NetworkResult<PaginatedSellerReviewsModel>> getSellerReviews({
    required String sellerId,
    int page = 1,
    int limit = 10,
    int? rating,
    ReviewSortOption sort = ReviewSortOption.newest,
  }) {
    return _apiClient.get<PaginatedSellerReviewsModel>(
      ApiEndpoints.sellerReviews(sellerId),
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        'rating': ?rating,
        'sort': sort.apiValue,
      },
      parser: (rawData) {
        if (rawData is Map<String, dynamic>) {
          return PaginatedSellerReviewsModel.fromJson(rawData);
        }
        if (rawData is List) {
          return PaginatedSellerReviewsModel(
            items: rawData
                .whereType<Map<String, dynamic>>()
                .map(ReviewModel.fromJson)
                .toList(growable: false),
          );
        }
        return const PaginatedSellerReviewsModel();
      },
    );
  }

  /// `GET /api/v1/sellers/:sellerId/reputation`
  Future<NetworkResult<SellerReputationModel>> getSellerReputation(
    String sellerId,
  ) {
    return _apiClient.get<SellerReputationModel>(
      ApiEndpoints.sellerReputation(sellerId),
      parser: (rawData) =>
          SellerReputationModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/reviews/upload-images` (`multipart/form-data`, field `images`, max 5)
  Future<NetworkResult<List<String>>> uploadReviewImages(
    List<UploadableImageFile> files,
  ) {
    final formData = FormData();
    for (final file in files.take(5)) {
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
      ApiEndpoints.reviewsUploadImages,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      parser: (rawData) {
        if (rawData is Map<String, dynamic> && rawData['urls'] is List) {
          return (rawData['urls'] as List)
              .map((e) => e.toString())
              .where((url) => url.trim().isNotEmpty)
              .map(_apiClient.config.resolveMediaUrl)
              .toList(growable: false);
        }
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
        return const <String>[];
      },
    );
  }
}
