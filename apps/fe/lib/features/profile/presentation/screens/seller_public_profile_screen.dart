import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_empty_state.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../../../reviews/data/models/review_models.dart';
import '../../../reviews/presentation/providers/review_providers.dart';
import '../../../reviews/presentation/screens/seller_reviews_screen.dart';
import '../providers/profile_providers.dart';

/// Seller Public Profile Screen (`12 - Seller Public Profile` — `GET /api/v1/users/:id`).
class SellerPublicProfileScreen extends ConsumerWidget {
  const SellerPublicProfileScreen({
    super.key,
    required this.sellerId,
  });

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(publicSellerProfileProvider(sellerId));
    final sellerProductsAsync = ref.watch(sellerProductsProvider(sellerId));
    final reputationAsync = ref.watch(sellerReputationProvider(sellerId));
    final reviewsState = ref.watch(sellerReviewsNotifierProvider(sellerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ người bán'),
      ),
      body: sellerAsync.when(
        loading: () => const RmLoadingIndicator(
          message: 'Đang tải thông tin người bán...',
        ),
        error: (err, _) => RmErrorState(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(publicSellerProfileProvider(sellerId)),
        ),
        data: (seller) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RmCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: AppColors.primaryTintBg,
                                  child: Text(
                                    seller.initials,
                                    style:
                                        AppTypography.headlineMedium.copyWith(
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              seller.displayName,
                                              style: AppTypography.titleLarge,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.verified_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        seller.location?.trim().isNotEmpty ==
                                                true
                                            ? 'Khu vực: ${seller.location}'
                                            : 'Thành viên xác thực ReMarket',
                                        style: AppTypography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (seller.bio != null &&
                                seller.bio!.trim().isNotEmpty) ...[
                              const Divider(height: AppSpacing.lg),
                              Text(
                                seller.bio!,
                                style: AppTypography.bodyMedium,
                              ),
                            ],
                            const Divider(height: AppSpacing.lg),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MiniStat(
                                  label: 'Điểm uy tín',
                                  value:
                                      '${seller.stats?.reputationScore ?? 66}/100',
                                ),
                                _MiniStat(
                                  label: 'Đánh giá',
                                  value: (seller.stats?.totalReviews ?? 0) > 0
                                      ? '${(seller.stats?.rating ?? 0).toStringAsFixed(1)} ★ (${seller.stats?.totalReviews})'
                                      : 'Chưa có',
                                ),
                                _MiniStat(
                                  label: 'Giao dịch xong',
                                  value:
                                      '${seller.stats?.completedOrdersCount ?? seller.stats?.soldListingsCount ?? 0}',
                                ),
                                _MiniStat(
                                  label: 'Đang bán',
                                  value:
                                      '${seller.stats?.activeListingsCount ?? 0}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      reputationAsync.when(
                        data: (reputation) => SellerReputationOverviewCard(
                          reputation: reputation,
                          onViewAllReviews: () => context.push(
                            RouteNames.sellerReviews(sellerId),
                            extra: seller.displayName,
                          ),
                        ),
                        loading: () => SellerReputationOverviewCard(
                          reputation: SellerReputationModel(
                            sellerId: sellerId,
                            reputationScore: seller.stats?.reputationScore ?? 66,
                            averageRating: seller.stats?.rating ?? 0,
                            ratingSummary: RatingSummaryModel(
                              averageRating: seller.stats?.rating ?? 0,
                              totalReviews: seller.stats?.totalReviews ?? 0,
                            ),
                            transactionStats: TransactionStatsModel(
                              completedOrdersCount:
                                  seller.stats?.completedOrdersCount ?? 0,
                            ),
                          ),
                          onViewAllReviews: () => context.push(
                            RouteNames.sellerReviews(sellerId),
                            extra: seller.displayName,
                          ),
                        ),
                        error: (_, _) => SellerReputationOverviewCard(
                          reputation: SellerReputationModel(
                            sellerId: sellerId,
                            reputationScore: seller.stats?.reputationScore ?? 66,
                            averageRating: seller.stats?.rating ?? 0,
                            ratingSummary: RatingSummaryModel(
                              averageRating: seller.stats?.rating ?? 0,
                              totalReviews: seller.stats?.totalReviews ?? 0,
                            ),
                            transactionStats: TransactionStatsModel(
                              completedOrdersCount:
                                  seller.stats?.completedOrdersCount ?? 0,
                            ),
                          ),
                          onViewAllReviews: () => context.push(
                            RouteNames.sellerReviews(sellerId),
                            extra: seller.displayName,
                          ),
                        ),
                      ),
                      if (reviewsState.items.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Đánh giá gần đây từ người mua',
                              style: AppTypography.titleMedium,
                            ),
                            TextButton(
                              onPressed: () => context.push(
                                RouteNames.sellerReviews(sellerId),
                                extra: seller.displayName,
                              ),
                              child: const Text('Xem tất cả'),
                            ),
                          ],
                        ),
                        for (final review in reviewsState.items.take(2)) ...[
                          ReviewItemCard(
                            review: review,
                            onTap: () => context.push(
                              RouteNames.reviewDetail(review.id),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'Sản phẩm đang đăng bán',
                        style: AppTypography.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              sellerProductsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: RmLoadingIndicator(),
                ),
                error: (_, _) => const SliverToBoxAdapter(
                  child: SizedBox.shrink(),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: RmEmptyState(
                        title: 'Chưa có sản phẩm đang bán',
                        subtitle:
                            'Người bán này hiện không có sản phẩm nào đang mở bán.',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = products[index];
                          return ProductCard(
                            product: product,
                            onTap: () => context.push(
                              RouteNames.productDetail(product.id),
                            ),
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.primaryDark,
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}
