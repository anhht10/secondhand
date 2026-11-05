import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../providers/review_providers.dart';
import 'seller_reviews_screen.dart';

class ReviewDetailScreen extends ConsumerWidget {
  const ReviewDetailScreen({
    super.key,
    required this.reviewId,
  });

  final String reviewId;

  Future<void> _showReportDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final reasonController = TextEditingController();
    final descController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Báo cáo đánh giá vi phạm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do báo cáo *',
                  hintText: 'Ví dụ: Ngôn từ xúc phạm, tiết lộ SĐT cá nhân...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả chi tiết (tùy chọn)',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.length < 3) return;
                Navigator.of(dialogContext).pop();
                final res = await ref
                    .read(reviewRepositoryProvider)
                    .reportReview(
                      reviewId: reviewId,
                      reason: reason,
                      description: descController.text.trim(),
                    );
                if (!context.mounted) return;
                res.when(
                  success: (data, _, _) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          (data['message'] ?? 'Đã ghi nhận báo cáo').toString(),
                        ),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  failure: (err) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err.message),
                        backgroundColor: AppColors.errorRed,
                      ),
                    );
                  },
                );
              },
              child: const Text('Gửi báo cáo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(reviewDetailProvider(reviewId));
    final currentUserId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Chi tiết đánh giá',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Báo cáo đánh giá',
            onPressed: () => _showReportDialog(context, ref),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Không thể tải đánh giá: $err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (review) {
          final isBuyer = currentUserId != null && currentUserId == review.buyerId;
          final isSeller =
              currentUserId != null && currentUserId == review.sellerId;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              ReviewItemCard(
                review: review,
                canSellerReply: isSeller && review.canSellerReply,
                onReplySubmitted: (replyText) async {
                  final res = await ref
                      .read(reviewRepositoryProvider)
                      .replyToReview(reviewId: review.id, reply: replyText);
                  res.when(
                    success: (_, _, _) {
                      ref.invalidate(reviewDetailProvider(review.id));
                      ref.invalidate(sellerReputationProvider(review.sellerId));
                      ref.invalidate(
                        sellerReviewsNotifierProvider(review.sellerId),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Đã gửi phản hồi đánh giá thành công!'),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      }
                    },
                    failure: (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err.message),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              if (isBuyer && review.canBuyerEdit)
                FilledButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.writeReviewPath.replaceFirst(
                      ':orderId',
                      review.orderId,
                    ),
                    extra: review,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(
                    'Chỉnh sửa đánh giá (trong 7 ngày đầu)',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
