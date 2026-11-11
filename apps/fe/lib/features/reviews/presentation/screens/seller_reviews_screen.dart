import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/review_models.dart';
import '../providers/review_providers.dart';

class SellerReviewsScreen extends ConsumerWidget {
  const SellerReviewsScreen({
    super.key,
    required this.sellerId,
    this.sellerName,
  });

  final String sellerId;
  final String? sellerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsState = ref.watch(sellerReviewsNotifierProvider(sellerId));
    final reputationAsync = ref.watch(sellerReputationProvider(sellerId));
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    final isOwnSellerProfile =
        currentUserId != null && currentUserId == sellerId;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          sellerName != null && sellerName!.trim().isNotEmpty
              ? 'Đánh giá — $sellerName'
              : 'Đánh giá & Uy tín người bán',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sellerReputationProvider(sellerId));
          await ref
              .read(sellerReviewsNotifierProvider(sellerId).notifier)
              .loadReviews(page: 1);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            reputationAsync.when(
              data: (reputation) => SellerReputationOverviewCard(
                reputation: reputation,
              ),
              loading: () => SellerReputationOverviewCard(
                reputation: SellerReputationModel(
                  sellerId: sellerId,
                  averageRating: reviewsState.ratingSummary.averageRating,
                  ratingSummary: reviewsState.ratingSummary,
                ),
              ),
              error: (_, _) => SellerReputationOverviewCard(
                reputation: SellerReputationModel(
                  sellerId: sellerId,
                  averageRating: reviewsState.ratingSummary.averageRating,
                  ratingSummary: reviewsState.ratingSummary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFilterAndSortBar(context, ref, reviewsState),
            const SizedBox(height: 12),
            if (reviewsState.isLoading && reviewsState.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reviewsState.items.isEmpty)
              _buildEmptyState(reviewsState.selectedRating)
            else ...<Widget>[
              for (final review in reviewsState.items) ...<Widget>[
                ReviewItemCard(
                  review: review,
                  canSellerReply: isOwnSellerProfile && !review.hasSellerReply,
                  onTap: () => context.push(
                    AppRoutes.reviewDetailPath.replaceFirst(
                      ':reviewId',
                      review.id,
                    ),
                  ),
                  onReplySubmitted: (replyText) async {
                    final updated = await ref
                        .read(sellerReviewsNotifierProvider(sellerId).notifier)
                        .replyToReview(
                          reviewId: review.id,
                          reply: replyText,
                        );
                    if (context.mounted && updated != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã gửi phản hồi đánh giá thành công!'),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (reviewsState.hasNextPage)
                Center(
                  child: OutlinedButton(
                    onPressed: reviewsState.isLoading
                        ? null
                        : () => ref
                            .read(
                              sellerReviewsNotifierProvider(sellerId).notifier,
                            )
                            .loadMore(),
                    child: const Text('Xem thêm đánh giá'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSortBar(
    BuildContext context,
    WidgetRef ref,
    SellerReviewsListState state,
  ) {
    final notifier = ref.read(sellerReviewsNotifierProvider(sellerId).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              FilterChip(
                key: const Key('filter_star_all'),
                label: Text('Tất cả (${state.ratingSummary.totalReviews})'),
                selected: state.selectedRating == null,
                onSelected: (_) => notifier.filterByRating(null),
              ),
              const SizedBox(width: 8),
              for (int star = 5; star >= 1; star--) ...<Widget>[
                FilterChip(
                  key: Key('filter_star_$star'),
                  label: Text(
                    '$star sao (${state.ratingSummary.countForStar(star)})',
                  ),
                  selected: state.selectedRating == star,
                  onSelected: (_) => notifier.filterByRating(star),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Danh sách đánh giá (${state.items.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            DropdownButton<ReviewSortOption>(
              value: state.sort,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
              items: ReviewSortOption.values
                  .map(
                    (opt) => DropdownMenuItem<ReviewSortOption>(
                      value: opt,
                      child: Text(opt.labelVi),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) notifier.changeSort(val);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(int? selectedRating) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.reviews_outlined,
            size: 42,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            selectedRating != null
                ? 'Chưa có đánh giá $selectedRating sao nào'
                : 'Người bán này chưa có đánh giá nào từ giao dịch hoàn tất',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerReputationOverviewCard extends StatelessWidget {
  const SellerReputationOverviewCard({
    super.key,
    required this.reputation,
    this.onViewAllReviews,
  });

  final SellerReputationModel reputation;
  final VoidCallback? onViewAllReviews;

  @override
  Widget build(BuildContext context) {
    final summary = reputation.ratingSummary;
    final txStats = reputation.transactionStats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Điểm uy tín: ${reputation.reputationScore}/100',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reputation.tierLabelVi,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (onViewAllReviews != null)
                TextButton(
                  onPressed: onViewAllReviews,
                  child: const Text('Xem tất cả'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                children: <Widget>[
                  Text(
                    summary.totalReviews > 0
                        ? summary.averageRating.toStringAsFixed(1)
                        : 'Chưa có',
                    style: TextStyle(
                      fontSize: summary.totalReviews > 0 ? 32 : 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(5, (i) {
                      final filled = i < summary.averageRating.round();
                      return Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: const Color(0xFFF59E0B),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.totalReviews} đánh giá',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: <Widget>[
                    for (int star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 34,
                              child: Text(
                                '$star ★',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  value: summary.ratioForStar(star),
                                  backgroundColor: AppColors.backgroundLight,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${summary.countForStar(star)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildStatItem(
                label: 'Giao dịch thành công',
                value: '${txStats.completedOrdersCount}',
              ),
              _buildStatItem(
                label: 'Tỷ lệ hoàn tất',
                value: '${txStats.successfulTransactionRate.toStringAsFixed(0)}%',
              ),
              _buildStatItem(
                label: 'Phản hồi đánh giá',
                value: '${txStats.sellerReplyRate.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class ReviewItemCard extends StatelessWidget {
  const ReviewItemCard({
    super.key,
    required this.review,
    this.canSellerReply = false,
    this.onTap,
    this.onReplySubmitted,
  });

  final ReviewModel review;
  final bool canSellerReply;
  final VoidCallback? onTap;
  final ValueChanged<String>? onReplySubmitted;

  void _showReplyDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Phản hồi đánh giá của người mua'),
          content: TextField(
            key: const Key('seller_reply_input'),
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Nhập lời cảm ơn hoặc phản hồi lịch sự của bạn...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const Key('submit_seller_reply_button'),
              onPressed: () {
                final text = controller.text.trim();
                if (text.length < 2) return;
                Navigator.of(dialogContext).pop();
                onReplySubmitted?.call(text);
              },
              child: const Text('Gửi phản hồi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyerName = review.buyer?.displayName ?? 'Người mua đã xác thực';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 17,
                  backgroundColor:
                      AppColors.primaryGreen.withValues(alpha: 0.14),
                  child: Text(
                    buyerName.isNotEmpty ? buyerName[0].toUpperCase() : 'B',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        buyerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          for (int i = 1; i <= 5; i++)
                            Icon(
                              i <= review.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: const Color(0xFFF59E0B),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            AppFormatters.formatRelativeDate(review.createdAt),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Đã mua hàng',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            if (review.product != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Sản phẩm: ${review.product!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
            if (review.images.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 68,
                        height: 68,
                        color: AppColors.backgroundLight,
                        child: Image.network(
                          review.images[idx],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.image_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (review.hasSellerReply) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Phản hồi của người bán:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.sellerReply!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (canSellerReply && onReplySubmitted != null) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('reply_review_btn_${review.id}'),
                  onPressed: () => _showReplyDialog(context),
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: const Text('Phản hồi người mua'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
