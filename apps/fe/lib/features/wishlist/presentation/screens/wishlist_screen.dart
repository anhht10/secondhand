import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/rm_empty_state.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../providers/wishlist_providers.dart';

/// Wishlist Screen (`20 - Wishlist` — `GET /api/v1/auth/wishlist`).
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistState = ref.watch(wishlistControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Sản phẩm đã lưu (${wishlistState.items.length})'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () =>
                ref.read(wishlistControllerProvider.notifier).loadWishlist(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(wishlistControllerProvider.notifier).loadWishlist(),
        child: wishlistState.isLoading && wishlistState.items.isEmpty
            ? const RmLoadingIndicator(
                message: 'Đang tải danh sách yêu thích...',
              )
            : wishlistState.error != null && wishlistState.items.isEmpty
                ? RmErrorState(
                    message: wishlistState.error!.message,
                    onRetry: () => ref
                        .read(wishlistControllerProvider.notifier)
                        .loadWishlist(),
                  )
                : wishlistState.items.isEmpty
                    ? RmEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'Chưa có sản phẩm yêu thích',
                        subtitle:
                            'Nhấn biểu tượng trái tim trên các sản phẩm bạn quan tâm để lưu lại và so sánh giá.',
                        actionLabel: 'Khám phá sản phẩm',
                        onAction: () => context.go(RouteNames.homePath),
                      )
                    : GridView.builder(
                        padding: AppSpacing.screenPadding,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: wishlistState.items.length,
                        itemBuilder: (context, index) {
                          final product = wishlistState.items[index];
                          return ProductCard(
                            product: product,
                            onTap: () => context.push(
                              RouteNames.productDetail(product.id),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
