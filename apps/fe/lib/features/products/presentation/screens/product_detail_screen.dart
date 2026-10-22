import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../ai/presentation/providers/ai_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../messages/presentation/providers/messages_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../wishlist/presentation/providers/wishlist_providers.dart';
import '../../data/models/product_model.dart';
import '../providers/product_providers.dart';
import '../widgets/product_card.dart';

/// Product Detail Screen (`09 - Product Detail` & `10 - AI Buyer Checklist`).
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _currentImageIndex = 0;
  bool _showAiChecklist = false;
  bool _isOpeningChat = false;
  Set<int> _checkedChecklistIndices = <int>{};
  bool _loadedChecklistPrefs = false;

  void _ensureChecklistPrefsLoaded() {
    if (_loadedChecklistPrefs) return;
    _loadedChecklistPrefs = true;
    final prefs = ref.read(localPreferencesProvider);
    if (prefs != null) {
      _checkedChecklistIndices =
          prefs.readCheckedChecklistIndices(widget.productId);
    }
  }

  Future<void> _toggleChecklistIndex(int index) async {
    setState(() {
      if (_checkedChecklistIndices.contains(index)) {
        _checkedChecklistIndices.remove(index);
      } else {
        _checkedChecklistIndices.add(index);
      }
    });
    final prefs = ref.read(localPreferencesProvider);
    await prefs?.saveCheckedChecklistIndices(
      widget.productId,
      _checkedChecklistIndices,
    );
  }

  Future<void> _startConversationWithSeller({String? initialMessage}) async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);

    final result = await ref
        .read(messagesRepositoryProvider)
        .createOrGetConversation(
          productId: widget.productId,
          initialMessage: initialMessage,
        );

    if (!mounted) return;
    setState(() => _isOpeningChat = false);

    result.when(
      success: (conversation, _, _) {
        ref.read(conversationsControllerProvider.notifier).loadConversations();
        context.push(RouteNames.chatDetail(conversation.id));
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
    _ensureChecklistPrefsLoaded();
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final activeOrderAsync =
        ref.watch(productOrderSummaryProvider(widget.productId));
    final activeOrder = activeOrderAsync.valueOrNull;
    final currentUser = ref.watch(authControllerProvider).user;
    final wishlistState = ref.watch(wishlistControllerProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: [
          productAsync.maybeWhen(
            data: (product) {
              final isWishlisted = wishlistState.contains(product.id);
              return IconButton(
                tooltip: isWishlisted ? 'Bỏ yêu thích' : 'Lưu yêu thích',
                onPressed: () {
                  ref
                      .read(wishlistControllerProvider.notifier)
                      .toggleWishlist(product);
                },
                icon: Icon(
                  isWishlisted
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isWishlisted ? AppColors.error : AppColors.textPrimary,
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () =>
                ref.invalidate(productDetailProvider(widget.productId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: productAsync.when(
        loading: () => const RmLoadingIndicator(
          message: 'Đang tải thông tin sản phẩm...',
        ),
        error: (err, _) => RmErrorState(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () =>
              ref.invalidate(productDetailProvider(widget.productId)),
        ),
        data: (product) {
          final isOwner =
              currentUser != null && currentUser.id == product.sellerId;
          final images = product.images
              .map(config.resolveMediaUrl)
              .where((u) => u.isNotEmpty)
              .toList(growable: false);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Image Gallery Carousel
                      SizedBox(
                        height: 290,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (images.isNotEmpty)
                              PageView.builder(
                                itemCount: images.length,
                                onPageChanged: (index) => setState(
                                  () => _currentImageIndex = index,
                                ),
                                itemBuilder: (context, index) {
                                  return Container(
                                    color: AppColors.surfaceVariant,
                                    child: Image.network(
                                      images[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                color: AppColors.surfaceVariant,
                                child: const Center(
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    size: 56,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            if (images.length > 1)
                              Positioned(
                                bottom: AppSpacing.md,
                                right: AppSpacing.md,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    '${_currentImageIndex + 1}/${images.length}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: AppSpacing.screenPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 2. Condition, Status & Category Badges
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                _InfoPill(
                                  icon: Icons.verified_outlined,
                                  label: product.condition.labelVi,
                                  backgroundColor: AppColors.primaryTintBg,
                                  textColor: AppColors.primaryDark,
                                ),
                                _InfoPill(
                                  icon: Icons.circle,
                                  label: product.status.labelVi,
                                  backgroundColor:
                                      product.status == ProductStatus.active
                                          ? AppColors.successBg
                                          : AppColors.warningBg,
                                  textColor:
                                      product.status == ProductStatus.active
                                          ? AppColors.successText
                                          : AppColors.warningText,
                                ),
                                if (product.category.name.isNotEmpty)
                                  _InfoPill(
                                    icon: Icons.category_outlined,
                                    label: product.category.name,
                                    backgroundColor: AppColors.surfaceVariant,
                                    textColor: AppColors.textSecondary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // 3. Title & Price
                            Text(
                              product.title,
                              style: AppTypography.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.sm,
                              children: [
                                Text(
                                  AppFormatters.formatVnd(product.price),
                                  style: AppTypography.headlineLarge.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (product.originalPrice != null &&
                                    product.originalPrice! > product.price)
                                  Text(
                                    AppFormatters.formatVnd(
                                      product.originalPrice!,
                                    ),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textMuted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                if (product.discountPercentage != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.successBg,
                                      borderRadius: AppSpacing.borderRadiusSm,
                                      border: Border.all(
                                        color: AppColors.successBorder,
                                      ),
                                    ),
                                    child: Text(
                                      'Tiết kiệm ${product.discountPercentage}%',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.successText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            // Meta row: Location, Views, CreatedAt
                            Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.location?.trim().isNotEmpty ==
                                              true
                                          ? product.location!
                                          : 'Toàn quốc',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.visibility_outlined,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${product.viewsCount} lượt xem',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppFormatters.formatRelativeDate(
                                        product.createdAt,
                                      ),
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // 4. Mandatory Defect Disclosure Card (ReMarket Transparency)
                            RmCard(
                              backgroundColor: AppColors.primaryTintBg,
                              borderColor: AppColors.primaryTintBorderStrong,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_user_rounded,
                                        color: AppColors.primaryDark,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          'Công khai Tình trạng & Khuyết điểm',
                                          style:
                                              AppTypography.titleMedium.copyWith(
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    product.hasDefectDisclosure
                                        ? product.defects
                                        : 'Người bán cam kết sản phẩm không có lỗi hoặc trầy xước đáng kể.',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (product.aiMetadata?.priceReasoning !=
                                          null &&
                                      product.aiMetadata!.priceReasoning!
                                          .trim()
                                          .isNotEmpty) ...[
                                    const Divider(height: AppSpacing.lg),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome_outlined,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Nhận định giá AI: ${product.aiMetadata!.priceReasoning}',
                                            style:
                                                AppTypography.bodySmall.copyWith(
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // 5. AI 3 — Buyer Inspection Checklist (`10 - AI Buyer Checklist`)
                            _AiBuyerChecklistSection(
                              product: product,
                              isExpanded: _showAiChecklist,
                              checkedIndices: _checkedChecklistIndices,
                              onToggleExpand: () {
                                setState(
                                  () => _showAiChecklist = !_showAiChecklist,
                                );
                              },
                              onToggleCheckItem: _toggleChecklistIndex,
                              onAskSellerQuestion: (question) {
                                _startConversationWithSeller(
                                  initialMessage: question,
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // 6. Seller Info Card (with Rating, Reviews & Reputation)
                            RmCard(
                              onTap: product.sellerId.isNotEmpty
                                  ? () => context.push(
                                        RouteNames.sellerProfile(
                                          product.sellerId,
                                        ),
                                      )
                                  : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor:
                                            AppColors.primaryTintBg,
                                        child: Text(
                                          product.seller.initials,
                                          style:
                                              AppTypography.titleLarge.copyWith(
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
                                                    product.seller.displayName,
                                                    style: AppTypography
                                                        .titleMedium,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.verified_rounded,
                                                  size: 16,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              product.seller.location ??
                                                  product.location ??
                                                  'Đã xác thực email',
                                              style: AppTypography.bodySmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.star_rounded,
                                                      size: 15,
                                                      color: Color(0xFFF59E0B),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      product.seller
                                                                  .totalReviews >
                                                              0
                                                          ? '${product.seller.averageRating.toStringAsFixed(1)} (${product.seller.totalReviews} đánh giá)'
                                                          : 'Chưa có đánh giá',
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '• ${product.seller.completedOrdersCount} giao dịch thành công',
                                                  style:
                                                      AppTypography.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Text(
                                        'Xem hồ sơ',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                  if (product.sellerId.isNotEmpty) ...[
                                    const Divider(height: 18),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.verified_user_outlined,
                                              size: 15,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Điểm uy tín: ${product.seller.trustScore}/100',
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        InkWell(
                                          key: const Key(
                                            'product_detail_view_seller_reviews',
                                          ),
                                          onTap: () => context.push(
                                            RouteNames.sellerReviews(
                                              product.sellerId,
                                            ),
                                            extra: product.seller.displayName,
                                          ),
                                          child: const Text(
                                            'Xem tất cả đánh giá →',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // 7. Detailed Description & Tags
                            RmCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mô tả chi tiết',
                                    style: AppTypography.titleMedium,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    product.description,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (product.tags.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        for (final tag in product.tags)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppSpacing.radiusPill,
                                              ),
                                            ),
                                            child: Text(
                                              '#$tag',
                                              style: AppTypography.bodySmall,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // 8. Safety Report Button (Hidden if owner)
                            if (!isOwner)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    context.push(
                                      RouteNames.reportProduct(product.id),
                                      extra: product.title,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.flag_outlined,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  label: const Text(
                                    'Báo cáo tin đăng vi phạm / gian lận',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),

                            // 9. Related Products Section
                            _RelatedProductsSection(product: product),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 10. Sticky Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: isOwner
                      ? Row(
                          children: [
                            if (activeOrder != null) ...[
                              Expanded(
                                child: RmButton(
                                  label:
                                      'Xem đơn (${activeOrder.status.labelVi})',
                                  icon: Icons.receipt_long_outlined,
                                  onPressed: () {
                                    context.push(
                                      RouteNames.orderDetail(activeOrder.id),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ] else if (product.status.canEditAndDelete) ...[
                              Expanded(
                                child: RmButton(
                                  label: 'Chỉnh sửa tin',
                                  icon: Icons.edit_outlined,
                                  variant: RmButtonVariant.secondary,
                                  onPressed: () {
                                    context.push(
                                      RouteNames.editListing(product.id),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            Expanded(
                              child: RmButton(
                                label: 'Quản lý tin đăng',
                                icon: Icons.inventory_rounded,
                                variant: activeOrder != null
                                    ? RmButtonVariant.secondary
                                    : RmButtonVariant.primary,
                                onPressed: () {
                                  context.push(RouteNames.myListingsPath);
                                },
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  tooltip: 'Hỏi thêm AI về sản phẩm này',
                                  onPressed: () {
                                    ref
                                        .read(aiChatControllerProvider.notifier)
                                        .askAboutProduct(product);
                                    context.push(RouteNames.aiChatPath);
                                  },
                                  icon: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: RmButton(
                                    label: 'Nhắn tin người bán',
                                    icon: Icons.chat_bubble_outline_rounded,
                                    variant: RmButtonVariant.secondary,
                                    isLoading: _isOpeningChat,
                                    onPressed:
                                        product.status == ProductStatus.sold
                                            ? null
                                            : () =>
                                                _startConversationWithSeller(),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: RmButton(
                                    key: const Key('buy_now_button'),
                                    label: activeOrder != null
                                        ? 'Xem đơn hàng'
                                        : product.status == ProductStatus.active
                                            ? 'Mua ngay'
                                            : product.status.labelVi,
                                    icon: activeOrder != null
                                        ? Icons.receipt_long_outlined
                                        : Icons.shopping_bag_outlined,
                                    onPressed: activeOrder != null
                                        ? () => context.push(
                                              RouteNames.orderDetail(
                                                activeOrder.id,
                                              ),
                                            )
                                        : product.status == ProductStatus.active
                                            ? () => context.push(
                                                  RouteNames.checkout(
                                                    product.id,
                                                  ),
                                                )
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 3 — Buyer Inspection Checklist Card (`POST /api/v1/ai/buyer-checklist`).
class _AiBuyerChecklistSection extends ConsumerWidget {
  const _AiBuyerChecklistSection({
    required this.product,
    required this.isExpanded,
    required this.checkedIndices,
    required this.onToggleExpand,
    required this.onToggleCheckItem,
    required this.onAskSellerQuestion,
  });

  final ProductModel product;
  final bool isExpanded;
  final Set<int> checkedIndices;
  final VoidCallback onToggleExpand;
  final ValueChanged<int> onToggleCheckItem;
  final ValueChanged<String> onAskSellerQuestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RmCard(
      backgroundColor: AppColors.surface,
      borderColor: AppColors.primaryTintBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTintBg,
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cẩm nang Kiểm tra Hàng cũ bằng AI',
                      style: AppTypography.titleMedium,
                    ),
                    Text(
                      'Tự động sinh danh sách mục cần test dựa trên tình trạng máy',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onToggleExpand,
                child: Text(isExpanded ? 'Thu gọn' : 'Mở checklist'),
              ),
            ],
          ),
          if (isExpanded) ...[
            const Divider(height: AppSpacing.lg),
            ref.watch(buyerChecklistProvider(product.id)).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: RmLoadingIndicator(
                      message:
                          'Gemini AI đang phân tích sản phẩm & khuyết điểm...',
                    ),
                  ),
                  error: (err, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        err.toString().replaceFirst('Exception: ', ''),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.errorText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      RmButton(
                        label: 'Thử tạo lại Checklist',
                        variant: RmButtonVariant.secondary,
                        fullWidth: false,
                        onPressed: () => ref.invalidate(
                          buyerChecklistProvider(product.id),
                        ),
                      ),
                    ],
                  ),
                  data: (checklistData) {
                    final total = checklistData.checklist.length;
                    final checkedCount = checkedIndices
                        .where((idx) => idx >= 0 && idx < total)
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Các bước kiểm tra khi nhận hàng ($checkedCount/$total)',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (checklistData.recommendedExpandedView)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warningBg,
                                  borderRadius: AppSpacing.borderRadiusSm,
                                ),
                                child: Text(
                                  'Cần kiểm tra kỹ',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.warningText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (int i = 0;
                            i < checklistData.checklist.length;
                            i++)
                          Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              value: checkedIndices.contains(i),
                              onChanged: (_) => onToggleCheckItem(i),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.primary,
                              title: Text(
                                checklistData.checklist[i],
                                style: AppTypography.bodyMedium.copyWith(
                                  color: checkedIndices.contains(i)
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                  decoration: checkedIndices.contains(i)
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        if (checklistData.riskNotes.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm + 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: AppSpacing.borderRadiusMd,
                              border: Border.all(
                                color: AppColors.warningBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '⚠️ Lưu ý rủi ro cần lưu tâm:',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.warningText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (final note in checklistData.riskNotes)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      '• $note',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.warningText,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (checklistData.questionsForSeller.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Gợi ý câu hỏi nhanh gửi người bán (Nhấn để gửi):',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final question
                                  in checklistData.questionsForSeller)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.send_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  backgroundColor: AppColors.primaryTintBg,
                                  label: Text(
                                    question,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  onPressed: () =>
                                      onAskSellerQuestion(question),
                                ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
          ],
        ],
      ),
    );
  }
}

class _RelatedProductsSection extends ConsumerWidget {
  const _RelatedProductsSection({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedAsync = ref.watch(
      relatedProductsProvider(
        (productId: product.id, categoryId: product.category.id),
      ),
    );

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (related) {
        if (related.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sản phẩm tương tự cùng danh mục',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 255,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: related.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final item = related[index];
                  return SizedBox(
                    width: 175,
                    child: ProductCard(
                      product: item,
                      onTap: () => context.push(
                        RouteNames.productDetail(item.id),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
