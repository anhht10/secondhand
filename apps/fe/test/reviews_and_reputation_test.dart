import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/app/theme/app_theme.dart';
import 'package:remarket_fe/core/network/network_result.dart';
import 'package:remarket_fe/features/auth/domain/auth_repository.dart';
import 'package:remarket_fe/features/auth/domain/auth_state.dart';
import 'package:remarket_fe/features/auth/presentation/controllers/auth_controller.dart';
import 'package:remarket_fe/features/orders/data/models/order_model.dart';
import 'package:remarket_fe/features/orders/data/models/payment_model.dart';
import 'package:remarket_fe/features/orders/data/repositories/order_repository.dart';
import 'package:remarket_fe/features/orders/presentation/providers/order_providers.dart';
import 'package:remarket_fe/features/orders/presentation/screens/my_orders_screen.dart';
import 'package:remarket_fe/features/products/data/datasources/product_remote_data_source.dart';
import 'package:remarket_fe/features/reviews/data/models/review_models.dart';
import 'package:remarket_fe/features/reviews/data/repositories/review_repository.dart';
import 'package:remarket_fe/features/reviews/presentation/providers/review_providers.dart';
import 'package:remarket_fe/features/reviews/presentation/screens/seller_reviews_screen.dart';
import 'package:remarket_fe/features/reviews/presentation/screens/write_review_screen.dart';
import 'package:remarket_fe/shared/models/user_model.dart';

class _FakeReviewRepository implements ReviewRepository {
  int createReviewCalls = 0;
  int updateReviewCalls = 0;
  int replyToReviewCalls = 0;
  int? lastRatingSubmitted;
  String? lastCommentSubmitted;
  List<String> lastImagesSubmitted = <String>[];
  String? lastReplySubmitted;
  int? lastFilterRating;

  List<ReviewModel> reviews = <ReviewModel>[_sampleReview5Star, _sampleReview4Star];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<ReviewModel>> createReview({
    required String orderId,
    required int rating,
    required String comment,
    List<String> images = const <String>[],
  }) async {
    createReviewCalls += 1;
    lastRatingSubmitted = rating;
    lastCommentSubmitted = comment;
    lastImagesSubmitted = images;
    final created = ReviewModel(
      id: 'rev-created-1',
      orderId: orderId,
      buyerId: 'buyer-1',
      sellerId: 'seller-1',
      productId: 'prod-1',
      rating: rating,
      comment: comment,
      images: images,
      canBuyerEdit: true,
      createdAt: DateTime(2026, 11, 8, 10),
      updatedAt: DateTime(2026, 11, 8, 10),
    );
    return NetworkSuccess<ReviewModel>(data: created);
  }

  @override
  Future<NetworkResult<ReviewModel>> updateReview({
    required String reviewId,
    int? rating,
    String? comment,
    List<String>? images,
  }) async {
    updateReviewCalls += 1;
    return NetworkSuccess<ReviewModel>(
      data: ReviewModel(
        id: reviewId,
        orderId: 'order-completed-1',
        buyerId: 'buyer-1',
        sellerId: 'seller-1',
        productId: 'prod-1',
        rating: rating ?? 5,
        comment: comment ?? '',
        images: images ?? const <String>[],
        canBuyerEdit: true,
        createdAt: DateTime(2026, 11, 8, 10),
        updatedAt: DateTime(2026, 11, 8, 11),
      ),
    );
  }

  @override
  Future<NetworkResult<ReviewModel?>> getReviewByOrderId(String orderId) async {
    return const NetworkSuccess<ReviewModel?>(data: null);
  }

  @override
  Future<NetworkResult<PaginatedSellerReviewsModel>> getSellerReviews({
    required String sellerId,
    int page = 1,
    int limit = 10,
    int? rating,
    ReviewSortOption sort = ReviewSortOption.newest,
  }) async {
    lastFilterRating = rating;
    final filtered = rating == null
        ? reviews
        : reviews.where((r) => r.rating == rating).toList();
    return NetworkSuccess<PaginatedSellerReviewsModel>(
      data: PaginatedSellerReviewsModel(
        items: filtered,
        ratingSummary: const RatingSummaryModel(
          averageRating: 4.5,
          totalReviews: 2,
          star5Count: 1,
          star4Count: 1,
          ratingDistribution: <int, int>{5: 1, 4: 1, 3: 0, 2: 0, 1: 0},
        ),
        total: filtered.length,
        page: 1,
        limit: 10,
        totalPages: 1,
      ),
    );
  }

  @override
  Future<NetworkResult<SellerReputationModel>> getSellerReputation(
    String sellerId,
  ) async {
    return const NetworkSuccess<SellerReputationModel>(
      data: _sampleSellerReputation,
    );
  }

  @override
  Future<NetworkResult<ReviewModel>> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    replyToReviewCalls += 1;
    lastReplySubmitted = reply;
    final target = reviews.firstWhere(
      (r) => r.id == reviewId,
      orElse: () => _sampleReview5Star,
    );
    return NetworkSuccess<ReviewModel>(
      data: ReviewModel(
        id: target.id,
        orderId: target.orderId,
        buyerId: target.buyerId,
        sellerId: target.sellerId,
        productId: target.productId,
        buyer: target.buyer,
        product: target.product,
        rating: target.rating,
        comment: target.comment,
        images: target.images,
        sellerReply: reply,
        sellerRepliedAt: DateTime(2026, 11, 8, 12),
        createdAt: target.createdAt,
        updatedAt: DateTime(2026, 11, 8, 12),
      ),
    );
  }

  @override
  Future<NetworkResult<List<String>>> uploadReviewImages(
    List<UploadableImageFile> files,
  ) async {
    return const NetworkSuccess<List<String>>(
      data: <String>[
        'http://localhost:3000/uploads/products/review-photo-1.jpg',
      ],
    );
  }
}

class _FakeOrderRepositoryForReviews implements OrderRepository {
  List<OrderModel> buyerOrders = <OrderModel>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<OrderModel>> getOrderById(String orderId) async {
    return NetworkSuccess<OrderModel>(data: _sampleCompletedOrderNoReview);
  }

  @override
  Future<NetworkResult<List<OrderModel>>> getBuyerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return NetworkSuccess<List<OrderModel>>(data: buyerOrders);
  }

  @override
  Future<NetworkResult<List<OrderModel>>> getSellerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return const NetworkSuccess<List<OrderModel>>(data: <OrderModel>[]);
  }
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository(this.user);
  final UserModel user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<UserModel?>> restoreSession() async {
    return NetworkSuccess<UserModel?>(data: user);
  }
}

class _StubAuthController extends AuthController {
  _StubAuthController(UserModel user)
      : super(
          repository: _FakeAuthRepository(user),
          autoRestore: false,
        ) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
    );
  }
}

final _sampleBuyerUser = UserModel(
  id: 'buyer-1',
  email: 'buyer@student.edu.vn',
  displayName: 'Trần Minh Buyer',
  createdAt: DateTime(2026, 1, 1),
);

final _sampleSellerUser = UserModel(
  id: 'seller-1',
  email: 'seller@student.edu.vn',
  displayName: 'Nguyễn An Seller',
  createdAt: DateTime(2026, 1, 1),
);

final _sampleCompletedOrderNoReview = OrderModel(
  id: 'order-completed-1',
  orderCode: 'RM-20261108-9001',
  productId: 'prod-1',
  buyerId: 'buyer-1',
  sellerId: 'seller-1',
  productSnapshot: const OrderProductSnapshotModel(
    title: 'Tai nghe Sony WH-1000XM4',
    price: 3500000,
    condition: 'LIKE_NEW',
  ),
  itemPrice: 3500000,
  shippingFee: 0,
  totalAmount: 3500000,
  deliveryMethod: DeliveryMethod.meetup,
  paymentMethod: PaymentMethod.cod,
  paymentStatus: PaymentStatus.paid,
  status: OrderStatus.completed,
  timeline: const <OrderTimelineEntryModel>[],
  hasReview: false,
  buyer: const OrderPartySummaryModel(
    id: 'buyer-1',
    displayName: 'Trần Minh Buyer',
  ),
  seller: const OrderPartySummaryModel(
    id: 'seller-1',
    displayName: 'Nguyễn An Seller',
  ),
  createdAt: DateTime(2026, 11, 8, 8),
  completedAt: DateTime(2026, 11, 8, 9),
);

final _sampleCompletedOrderWithReview = OrderModel(
  id: 'order-completed-2',
  orderCode: 'RM-20261108-9002',
  productId: 'prod-2',
  buyerId: 'buyer-1',
  sellerId: 'seller-1',
  productSnapshot: const OrderProductSnapshotModel(
    title: 'Bàn phím Keychron K2',
    price: 1200000,
    condition: 'GOOD',
  ),
  itemPrice: 1200000,
  shippingFee: 0,
  totalAmount: 1200000,
  deliveryMethod: DeliveryMethod.delivery,
  paymentMethod: PaymentMethod.bankTransfer,
  paymentStatus: PaymentStatus.paid,
  status: OrderStatus.completed,
  timeline: const <OrderTimelineEntryModel>[],
  reviewId: 'rev-1',
  hasReview: true,
  buyer: const OrderPartySummaryModel(
    id: 'buyer-1',
    displayName: 'Trần Minh Buyer',
  ),
  seller: const OrderPartySummaryModel(
    id: 'seller-1',
    displayName: 'Nguyễn An Seller',
  ),
  createdAt: DateTime(2026, 11, 8, 8),
  completedAt: DateTime(2026, 11, 8, 9),
);

final _sampleReview5Star = ReviewModel(
  id: 'rev-1',
  orderId: 'order-completed-1',
  buyerId: 'buyer-1',
  sellerId: 'seller-1',
  productId: 'prod-1',
  buyer: const ReviewParticipantSummary(
    id: 'buyer-1',
    displayName: 'Trần Minh Buyer',
    isEmailVerified: true,
  ),
  product: const ReviewProductSummary(
    id: 'prod-1',
    title: 'Tai nghe Sony WH-1000XM4',
    price: 3500000,
  ),
  rating: 5,
  comment: 'Tai nghe nguyên zin, chống ồn tốt, người bán giao đúng hẹn!',
  images: const <String>[
    'http://localhost:3000/uploads/products/review-sony.jpg',
  ],
  canBuyerEdit: true,
  canSellerReply: true,
  createdAt: DateTime(2026, 11, 8, 10),
  updatedAt: DateTime(2026, 11, 8, 10),
);

final _sampleReview4Star = ReviewModel(
  id: 'rev-2',
  orderId: 'order-completed-2',
  buyerId: 'buyer-2',
  sellerId: 'seller-1',
  productId: 'prod-2',
  buyer: const ReviewParticipantSummary(
    id: 'buyer-2',
    displayName: 'Lê Hoàng',
    isEmailVerified: true,
  ),
  product: const ReviewProductSummary(
    id: 'prod-2',
    title: 'Bàn phím Keychron K2',
    price: 1200000,
  ),
  rating: 4,
  comment: 'Bàn phím gõ êm, đóng gói cẩn thận, giao hơi trễ 10 phút.',
  sellerReply: 'Cảm ơn bạn Hoàng đã thông cảm và ủng hộ shop nhé!',
  sellerRepliedAt: DateTime(2026, 11, 8, 11),
  createdAt: DateTime(2026, 11, 8, 9),
  updatedAt: DateTime(2026, 11, 8, 11),
);

const _sampleSellerReputation = SellerReputationModel(
  sellerId: 'seller-1',
  reputationScore: 86,
  reputationTier: 'TRUSTED_SELLER',
  averageRating: 4.5,
  ratingSummary: RatingSummaryModel(
    averageRating: 4.5,
    totalReviews: 2,
    star5Count: 1,
    star4Count: 1,
    star3Count: 0,
    star2Count: 0,
    star1Count: 0,
    ratingDistribution: <int, int>{5: 1, 4: 1, 3: 0, 2: 0, 1: 0},
  ),
  transactionStats: TransactionStatsModel(
    completedOrdersCount: 6,
    buyerCancelledOrdersCount: 1,
    sellerRejectedOrdersCount: 0,
    pendingOrdersCount: 0,
    successfulTransactionCount: 6,
    successfulTransactionRate: 100.0,
    repliedReviewsCount: 1,
    sellerReplyRate: 50.0,
  ),
);

void main() {
  group('Review & Seller Reputation Models Unit Tests', () {
    test('ReviewModel.fromJson parses rating, comment, images & sellerReply', () {
      final json = <String, dynamic>{
        'id': 'rev-100',
        'orderId': 'ord-100',
        'buyerId': 'buyer-1',
        'sellerId': 'seller-1',
        'productId': 'prod-1',
        'rating': 5,
        'comment': 'Sản phẩm đúng mô tả, người bán nhiệt tình!',
        'images': <String>['http://localhost:3000/uploads/products/r1.jpg'],
        'sellerReply': 'Cảm ơn bạn đã mua hàng!',
        'canBuyerEdit': true,
        'canSellerReply': false,
        'createdAt': '2026-11-08T10:00:00.000Z',
        'updatedAt': '2026-11-08T10:30:00.000Z',
      };

      final model = ReviewModel.fromJson(json);
      expect(model.id, 'rev-100');
      expect(model.rating, 5);
      expect(model.images, hasLength(1));
      expect(model.hasSellerReply, isTrue);
      expect(model.canBuyerEdit, isTrue);
    });

    test('SellerReputationModel & RatingSummaryModel compute ratios & tier labels', () {
      expect(_sampleSellerReputation.reputationScore, 86);
      expect(_sampleSellerReputation.tierLabelVi, 'Người bán Uy tín cao');
      expect(_sampleSellerReputation.ratingSummary.countForStar(5), 1);
      expect(_sampleSellerReputation.ratingSummary.ratioForStar(5), 0.5);
      expect(
        _sampleSellerReputation.transactionStats.completedOrdersCount,
        6,
      );
    });
  });

  group('WriteReviewScreen Widget Tests', () {
    testWidgets(
      'selects 1..5 stars, validates comment length, manages images, and submits review',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeReviewRepo = _FakeReviewRepository();
        final fakeOrderRepo = _FakeOrderRepositoryForReviews();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reviewRepositoryProvider.overrideWithValue(fakeReviewRepo),
              orderRepositoryProvider.overrideWithValue(fakeOrderRepo),
              authControllerProvider.overrideWith(
                (_) => _StubAuthController(_sampleBuyerUser),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const WriteReviewScreen(orderId: 'order-completed-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Product summary from completed order is shown
        expect(find.text('Tai nghe Sony WH-1000XM4'), findsOneWidget);
        expect(find.text('5 sao — Rất hài lòng, uy tín!'), findsOneWidget);

        // Tap 4-star icon
        await tester.tap(find.byKey(const Key('review_star_4')));
        await tester.pump();
        expect(find.text('4 sao — Hài lòng'), findsOneWidget);

        // Attempt submit with empty comment -> validation error
        await tester.tap(find.byKey(const Key('submit_review_button')));
        await tester.pump();
        expect(find.text('Vui lòng nhập nội dung đánh giá'), findsOneWidget);
        expect(fakeReviewRepo.createReviewCalls, 0);

        // Attempt submit with too short comment (< 10 chars) -> validation error
        await tester.enterText(
          find.byKey(const Key('review_comment_input')),
          'Tốt lắm',
        );
        await tester.tap(find.byKey(const Key('submit_review_button')));
        await tester.pump();
        expect(
          find.text('Nội dung đánh giá cần tối thiểu 10 ký tự'),
          findsOneWidget,
        );

        // Enter valid comment and submit
        await tester.enterText(
          find.byKey(const Key('review_comment_input')),
          'Tai nghe còn rất mới, người bán tư vấn nhiệt tình và đúng hẹn!',
        );
        await tester.tap(find.byKey(const Key('submit_review_button')));
        await tester.pumpAndSettle();

        expect(fakeReviewRepo.createReviewCalls, 1);
        expect(fakeReviewRepo.lastRatingSubmitted, 4);
        expect(
          fakeReviewRepo.lastCommentSubmitted,
          contains('người bán tư vấn nhiệt tình'),
        );
      },
    );
  });

  group('SellerReviewsScreen & Seller Reply Widget Tests', () {
    testWidgets(
      'displays Reputation Score, star distribution, filters by star, and allows Seller reply',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeReviewRepo = _FakeReviewRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reviewRepositoryProvider.overrideWithValue(fakeReviewRepo),
              authControllerProvider.overrideWith(
                (_) => _StubAuthController(_sampleSellerUser),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const SellerReviewsScreen(
                sellerId: 'seller-1',
                sellerName: 'Nguyễn An Seller',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Reputation score & stats displayed
        expect(find.text('Điểm uy tín: 86/100'), findsOneWidget);
        expect(find.text('Người bán Uy tín cao'), findsOneWidget);
        expect(find.text('4.5'), findsOneWidget);
        expect(find.text('2 đánh giá'), findsOneWidget);

        // Both 5-star and 4-star reviews are initially rendered
        expect(find.textContaining('Tai nghe nguyên zin'), findsOneWidget);
        expect(find.textContaining('Bàn phím gõ êm'), findsOneWidget);

        // Filter by 5-star reviews
        await tester.tap(find.byKey(const Key('filter_star_5')));
        await tester.pumpAndSettle();
        expect(fakeReviewRepo.lastFilterRating, 5);
        expect(find.textContaining('Tai nghe nguyên zin'), findsOneWidget);
        expect(find.textContaining('Bàn phím gõ êm'), findsNothing);

        // Seller replies to the 5-star review
        await tester.tap(find.byKey(const Key('reply_review_btn_rev-1')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('seller_reply_input')),
          'Cảm ơn bạn Minh đã giao dịch nhanh gọn nhé!',
        );
        await tester.tap(find.byKey(const Key('submit_seller_reply_button')));
        await tester.pumpAndSettle();

        expect(fakeReviewRepo.replyToReviewCalls, 1);
        expect(
          fakeReviewRepo.lastReplySubmitted,
          'Cảm ơn bạn Minh đã giao dịch nhanh gọn nhé!',
        );
        expect(
          find.text('Cảm ơn bạn Minh đã giao dịch nhanh gọn nhé!'),
          findsOneWidget,
        );
      },
    );
  });

  group('MyOrdersScreen Review Button State Tests', () {
    testWidgets(
      'shows "Đánh giá người bán" on unreviewed completed order and "Đã đánh giá (Xem / Sửa)" when reviewed',
      (tester) async {
        final fakeOrderRepo = _FakeOrderRepositoryForReviews()
          ..buyerOrders = <OrderModel>[
            _sampleCompletedOrderNoReview,
            _sampleCompletedOrderWithReview,
          ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              orderRepositoryProvider.overrideWithValue(fakeOrderRepo),
              authControllerProvider.overrideWith(
                (_) => _StubAuthController(_sampleBuyerUser),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MyOrdersScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('write_review_btn_order-completed-1')),
          findsOneWidget,
        );
        expect(find.text('Đánh giá người bán'), findsOneWidget);

        expect(
          find.byKey(const Key('view_review_btn_order-completed-2')),
          findsOneWidget,
        );
        expect(find.text('Đã đánh giá (Xem / Sửa)'), findsOneWidget);
      },
    );
  });
}
