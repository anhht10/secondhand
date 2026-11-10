import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_empty_state.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_providers.dart';

/// My Listings & Drafts Screen (`19 - My Listings & Drafts` — `GET /api/v1/products/me/listings`).
class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  ProductStatus? _selectedStatus;
  List<ProductModel> _listings = const <ProductModel>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadMyListings);
  }

  Future<void> _loadMyListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(productRepositoryProvider).getMyListings(
          status: _selectedStatus,
          limit: 50,
        );
    if (!mounted) return;

    result.when(
      success: (items, _, _) {
        setState(() {
          _listings = items;
          _isLoading = false;
        });
      },
      failure: (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message;
        });
      },
    );
  }

  Future<void> _changeListingStatus(
    ProductModel product,
    ProductStatus targetStatus,
  ) async {
    final result =
        await ref.read(productRepositoryProvider).updateProductStatus(
              productId: product.id,
              status: targetStatus,
            );
    if (!mounted) return;

    result.when(
      success: (updated, _, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã chuyển trạng thái sang "${targetStatus.labelVi}"!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(productFeedControllerProvider.notifier).refresh();
        _loadMyListings();
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  Future<void> _confirmAndDelete(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tin đăng'),
        content: Text(
          'Bạn có chắc chắn muốn xóa tin đăng "${product.title}"? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa tin'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result =
        await ref.read(productRepositoryProvider).deleteProduct(product.id);
    if (!mounted) return;

    result.when(
      success: (_, _, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tin đăng thành công.'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(productFeedControllerProvider.notifier).refresh();
        _loadMyListings();
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý tin đăng của tôi'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(RouteNames.sellerOrdersPath),
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('Đơn bán hàng'),
          ),
          IconButton(
            tooltip: 'Đăng tin mới',
            onPressed: () => context.go(RouteNames.createListingPath),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loadMyListings,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Filter Chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _selectedStatus == null,
                    onSelected: (_) {
                      setState(() => _selectedStatus = null);
                      _loadMyListings();
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  for (final status in ProductStatus.values) ...[
                    ChoiceChip(
                      label: Text(status.labelVi),
                      selected: _selectedStatus == status,
                      onSelected: (_) {
                        setState(() => _selectedStatus = status);
                        _loadMyListings();
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadMyListings,
              child: _isLoading
                  ? const RmLoadingIndicator(
                      message: 'Đang tải danh sách tin đăng...',
                    )
                  : _errorMessage != null
                      ? RmErrorState(
                          message: _errorMessage!,
                          onRetry: _loadMyListings,
                        )
                      : _listings.isEmpty
                          ? RmEmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'Chưa có tin đăng nào',
                              subtitle:
                                  'Tạo tin đăng bán đồ cũ nhanh chóng với công cụ AI tạo mô tả và gợi ý giá.',
                              actionLabel: 'Đăng bán ngay',
                              onAction: () =>
                                  context.go(RouteNames.createListingPath),
                            )
                          : ListView.separated(
                              padding: AppSpacing.screenPadding,
                              itemCount: _listings.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final item = _listings[index];
                                final imgUrl = config
                                    .resolveMediaUrl(item.primaryImageUrl);
                                final transitions =
                                    item.status.allowedTransitions;

                                return RmCard(
                                  onTap: () => context.push(
                                    RouteNames.productDetail(item.id),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                AppSpacing.borderRadiusMd,
                                            child: Container(
                                              width: 76,
                                              height: 76,
                                              color: AppColors.surfaceVariant,
                                              child: imgUrl.isNotEmpty
                                                  ? Image.network(
                                                      imgUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, _, _) =>
                                                              const Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      color:
                                                          AppColors.textMuted,
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
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: item.status ==
                                                                ProductStatus
                                                                    .active
                                                            ? AppColors
                                                                .successBg
                                                            : item.status ==
                                                                    ProductStatus
                                                                        .sold
                                                                ? AppColors
                                                                    .errorBg
                                                                : AppColors
                                                                    .warningBg,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          AppSpacing.radiusPill,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        item.status.labelVi,
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: item.status ==
                                                                  ProductStatus
                                                                      .active
                                                              ? AppColors
                                                                  .successText
                                                              : item.status ==
                                                                      ProductStatus
                                                                          .sold
                                                                  ? AppColors
                                                                      .errorText
                                                                  : AppColors
                                                                      .warningText,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '• ${item.viewsCount} lượt xem',
                                                      style: AppTypography
                                                          .bodySmall,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      AppTypography.titleMedium,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  AppFormatters.formatVnd(
                                                    item.price,
                                                  ),
                                                  style:
                                                      AppTypography.priceText,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: AppSpacing.lg),
                                      Wrap(
                                        spacing: AppSpacing.sm,
                                        runSpacing: AppSpacing.xs,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          for (final nextStatus in transitions)
                                            ActionChip(
                                              avatar: const Icon(
                                                Icons.swap_horiz_rounded,
                                                size: 15,
                                                color: AppColors.primary,
                                              ),
                                              label: Text(
                                                'Chuyển: ${nextStatus.labelVi}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _changeListingStatus(
                                                item,
                                                nextStatus,
                                              ),
                                            ),
                                          if (item.status.canEditAndDelete) ...[
                                            TextButton.icon(
                                              onPressed: () => context.push(
                                                RouteNames.editListing(item.id),
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 16,
                                              ),
                                              label: const Text('Sửa'),
                                            ),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _confirmAndDelete(item),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: AppColors.error,
                                              ),
                                              label: const Text(
                                                'Xóa',
                                                style: TextStyle(
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ),
                                          ] else
                                            Text(
                                              'Tin đã bán (Không thể sửa/xóa)',
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
