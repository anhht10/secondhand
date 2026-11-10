import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_empty_state.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../categories/presentation/widgets/category_selector_bar.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../products/presentation/widgets/filter_sort_sheet.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../../../wishlist/presentation/providers/wishlist_providers.dart';

/// Home Discovery Feed (`05 - Home Feed`, `06 - Search & Results`, `08 - Offline Cached Mode`).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= maxScroll - 280) {
      ref.read(productFeedControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(productFeedControllerProvider.notifier).setSearchKeyword(value);
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(productFeedControllerProvider.notifier).setSearchKeyword('');
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(productFeedControllerProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final wishlistState = ref.watch(wishlistControllerProvider);
    final localPrefs = ref.watch(localPreferencesProvider);
    final hasLocalDraft =
        localPrefs?.readListingDraftJson()?.isNotEmpty ?? false;
    final cachedTimestamp = localPrefs?.readCachedProductsTimestamp();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ReMarket',
                    style: AppTypography.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Chợ đồ cũ minh bạch & AI thẩm định',
                    style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đơn mua & Đơn bán của tôi',
            onPressed: () => context.push(RouteNames.myOrdersPath),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Sản phẩm yêu thích',
            onPressed: () => context.push(RouteNames.wishlistPath),
            icon: Badge(
              isLabelVisible: wishlistState.wishlistIds.isNotEmpty,
              label: Text('${wishlistState.wishlistIds.length}'),
              child: const Icon(Icons.favorite_border_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Đăng tin bán mới',
            onPressed: () => context.go(RouteNames.createListingPath),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          await ref.read(productFeedControllerProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Top Search & Filter Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (val) {
                          _debounceTimer?.cancel();
                          ref
                              .read(productFeedControllerProvider.notifier)
                              .setSearchKeyword(val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Tìm iPhone, MacBook, bàn phím, xe đạp...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textMuted,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Badge(
                      isLabelVisible: feedState.query.hasActiveFilters,
                      backgroundColor: AppColors.primary,
                      child: Material(
                        color: feedState.query.hasActiveFilters
                            ? AppColors.primaryTintBg
                            : AppColors.surface,
                        borderRadius: AppSpacing.borderRadiusMd,
                        child: InkWell(
                          borderRadius: AppSpacing.borderRadiusMd,
                          onTap: () {
                            FilterSortSheet.show(
                              context: context,
                              initialQuery: feedState.query,
                              onApply: (updatedQuery) {
                                ref
                                    .read(
                                      productFeedControllerProvider.notifier,
                                    )
                                    .applyFilters(updatedQuery);
                              },
                            );
                          },
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              borderRadius: AppSpacing.borderRadiusMd,
                              border: Border.all(
                                color: feedState.query.hasActiveFilters
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: feedState.query.hasActiveFilters
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Offline Cached Mode Warning Banner (`08 - Offline Cached Mode`)
            if (feedState.isFromOfflineCache)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: AppSpacing.borderRadiusMd,
                      border: Border.all(color: AppColors.warningBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: AppColors.warningText,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chế độ ngoại tuyến — Đang xem dữ liệu đã lưu',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.warningText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (cachedTimestamp != null)
                                Text(
                                  'Cập nhật lần cuối: ${AppFormatters.formatRelativeDate(cachedTimestamp)}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.warningText,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(productFeedControllerProvider.notifier)
                                .refresh();
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 3. Saved Local Draft Banner (`F09`)
            if (hasLocalDraft)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Material(
                    color: AppColors.primaryTintBg,
                    borderRadius: AppSpacing.borderRadiusMd,
                    child: InkWell(
                      borderRadius: AppSpacing.borderRadiusMd,
                      onTap: () => context.go(RouteNames.createListingPath),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: AppSpacing.borderRadiusMd,
                          border: Border.all(color: AppColors.primaryTintBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Bạn có bản nháp tin đăng chưa hoàn tất. Nhấn để tiếp tục!',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 4. AI Shopping Assistant Banner (`AI 4`)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Material(
                  color: AppColors.primary,
                  borderRadius: AppSpacing.borderRadiusLg,
                  child: InkWell(
                    borderRadius: AppSpacing.borderRadiusLg,
                    onTap: () => context.push(RouteNames.aiChatPath),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: AppSpacing.borderRadiusMd,
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trợ lý Mua sắm Gemini AI',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tư vấn chọn đồ cũ hợp ngân sách & soi khuyết điểm tự động',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Category Horizontal Selector Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: categoriesAsync.when(
                  data: (categories) => CategorySelectorBar(
                    categories: categories,
                    selectedCategoryId: feedState.query.categoryId,
                    onCategorySelected: (categoryId) {
                      ref
                          .read(productFeedControllerProvider.notifier)
                          .selectCategory(categoryId);
                    },
                  ),
                  loading: () => const SizedBox(height: 44),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),

            // 6. Active Filters & Total Count Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        feedState.query.hasActiveFilters
                            ? 'Kết quả lọc (${feedState.meta?.total ?? feedState.items.length} sản phẩm)'
                            : 'Tin đăng mới nhất (${feedState.meta?.total ?? feedState.items.length})',
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (feedState.query.hasActiveFilters)
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(productFeedControllerProvider.notifier)
                              .clearFilters();
                        },
                        icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                        label: const Text('Bỏ lọc'),
                      ),
                  ],
                ),
              ),
            ),

            // 7. Product Grid / Loading Skeletons / Empty / Error States
            if (feedState.isLoading && feedState.items.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const ProductCardSkeleton(),
                    childCount: 6,
                  ),
                ),
              )
            else if (feedState.error != null && feedState.items.isEmpty)
              SliverToBoxAdapter(
                child: RmErrorState(
                  message: feedState.error!.message,
                  onRetry: () => ref
                      .read(productFeedControllerProvider.notifier)
                      .loadInitial(),
                ),
              )
            else if (feedState.items.isEmpty)
              SliverToBoxAdapter(
                child: RmEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Không tìm thấy sản phẩm phù hợp',
                  subtitle: feedState.query.hasActiveFilters
                      ? 'Hãy thử mở rộng khoảng giá hoặc xóa bớt bộ lọc hiện tại.'
                      : 'Chưa có sản phẩm nào trên sàn. Hãy là người đầu tiên đăng bán!',
                  actionLabel: feedState.query.hasActiveFilters
                      ? 'Xóa tất cả bộ lọc'
                      : 'Đăng bán ngay',
                  onAction: () {
                    if (feedState.query.hasActiveFilters) {
                      _searchController.clear();
                      ref
                          .read(productFeedControllerProvider.notifier)
                          .clearFilters();
                    } else {
                      context.go(RouteNames.createListingPath);
                    }
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = feedState.items[index];
                      return ProductCard(
                        product: product,
                        onTap: () => context.push(
                          RouteNames.productDetail(product.id),
                        ),
                      );
                    },
                    childCount: feedState.items.length,
                  ),
                ),
              ),

            // 8. Infinite Scroll Loading Footer
            if (feedState.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
