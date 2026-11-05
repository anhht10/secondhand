import '../../../../core/network/network_result.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../datasources/review_remote_data_source.dart';
import '../models/review_models.dart';

class ReviewRepository {
  const ReviewRepository(this._remoteDataSource);

  final ReviewRemoteDataSource _remoteDataSource;

  Future<NetworkResult<ReviewModel>> createReview({
    required String orderId,
    required int rating,
    required String comment,
    List<String> images = const <String>[],
  }) {
    return _remoteDataSource.createReview(
      orderId: orderId,
      rating: rating,
      comment: comment,
      images: images,
    );
  }

  Future<NetworkResult<ReviewModel>> getReviewById(String reviewId) {
    return _remoteDataSource.getReviewById(reviewId);
  }

  Future<NetworkResult<ReviewModel?>> getReviewByOrderId(String orderId) {
    return _remoteDataSource.getReviewByOrderId(orderId);
  }

  Future<NetworkResult<ReviewModel>> updateReview({
    required String reviewId,
    int? rating,
    String? comment,
    List<String>? images,
  }) {
    return _remoteDataSource.updateReview(
      reviewId: reviewId,
      rating: rating,
      comment: comment,
      images: images,
    );
  }

  Future<NetworkResult<ReviewModel>> replyToReview({
    required String reviewId,
    required String reply,
  }) {
    return _remoteDataSource.replyToReview(
      reviewId: reviewId,
      reply: reply,
    );
  }

  Future<NetworkResult<Map<String, dynamic>>> reportReview({
    required String reviewId,
    required String reason,
    String? description,
  }) {
    return _remoteDataSource.reportReview(
      reviewId: reviewId,
      reason: reason,
      description: description,
    );
  }

  Future<NetworkResult<PaginatedSellerReviewsModel>> getSellerReviews({
    required String sellerId,
    int page = 1,
    int limit = 10,
    int? rating,
    ReviewSortOption sort = ReviewSortOption.newest,
  }) {
    return _remoteDataSource.getSellerReviews(
      sellerId: sellerId,
      page: page,
      limit: limit,
      rating: rating,
      sort: sort,
    );
  }

  Future<NetworkResult<SellerReputationModel>> getSellerReputation(
    String sellerId,
  ) {
    return _remoteDataSource.getSellerReputation(sellerId);
  }

  Future<NetworkResult<List<String>>> uploadReviewImages(
    List<UploadableImageFile> files,
  ) {
    return _remoteDataSource.uploadReviewImages(files);
  }
}
