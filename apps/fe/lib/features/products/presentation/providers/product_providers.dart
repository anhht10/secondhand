import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/network_result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/product_remote_data_source.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';

final productRemoteDataSourceProvider =
    Provider<ProductRemoteDataSource>((ref) {
  return ProductRemoteDataSource(ref.watch(apiClientProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    remoteDataSource: ref.watch(productRemoteDataSourceProvider),
    localPreferences: ref.watch(localPreferencesProvider),
  );
});

/// State for the Home / Discovery product feed.
class ProductFeedState {
  const ProductFeedState({
    this.items = const <ProductModel>[],
    this.query = const ProductFilterQuery(),
    this.meta,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isFromOfflineCache = false,
    this.cachedAt,
    this.error,
  });

  final List<ProductModel> items;
  final ProductFilterQuery query;
  final PaginationMeta? meta;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isFromOfflineCache;
  final DateTime? cachedAt;
  final ApiException? error;

  bool get hasNextPage =>
      !isFromOfflineCache && (meta?.hasNextPage ?? false);

  ProductFeedState copyWith({
    List<ProductModel>? items,
    ProductFilterQuery? query,
    PaginationMeta? meta,
    bool clearMeta = false,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isFromOfflineCache,
    DateTime? cachedAt,
    ApiException? error,
    bool clearError = false,
  }) {
    return ProductFeedState(
      items: items ?? this.items,
      query: query ?? this.query,
      meta: clearMeta ? null : (meta ?? this.meta),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isFromOfflineCache: isFromOfflineCache ?? this.isFromOfflineCache,
      cachedAt: cachedAt ?? this.cachedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages product discovery, search, category/condition/price filtering,
/// sorting, pagination, and offline cached mode.
class ProductFeedController extends StateNotifier<ProductFeedState> {
  ProductFeedController({
    required this.repository,
    bool autoLoad = true,
  }) : super(const ProductFeedState()) {
    if (autoLoad) {
      Future<void>.microtask(loadInitial);
    }
  }

  final ProductRepository repository;

  Future<void> loadInitial() async {
    final resetQuery = state.query.copyWith(page: 1);
    state = state.copyWith(
      query: resetQuery,
      isLoading: true,
      clearError: true,
    );

    final result = await repository.getProducts(resetQuery);
    if (!mounted) return;

    result.when(
      success: (feed, _, _) {
        state = state.copyWith(
          items: feed.items,
          meta: feed.meta,
          isLoading: false,
          isFromOfflineCache: feed.isFromOfflineCache,
          cachedAt: feed.cachedAt,
          clearError: true,
        );
      },
      failure: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error,
        );
      },
    );
  }

  Future<void> refresh() => loadInitial();

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasNextPage) {
      return;
    }

    final nextQuery = state.query.copyWith(page: state.query.page + 1);
    state = state.copyWith(isLoadingMore: true, clearError: true);

    final result = await repository.getProducts(nextQuery);
    if (!mounted) return;

    result.when(
      success: (feed, _, _) {
        final existingIds = state.items.map((e) => e.id).toSet();
        final newItems = feed.items
            .where((item) => !existingIds.contains(item.id))
            .toList(growable: false);
        state = state.copyWith(
          items: <ProductModel>[...state.items, ...newItems],
          query: nextQuery,
          meta: feed.meta,
          isLoadingMore: false,
        );
      },
      failure: (error) {
        state = state.copyWith(
          isLoadingMore: false,
          error: error,
        );
      },
    );
  }

  Future<void> updateSearch(String keyword) async {
    final trimmed = keyword.trim();
    if ((state.query.search ?? '') == trimmed) return;
    state = state.copyWith(
      query: state.query.copyWith(
        page: 1,
        search: trimmed.isEmpty ? null : trimmed,
        clearSearch: trimmed.isEmpty,
      ),
    );
    await loadInitial();
  }

  Future<void> selectCategory(String? categoryId) async {
    state = state.copyWith(
      query: state.query.copyWith(
        page: 1,
        categoryId: categoryId,
        clearCategory: categoryId == null || categoryId.isEmpty,
      ),
    );
    await loadInitial();
  }

  Future<void> applyFilters(ProductFilterQuery updatedQuery) async {
    state = state.copyWith(query: updatedQuery.copyWith(page: 1));
    await loadInitial();
  }

  Future<void> clearAllFilters() async {
    state = state.copyWith(query: const ProductFilterQuery());
    await loadInitial();
  }

  Future<void> setSearchKeyword(String keyword) => updateSearch(keyword);
  Future<void> clearFilters() => clearAllFilters();
}

final productFeedControllerProvider =
    StateNotifierProvider<ProductFeedController, ProductFeedState>((ref) {
  return ProductFeedController(
    repository: ref.watch(productRepositoryProvider),
  );
});

/// Fetches a single product's full details (`GET /api/v1/products/:id`).
final productDetailProvider =
    FutureProvider.family<ProductModel, String>((ref, productId) async {
  final repo = ref.watch(productRepositoryProvider);
  final result = await repo.getProductById(productId);
  return result.when(
    success: (product, _, _) => product,
    failure: (error) => throw error,
  );
});

/// Fetches related products in the same category excluding the current product.
final relatedProductsProvider = FutureProvider.family<List<ProductModel>,
    ({String productId, String categoryId})>((ref, params) async {
  if (params.categoryId.trim().isEmpty) {
    return const <ProductModel>[];
  }
  final repo = ref.watch(productRepositoryProvider);
  final result = await repo.getProducts(
    ProductFilterQuery(
      categoryId: params.categoryId,
      limit: 6,
    ),
  );
  return result.when(
    success: (feed, _, _) => feed.items
        .where((p) => p.id != params.productId)
        .take(4)
        .toList(growable: false),
    failure: (_) => const <ProductModel>[],
  );
});

/// Fetches active listings belonging to a specific seller (`GET /products?sellerId=:id`).
final sellerProductsProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, sellerId) async {
  final repo = ref.watch(productRepositoryProvider);
  final result = await repo.getProducts(
    ProductFilterQuery(sellerId: sellerId, limit: 20),
  );
  return result.when(
    success: (feed, _, _) => feed.items,
    failure: (error) => throw error,
  );
});
