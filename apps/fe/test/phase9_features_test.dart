import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/app/theme/app_theme.dart';
import 'package:remarket_fe/core/config/app_config.dart';
import 'package:remarket_fe/core/errors/api_exception.dart';
import 'package:remarket_fe/core/network/network_result.dart';
import 'package:remarket_fe/core/storage/local_preferences.dart';
import 'package:remarket_fe/features/ai/data/models/ai_models.dart';
import 'package:remarket_fe/features/ai/data/repositories/ai_repository.dart';
import 'package:remarket_fe/features/ai/presentation/providers/ai_providers.dart';
import 'package:remarket_fe/features/ai/presentation/screens/ai_shopping_chat_screen.dart';
import 'package:remarket_fe/features/categories/data/models/category_model.dart';
import 'package:remarket_fe/features/categories/presentation/providers/category_providers.dart';
import 'package:remarket_fe/features/home/presentation/screens/home_screen.dart';
import 'package:remarket_fe/features/listings/data/models/listing_draft_model.dart';
import 'package:remarket_fe/features/listings/presentation/screens/create_listing_screen.dart';
import 'package:remarket_fe/features/messages/data/models/message_models.dart';
import 'package:remarket_fe/features/orders/presentation/providers/order_providers.dart';
import 'package:remarket_fe/features/products/data/datasources/product_remote_data_source.dart';
import 'package:remarket_fe/features/products/data/models/product_model.dart';
import 'package:remarket_fe/features/products/data/repositories/product_repository.dart';
import 'package:remarket_fe/features/products/presentation/providers/product_providers.dart';
import 'package:remarket_fe/features/products/presentation/screens/product_detail_screen.dart';
import 'package:remarket_fe/features/reports/data/models/report_model.dart';
import 'package:remarket_fe/features/wishlist/data/repositories/wishlist_repository.dart';
import 'package:remarket_fe/features/wishlist/presentation/providers/wishlist_providers.dart';
import 'package:remarket_fe/shared/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProductRemoteDataSource implements ProductRemoteDataSource {
  bool shouldFailNetwork = false;
  List<ProductModel> remoteProducts = <ProductModel>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<List<ProductModel>>> getProducts(
    ProductFilterQuery query,
  ) async {
    if (shouldFailNetwork) {
      return const NetworkFailure<List<ProductModel>>(
        ApiException(
          message: 'Không có kết nối mạng',
          code: ApiErrorCodes.networkError,
          isNetworkError: true,
        ),
      );
    }
    return NetworkSuccess<List<ProductModel>>(
      data: remoteProducts,
      meta: PaginationMeta(
        page: 1,
        limit: 20,
        total: remoteProducts.length,
        totalPages: 1,
        hasNextPage: false,
        hasPrevPage: false,
      ),
    );
  }
}

class _FakeWishlistRepository implements WishlistRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<List<ProductModel>>> getWishlist() async {
    return const NetworkSuccess<List<ProductModel>>(data: <ProductModel>[]);
  }
}

class _FakeAiRepository implements AiRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<NetworkResult<AiChatResponseModel>> sendChatMessage({
    required String message,
    String? threadId,
    double? maxBudget,
    String? category,
    Map<String, dynamic>? focusedProduct,
  }) async {
    return NetworkSuccess<AiChatResponseModel>(
      data: AiChatResponseModel(
        reply: 'Gợi ý cho bạn bàn phím cơ Keychron K2 Pro tình trạng Như mới.',
        threadId: 'thread-demo-001',
        toolsUsed: const <String>['search_products'],
        matchedProducts: <ProductModel>[_demoProduct],
        followUpQuestions: const <String>[
          'Kiểm tra switch bàn phím cơ như thế nào?',
        ],
      ),
    );
  }

  @override
  Future<NetworkResult<void>> deleteConversation(String conversationId) async {
    return const NetworkSuccess<void>(data: null);
  }
}

const ProductModel _demoProduct = ProductModel(
  id: 'prod-001',
  title: 'Bàn phím cơ Keychron K2 Pro RGB Hotswap',
  description:
      'Bàn phím cơ không dây 75%, khung nhôm chắc chắn, đầy đủ phụ kiện.',
  price: 1450000,
  originalPrice: 2400000,
  condition: ProductCondition.likeNew,
  defectDisclosure: 'Trầy nhẹ 1 vết nhỏ ở cạnh dưới khung nhôm, pin tốt 95%.',
  images: <String>[],
  status: ProductStatus.active,
  location: 'Quận 1, TP.HCM',
  seller: ProductSellerSummary(
    id: 'seller-001',
    displayName: 'Trần Minh Quân',
    location: 'Quận 1, TP.HCM',
    isEmailVerified: true,
  ),
  category: ProductCategorySummary(
    id: 'cat-electronics',
    name: 'Đồ điện tử & Công nghệ',
  ),
  viewsCount: 42,
);

void main() {
  group('Phase 9 — Product, Status State Machine & AI Models Unit Tests', () {
    test(
      'ProductStatus enforces Backend state machine transitions and SOLD lock',
      () {
        expect(ProductStatus.draft.canEditAndDelete, isTrue);
        expect(ProductStatus.active.canEditAndDelete, isTrue);
        expect(ProductStatus.reserved.canEditAndDelete, isTrue);
        expect(ProductStatus.sold.canEditAndDelete, isFalse);

        expect(
          ProductStatus.active.allowedTransitions,
          containsAll(<ProductStatus>[
            ProductStatus.reserved,
            ProductStatus.sold,
            ProductStatus.archived,
          ]),
        );
        expect(
          ProductStatus.sold.allowedTransitions,
          equals(const <ProductStatus>[ProductStatus.archived]),
        );
      },
    );

    test(
      'ProductModel computes discountPercentage and defect disclosure flag accurately',
      () {
        expect(_demoProduct.hasDefectDisclosure, isTrue);
        expect(_demoProduct.discountPercentage, equals(40));

        final json = _demoProduct.toJson();
        final roundTrip = ProductModel.fromJson(json);
        expect(roundTrip.id, equals('prod-001'));
        expect(roundTrip.title, equals(_demoProduct.title));
        expect(roundTrip.condition, equals(ProductCondition.likeNew));
        expect(roundTrip.defectDisclosure, equals(_demoProduct.defects));
      },
    );

    test(
      'AiModels parse generate-listing, estimate-price, buyer-checklist, and chat payloads',
      () {
        final listing = AiGeneratedListingModel.fromJson(<String, dynamic>{
          'suggestedTitle': 'Keychron K2 Pro Hotswap 99% Fullbox',
          'description': 'Tổng quan...\nTình trạng...\nPhụ kiện...',
          'suggestedCategory': 'Đồ điện tử',
          'tags': <String>['keychron', 'banphimco'],
          'transparencyNote': 'Đã công khai vết xước nhẹ ở khung nhôm',
          'condition_tips': <String>['Chụp rõ mặt đáy và cổng sạc Type-C'],
        });
        expect(listing.title, equals('Keychron K2 Pro Hotswap 99% Fullbox'));
        expect(listing.tags, hasLength(2));
        expect(listing.conditionTips, hasLength(1));

        final priceEst = AiPriceEstimateModel.fromJson(<String, dynamic>{
          'quickSellPrice': 1250000,
          'recommendedPrice': 1450000,
          'maxFairPrice': 1600000,
          'confidence': 0.85,
          'reasoning': 'Dựa trên 4 sản phẩm tương tự đang bán trên ReMarket.',
        });
        expect(priceEst.quickSellPrice, equals(1250000));
        expect(priceEst.recommendedPrice, equals(1450000));
        expect(priceEst.maxFairPrice, equals(1600000));
        expect(priceEst.confidenceLabelVi, equals('Độ tin cậy cao'));

        final checklist = AiBuyerChecklistModel.fromJson(<String, dynamic>{
          'productId': 'prod-001',
          'checklist': <String>[
            'Kiểm tra toàn bộ phím bấm và kết nối Bluetooth',
            'Kiểm tra vết xước ở cạnh dưới khung nhôm đúng mô tả',
          ],
          'questionsForSeller': <String>['Bàn phím còn giữ keycap puller không?'],
          'riskNotes': <String>['Kiểm tra kỹ cổng USB-C không bị lỏng'],
        });
        expect(checklist.checklist, hasLength(2));
        expect(checklist.questionsForSeller, hasLength(1));
        expect(checklist.recommendedExpandedView, isTrue);
      },
    );

    test(
      'ConversationModel, MessageModel, and ReportModel parse nested payloads accurately',
      () {
        final conv = ConversationModel.fromJson(<String, dynamic>{
          '_id': 'conv-001',
          'buyerId': <String, dynamic>{
            '_id': 'buyer-1',
            'displayName': 'Nguyễn Văn An',
          },
          'sellerId': <String, dynamic>{
            '_id': 'seller-1',
            'displayName': 'Trần Minh Quân',
          },
          'productId': <String, dynamic>{
            '_id': 'prod-001',
            'title': 'Keychron K2 Pro',
            'price': 1450000,
            'condition': 'LIKE_NEW',
            'status': 'ACTIVE',
          },
          'lastMessage': 'Sản phẩm còn không bạn?',
        });

        expect(conv.counterpartFor('buyer-1').displayName, 'Trần Minh Quân');
        expect(conv.counterpartFor('seller-1').displayName, 'Nguyễn Văn An');

        final report = ReportModel.fromJson(<String, dynamic>{
          '_id': 'rep-001',
          'reporterId': 'buyer-1',
          'productId': <String, dynamic>{
            '_id': 'prod-001',
            'title': 'Keychron K2 Pro',
            'price': 1450000,
          },
          'reason': ReportReasons.predefinedReasons.first,
          'status': 'PENDING',
        });
        expect(report.statusLabel, equals('Đang chờ xử lý'));
      },
    );
  });

  group('Phase 9 — Offline Feed Cache & Local Draft Persistence Tests', () {
    test(
      'ProductRepository caches page 1 online and falls back to offline cache when network fails',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final localPreferences = LocalPreferences(prefs);
        final fakeRemote = _FakeProductRemoteDataSource()
          ..remoteProducts = <ProductModel>[_demoProduct];

        final repository = ProductRepository(
          remoteDataSource: fakeRemote,
          localPreferences: localPreferences,
        );

        // 1. Online fetch -> saves to cache
        final onlineResult =
            await repository.getProducts(const ProductFilterQuery());
        expect(onlineResult, isA<NetworkSuccess<ProductFeedResponse>>());
        final onlineFeed =
            (onlineResult as NetworkSuccess<ProductFeedResponse>).data;
        expect(onlineFeed.isFromOfflineCache, isFalse);
        expect(onlineFeed.items, hasLength(1));
        expect(localPreferences.readCachedProductsJson(), hasLength(1));

        // 2. Simulate offline disconnect -> returns cached feed with isFromOfflineCache = true
        fakeRemote.shouldFailNetwork = true;
        final offlineResult =
            await repository.getProducts(const ProductFilterQuery());
        expect(offlineResult, isA<NetworkSuccess<ProductFeedResponse>>());
        final offlineFeed =
            (offlineResult as NetworkSuccess<ProductFeedResponse>).data;
        expect(offlineFeed.isFromOfflineCache, isTrue);
        expect(offlineFeed.items.first.title, equals(_demoProduct.title));
      },
    );

    test(
      'LocalPreferences persists ListingDraftModel and Buyer Checklist checkmarks',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final localPrefs = LocalPreferences(prefs);

        const draft = ListingDraftModel(
          title: 'Tai nghe Sony WH-1000XM4',
          priceText: '3200000',
          defectDisclosure: 'Đệm tai hơi mòn nhẹ, chống ồn hoạt động tốt',
        );
        await localPrefs.saveListingDraftJson(draft.toJson());

        final restoredRaw = localPrefs.readListingDraftJson();
        expect(restoredRaw, isNotNull);
        final restoredDraft = ListingDraftModel.fromJson(restoredRaw!);
        expect(restoredDraft.title, equals('Tai nghe Sony WH-1000XM4'));
        expect(restoredDraft.isNotEmpty, isTrue);

        await localPrefs.saveCheckedChecklistIndices('prod-001', <int>{0, 2});
        expect(
          localPrefs.readCheckedChecklistIndices('prod-001'),
          equals(<int>{0, 2}),
        );
      },
    );
  });

  group('Phase 9 — Feature Screens Widget Tests', () {
    testWidgets(
      'HomeScreen displays offline cached warning banner and product cards when served from cache',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final localPreferences = LocalPreferences(prefs);
        await localPreferences.saveCachedProductsJson(
          <Map<String, dynamic>>[_demoProduct.toJson()],
        );

        final fakeRemote = _FakeProductRemoteDataSource()
          ..shouldFailNetwork = true;
        final productRepo = ProductRepository(
          remoteDataSource: fakeRemote,
          localPreferences: localPreferences,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              productRepositoryProvider.overrideWithValue(productRepo),
              wishlistRepositoryProvider
                  .overrideWithValue(_FakeWishlistRepository()),
              categoriesProvider.overrideWith(
                (ref) async => const <CategoryModel>[
                  CategoryModel(
                    id: 'cat-electronics',
                    name: 'Đồ điện tử',
                    slug: 'do-dien-tu',
                  ),
                ],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const HomeScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Offline Cached Mode Banner should be visible
        expect(
          find.text('Chế độ ngoại tuyến — Đang xem dữ liệu đã lưu'),
          findsOneWidget,
        );
        // Cached product title & transparency badge should be visible
        expect(
          find.text('Bàn phím cơ Keychron K2 Pro RGB Hotswap'),
          findsOneWidget,
        );
        expect(find.text('Minh bạch tình trạng'), findsOneWidget);
      },
    );

    testWidgets(
      'ProductDetailScreen renders mandatory defect disclosure card and interactive AI Buyer Checklist',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              wishlistRepositoryProvider
                  .overrideWithValue(_FakeWishlistRepository()),
              productDetailProvider('prod-001').overrideWith(
                (ref) async => _demoProduct,
              ),
              productOrderSummaryProvider('prod-001').overrideWith(
                (ref) async => null,
              ),
              relatedProductsProvider(
                (productId: 'prod-001', categoryId: 'cat-electronics'),
              ).overrideWith((ref) async => const <ProductModel>[]),
              buyerChecklistProvider('prod-001').overrideWith(
                (ref) async => const AiBuyerChecklistModel(
                  productId: 'prod-001',
                  checklist: <String>[
                    'Kiểm tra kết nối Bluetooth trên 3 thiết bị',
                    'Kiểm tra vết xước nhẹ ở khung nhôm dưới',
                  ],
                  questionsForSeller: <String>[
                    'Pin dùng liên tục được bao lâu?',
                  ],
                  riskNotes: <String>['Test kỹ từng switch trước khi nhận'],
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProductDetailScreen(productId: 'prod-001'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify product title & mandatory defect disclosure
        expect(
          find.text('Bàn phím cơ Keychron K2 Pro RGB Hotswap'),
          findsOneWidget,
        );
        expect(
          find.text('Công khai Tình trạng & Khuyết điểm'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Trầy nhẹ 1 vết nhỏ ở cạnh dưới khung nhôm, pin tốt 95%.',
          ),
          findsOneWidget,
        );

        // Expand AI Buyer Checklist
        final openChecklistBtn = find.text('Mở checklist');
        await tester.ensureVisible(openChecklistBtn);
        await tester.tap(openChecklistBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Các bước kiểm tra khi nhận hàng (0/2)'),
          findsOneWidget,
        );
        expect(
          find.text('Kiểm tra kết nối Bluetooth trên 3 thiết bị'),
          findsOneWidget,
        );

        // Toggle first checklist item -> progress updates to (1/2)
        await tester.tap(
          find.text('Kiểm tra kết nối Bluetooth trên 3 thiết bị'),
        );
        await tester.pump();
        expect(
          find.text('Các bước kiểm tra khi nhận hàng (1/2)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AiShoppingChatScreen sends message and displays AI reply with matched products',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              aiRepositoryProvider.overrideWithValue(_FakeAiRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const AiShoppingChatScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap one of the initial follow-up suggestion chips
        final suggestionChip = find.text(
          'Tìm bàn phím cơ hoặc phụ kiện máy tính dưới 2 triệu',
        );
        await tester.tap(suggestionChip);
        await tester.pumpAndSettle();

        // Verify AI response text and matched product card appear
        expect(
          find.text(
            'Gợi ý cho bạn bàn phím cơ Keychron K2 Pro tình trạng Như mới.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Bàn phím cơ Keychron K2 Pro RGB Hotswap'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CreateListingScreen renders without layout assertion errors when RmButton(fullWidth: false) is inside Row',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              categoriesProvider.overrideWith(
                (ref) async => const <CategoryModel>[
                  CategoryModel(
                    id: 'cat-electronics',
                    name: 'Đồ điện tử & Công nghệ',
                    slug: 'electronics',
                  ),
                ],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CreateListingScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Đăng bán minh bạch & AI'), findsOneWidget);
        expect(find.text('Gợi ý 3 mức giá'), findsOneWidget);
        expect(find.text('Tạo mô tả bằng AI'), findsOneWidget);
      },
    );
  });

  group('Phase 10 — Cross-Layer Bug Fix Regression Tests (BUG-01 to BUG-06)', () {
    test(
      'BUG-01: ProductFilterQuery.toQueryParameters maps sortBy/sortOrder to NestJS ProductSortBy without non-whitelisted sortOrder',
      () {
        const defaultQuery = ProductFilterQuery();
        final defaultParams = defaultQuery.toQueryParameters();
        expect(defaultParams['sort'], equals('newest'));
        expect(defaultParams.containsKey('sortOrder'), isFalse);
        expect(defaultParams.containsKey('sortBy'), isFalse);

        final priceAscQuery = defaultQuery.copyWith(
          sortBy: 'price',
          sortOrder: 'asc',
          sellerId: '672b3a9f8e1b2c0012345678',
        );
        final priceAscParams = priceAscQuery.toQueryParameters();
        expect(priceAscParams['sort'], equals('price_asc'));
        expect(priceAscParams['sellerId'], equals('672b3a9f8e1b2c0012345678'));
        expect(priceAscParams.containsKey('sortOrder'), isFalse);

        final priceDescQuery = defaultQuery.copyWith(
          sortBy: 'price',
          sortOrder: 'desc',
        );
        expect(priceDescQuery.toQueryParameters()['sort'], equals('price_desc'));

        final popularQuery = defaultQuery.copyWith(
          sortBy: 'viewsCount',
          sortOrder: 'desc',
        );
        expect(popularQuery.toQueryParameters()['sort'], equals('popular'));
      },
    );

    test(
      'BUG-03: UserModel.fromJson parses phoneNumber from NestJS Backend and preserves phone alias',
      () {
        final user = UserModel.fromJson(<String, dynamic>{
          '_id': 'u-001',
          'email': 'khoa@remarket.vn',
          'displayName': 'Khoa Nguyen',
          'phoneNumber': '+84901234567',
          'location': 'Quận 10, TP.HCM',
        });
        expect(user.phone, equals('+84901234567'));
        expect(user.toJson()['phoneNumber'], equals('+84901234567'));
      },
    );

    test(
      'BUG-04 & BUG-05: ProductModel.fromJson extracts url from ProductImage objects, viewCount, tags, and AppConfig resolves /uploads/ paths',
      () {
        final product = ProductModel.fromJson(<String, dynamic>{
          '_id': 'prod-backend-1',
          'title': 'Sony WH-1000XM4',
          'description': 'Tai nghe chống ồn chủ động cao cấp.',
          'price': 4100000,
          'condition': 'LIKE_NEW',
          'status': 'ACTIVE',
          'images': <Map<String, dynamic>>[
            <String, dynamic>{
              'url': '/uploads/products/sony-xm4.jpg',
              'publicId': 'local/products/sony-xm4.jpg',
              'sortOrder': 0,
            },
          ],
          'tags': <String>['sony', 'xm4', 'headphone'],
          'viewCount': 128,
          'sellerId': <String, dynamic>{
            '_id': 'seller-1',
            'displayName': 'Khoa Nguyen',
          },
          'categoryId': <String, dynamic>{
            '_id': 'cat-1',
            'name': 'Thiết bị âm thanh',
          },
        });

        expect(product.images, equals(<String>['/uploads/products/sony-xm4.jpg']));
        expect(product.viewsCount, equals(128));
        expect(product.tags, equals(<String>['sony', 'xm4', 'headphone']));

        final webConfig = AppConfig.fromEnvironment(
          baseUrlOverride: 'http://localhost:3000/api/v1',
        );
        expect(
          webConfig.resolveMediaUrl('/uploads/products/sony-xm4.jpg'),
          equals('http://localhost:3000/uploads/products/sony-xm4.jpg'),
        );

        final androidConfig = AppConfig.fromEnvironment(
          baseUrlOverride: 'http://10.0.2.2:3000/api/v1',
        );
        expect(
          androidConfig.resolveMediaUrl('/uploads/products/sony-xm4.jpg'),
          equals('http://10.0.2.2:3000/uploads/products/sony-xm4.jpg'),
        );
      },
    );

    test(
      'BUG-06: AiModels parse NestJS AiService camelCase/structured responses (string confidence, inspectionPoints, suggestedDescriptionText)',
      () {
        // AI 1: NestJS AiService response shape
        final generated = AiGeneratedListingModel.fromJson(<String, dynamic>{
          'suggestedTitle': 'Sony WH-1000XM4 Chính Hãng 99%',
          'suggestedDescriptionText':
              '1. Tổng quan: Tai nghe chống ồn.\n2. Tình trạng: Đẹp 99%.\n3. Lưu ý: Đầy đủ cáp sạc.',
          'suggestedCategory': 'electronics',
          'suggestedCategoryReason': 'Tai nghe thuộc danh mục Điện tử',
          'suggestedTags': <String>['sony', 'wh1000xm4'],
          'clarificationQuestions': <String>['Còn hộp giấy gốc không?'],
        });
        expect(generated.description, contains('Tai nghe chống ồn'));
        expect(generated.tags, equals(<String>['sony', 'wh1000xm4']));
        expect(generated.conditionTips, equals(<String>['Còn hộp giấy gốc không?']));
        expect(
          generated.transparencyNote,
          equals('Tai nghe thuộc danh mục Điện tử'),
        );

        // AI 2: NestJS AiService response shape with string confidence ("HIGH")
        final priceEst = AiPriceEstimateModel.fromJson(<String, dynamic>{
          'minPrice': 3800000,
          'suggestedPrice': 4100000,
          'maxPrice': 4400000,
          'confidence': 'HIGH',
          'reasoning': 'So sánh với 3 tai nghe Sony XM4 đang rao bán.',
          'marketComparables': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'comp-1',
              'title': 'Sony XM4 Bạc',
              'price': 4150000,
              'condition': 'LIKE_NEW',
            },
          ],
        });
        expect(priceEst.quickSellPrice, equals(3800000));
        expect(priceEst.recommendedPrice, equals(4100000));
        expect(priceEst.maxFairPrice, equals(4400000));
        expect(priceEst.confidence, closeTo(0.9, 0.01));
        expect(priceEst.comparableProducts, hasLength(1));

        // AI 3: NestJS AiService response shape with inspectionPoints objects
        final checklist = AiBuyerChecklistModel.fromJson(<String, dynamic>{
          'productId': 'prod-001',
          'inspectionPoints': <Map<String, dynamic>>[
            <String, dynamic>{
              'title': 'Chống ồn ANC',
              'description': 'Bật thử chế độ ANC và Ambient Sound',
              'importance': 'REQUIRED',
            },
          ],
          'suggestedQuestions': <String>['Tai nghe mua đợt nào?'],
          'safetyTips': <String>['Giao dịch trực tiếp và test kết nối app'],
        });
        expect(
          checklist.checklist.first,
          equals('Chống ồn ANC: Bật thử chế độ ANC và Ambient Sound'),
        );
        expect(checklist.questionsForSeller, hasLength(1));
        expect(checklist.riskNotes, hasLength(1));

        // AI 4: NestJS AiService response shape with message & suggestedActions
        final chatRes = AiChatResponseModel.fromJson(<String, dynamic>{
          'threadId': 'thread-999',
          'message': 'Mình tìm thấy 1 tai nghe Sony WH-1000XM4 phù hợp.',
          'suggestedActions': <String>['So sánh với Bose QC45'],
          'sources': <String>['search_products'],
          'matchedProducts': <Map<String, dynamic>>[_demoProduct.toJson()],
        });
        expect(chatRes.threadId, equals('thread-999'));
        expect(chatRes.reply, contains('Sony WH-1000XM4'));
        expect(chatRes.followUpQuestions, equals(<String>['So sánh với Bose QC45']));
        expect(chatRes.toolsUsed, equals(<String>['search_products']));
        expect(chatRes.matchedProducts, hasLength(1));
      },
    );
  });
}
