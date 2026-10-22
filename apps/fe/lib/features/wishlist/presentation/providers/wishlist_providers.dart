import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/data/models/product_model.dart';
import '../../data/repositories/wishlist_repository.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.watch(apiClientProvider));
});

class WishlistState {
  const WishlistState({
    this.items = const <ProductModel>[],
    this.isLoading = false,
    this.error,
  });

  final List<ProductModel> items;
  final bool isLoading;
  final ApiException? error;

  Set<String> get productIds => items.map((e) => e.id).toSet();
  Set<String> get wishlistIds => productIds;

  bool contains(String productId) => productIds.contains(productId);

  WishlistState copyWith({
    List<ProductModel>? items,
    bool? isLoading,
    ApiException? error,
    bool clearError = false,
  }) {
    return WishlistState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WishlistController extends StateNotifier<WishlistState> {
  WishlistController({
    required this.repository,
    bool autoLoad = true,
  }) : super(const WishlistState()) {
    if (autoLoad) {
      Future<void>.microtask(loadWishlist);
    }
  }

  final WishlistRepository repository;

  Future<void> loadWishlist() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await repository.getWishlist();
    if (!mounted) return;

    result.when(
      success: (items, _, _) {
        state = state.copyWith(items: items, isLoading: false);
      },
      failure: (error) {
        state = state.copyWith(isLoading: false, error: error);
      },
    );
  }

  Future<bool> toggleWishlist(ProductModel product) async {
    final isSaved = state.contains(product.id);
    final result = isSaved
        ? await repository.removeFromWishlist(product.id)
        : await repository.addToWishlist(product.id);
    if (!mounted) return false;

    return result.when(
      success: (updatedItems, _, _) {
        state = state.copyWith(items: updatedItems, clearError: true);
        return true;
      },
      failure: (error) {
        state = state.copyWith(error: error);
        return false;
      },
    );
  }
}

final wishlistControllerProvider =
    StateNotifierProvider<WishlistController, WishlistState>((ref) {
  final authState = ref.watch(authControllerProvider);
  return WishlistController(
    repository: ref.watch(wishlistRepositoryProvider),
    autoLoad: authState.isAuthenticated,
  );
});
