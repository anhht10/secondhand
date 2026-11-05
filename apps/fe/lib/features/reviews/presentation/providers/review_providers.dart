import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/review_remote_data_source.dart';
import '../../data/models/review_models.dart';
import '../../data/repositories/review_repository.dart';

final reviewRemoteDataSourceProvider = Provider<ReviewRemoteDataSource>((ref) {
  return ReviewRemoteDataSource(ref.watch(apiClientProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(reviewRemoteDataSourceProvider));
});

/// Fetches a single review by `reviewId`.
final reviewDetailProvider =
    FutureProvider.autoDispose.family<ReviewModel, String>((ref, reviewId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final result = await repo.getReviewById(reviewId);
  return result.when(
    success: (review, _, _) => review,
    failure: (error) => throw error,
  );
});

/// Fetches the review for a specific `orderId` (if one exists).
final orderReviewProvider =
    FutureProvider.autoDispose.family<ReviewModel?, String>((ref, orderId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final result = await repo.getReviewByOrderId(orderId);
  return result.when(
    success: (review, _, _) => review,
    failure: (_) => null,
  );
});

/// Fetches seller reputation score, rating distribution, and transaction statistics.
final sellerReputationProvider = FutureProvider.autoDispose
    .family<SellerReputationModel, String>((ref, sellerId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  final result = await repo.getSellerReputation(sellerId);
  return result.when(
    success: (reputation, _, _) => reputation,
    failure: (error) => throw error,
  );
});

class SellerReviewsListState {
  const SellerReviewsListState({
    this.items = const <ReviewModel>[],
    this.ratingSummary = const RatingSummaryModel(),
    this.selectedRating,
    this.sort = ReviewSortOption.newest,
    this.page = 1,
    this.totalPages = 1,
    this.hasNextPage = false,
    this.isLoading = false,
    this.isReplying = false,
    this.error,
  });

  final List<ReviewModel> items;
  final RatingSummaryModel ratingSummary;
  final int? selectedRating;
  final ReviewSortOption sort;
  final int page;
  final int totalPages;
  final bool hasNextPage;
  final bool isLoading;
  final bool isReplying;
  final ApiException? error;

  SellerReviewsListState copyWith({
    List<ReviewModel>? items,
    RatingSummaryModel? ratingSummary,
    int? selectedRating,
    bool clearSelectedRating = false,
    ReviewSortOption? sort,
    int? page,
    int? totalPages,
    bool? hasNextPage,
    bool? isLoading,
    bool? isReplying,
    ApiException? error,
    bool clearError = false,
  }) {
    return SellerReviewsListState(
      items: items ?? this.items,
      ratingSummary: ratingSummary ?? this.ratingSummary,
      selectedRating:
          clearSelectedRating ? null : (selectedRating ?? this.selectedRating),
      sort: sort ?? this.sort,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      isLoading: isLoading ?? this.isLoading,
      isReplying: isReplying ?? this.isReplying,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SellerReviewsNotifier extends StateNotifier<SellerReviewsListState> {
  SellerReviewsNotifier(this._ref, this._repository, this.sellerId)
      : super(const SellerReviewsListState()) {
    loadReviews();
  }

  final Ref _ref;
  final ReviewRepository _repository;
  final String sellerId;

  Future<void> loadReviews({int page = 1}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.getSellerReviews(
      sellerId: sellerId,
      page: page,
      limit: 10,
      rating: state.selectedRating,
      sort: state.sort,
    );
    if (!mounted) return;
    result.when(
      success: (paginated, _, _) {
        final combinedItems =
            page <= 1 ? paginated.items : <ReviewModel>[...state.items, ...paginated.items];
        state = state.copyWith(
          items: combinedItems,
          ratingSummary: paginated.ratingSummary,
          page: paginated.page,
          totalPages: paginated.totalPages,
          hasNextPage: paginated.hasNextPage,
          isLoading: false,
          clearError: true,
        );
      },
      failure: (err) {
        state = state.copyWith(isLoading: false, error: err);
      },
    );
  }

  Future<void> filterByRating(int? rating) async {
    if (rating == null) {
      state = state.copyWith(clearSelectedRating: true, page: 1);
    } else if (state.selectedRating == rating) {
      state = state.copyWith(clearSelectedRating: true, page: 1);
    } else {
      state = state.copyWith(selectedRating: rating, page: 1);
    }
    await loadReviews(page: 1);
  }

  Future<void> changeSort(ReviewSortOption sort) async {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort, page: 1);
    await loadReviews(page: 1);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasNextPage) return;
    await loadReviews(page: state.page + 1);
  }

  Future<ReviewModel?> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    state = state.copyWith(isReplying: true, clearError: true);
    final result = await _repository.replyToReview(
      reviewId: reviewId,
      reply: reply,
    );
    if (!mounted) return null;
    ReviewModel? updated;
    result.when(
      success: (rev, _, _) {
        updated = rev;
        final updatedList = state.items
            .map((item) => item.id == rev.id ? rev : item)
            .toList(growable: false);
        state = state.copyWith(
          items: updatedList,
          isReplying: false,
          clearError: true,
        );
        _ref.invalidate(reviewDetailProvider(reviewId));
        _ref.invalidate(sellerReputationProvider(sellerId));
      },
      failure: (err) {
        state = state.copyWith(isReplying: false, error: err);
      },
    );
    return updated;
  }
}

final sellerReviewsNotifierProvider = StateNotifierProvider.autoDispose
    .family<SellerReviewsNotifier, SellerReviewsListState, String>(
        (ref, sellerId) {
  return SellerReviewsNotifier(
    ref,
    ref.watch(reviewRepositoryProvider),
    sellerId,
  );
});

class ReviewSubmissionState {
  const ReviewSubmissionState({
    this.isSubmitting = false,
    this.isUploadingImages = false,
    this.uploadedImageUrls = const <String>[],
    this.submittedReview,
    this.error,
  });

  final bool isSubmitting;
  final bool isUploadingImages;
  final List<String> uploadedImageUrls;
  final ReviewModel? submittedReview;
  final ApiException? error;

  ReviewSubmissionState copyWith({
    bool? isSubmitting,
    bool? isUploadingImages,
    List<String>? uploadedImageUrls,
    ReviewModel? submittedReview,
    ApiException? error,
    bool clearError = false,
  }) {
    return ReviewSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploadingImages: isUploadingImages ?? this.isUploadingImages,
      uploadedImageUrls: uploadedImageUrls ?? this.uploadedImageUrls,
      submittedReview: submittedReview ?? this.submittedReview,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReviewSubmissionNotifier extends StateNotifier<ReviewSubmissionState> {
  ReviewSubmissionNotifier(this._ref, this._repository)
      : super(const ReviewSubmissionState());

  final Ref _ref;
  final ReviewRepository _repository;

  void setInitialImages(List<String> urls) {
    state = state.copyWith(uploadedImageUrls: List<String>.from(urls));
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= state.uploadedImageUrls.length) return;
    final next = List<String>.from(state.uploadedImageUrls)..removeAt(index);
    state = state.copyWith(uploadedImageUrls: next);
  }

  Future<List<String>> uploadSelectedImages(
    List<UploadableImageFile> files,
  ) async {
    if (files.isEmpty) return state.uploadedImageUrls;
    state = state.copyWith(isUploadingImages: true, clearError: true);
    final result = await _repository.uploadReviewImages(files);
    if (!mounted) return state.uploadedImageUrls;

    return result.when(
      success: (urls, _, _) {
        final merged = <String>[...state.uploadedImageUrls, ...urls]
            .take(5)
            .toList(growable: false);
        state = state.copyWith(
          isUploadingImages: false,
          uploadedImageUrls: merged,
          clearError: true,
        );
        return merged;
      },
      failure: (err) {
        state = state.copyWith(isUploadingImages: false, error: err);
        return state.uploadedImageUrls;
      },
    );
  }

  Future<ReviewModel?> submitReview({
    required String orderId,
    required int rating,
    required String comment,
    List<String>? images,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await _repository.createReview(
      orderId: orderId,
      rating: rating,
      comment: comment,
      images: images ?? state.uploadedImageUrls,
    );
    if (!mounted) return null;

    ReviewModel? created;
    result.when(
      success: (rev, _, _) {
        created = rev;
        state = state.copyWith(
          isSubmitting: false,
          submittedReview: rev,
          clearError: true,
        );
        _invalidateRelatedProviders(rev);
      },
      failure: (err) {
        state = state.copyWith(isSubmitting: false, error: err);
      },
    );
    return created;
  }

  Future<ReviewModel?> updateExistingReview({
    required String reviewId,
    required int rating,
    required String comment,
    List<String>? images,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await _repository.updateReview(
      reviewId: reviewId,
      rating: rating,
      comment: comment,
      images: images ?? state.uploadedImageUrls,
    );
    if (!mounted) return null;

    ReviewModel? updated;
    result.when(
      success: (rev, _, _) {
        updated = rev;
        state = state.copyWith(
          isSubmitting: false,
          submittedReview: rev,
          clearError: true,
        );
        _invalidateRelatedProviders(rev);
      },
      failure: (err) {
        state = state.copyWith(isSubmitting: false, error: err);
      },
    );
    return updated;
  }

  void _invalidateRelatedProviders(ReviewModel rev) {
    _ref.invalidate(orderDetailProvider(rev.orderId));
    _ref.invalidate(orderReviewProvider(rev.orderId));
    _ref.invalidate(reviewDetailProvider(rev.id));
    _ref.invalidate(buyerOrdersProvider);
    _ref.invalidate(sellerOrdersProvider);
    _ref.invalidate(sellerReputationProvider(rev.sellerId));
    _ref.invalidate(sellerReviewsNotifierProvider(rev.sellerId));
    _ref.invalidate(publicSellerProfileProvider(rev.sellerId));
  }
}

final reviewSubmissionProvider = StateNotifierProvider.autoDispose<
    ReviewSubmissionNotifier, ReviewSubmissionState>((ref) {
  return ReviewSubmissionNotifier(ref, ref.watch(reviewRepositoryProvider));
});
