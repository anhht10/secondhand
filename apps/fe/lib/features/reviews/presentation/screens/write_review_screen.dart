import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../../data/models/review_models.dart';
import '../providers/review_providers.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({
    super.key,
    required this.orderId,
    this.initialReview,
  });

  final String orderId;
  final ReviewModel? initialReview;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _imagePicker = ImagePicker();

  int _selectedRating = 5;
  ReviewModel? _editingReview;
  bool _initializedFromExisting = false;

  static const Map<int, String> _ratingLabels = <int, String>{
    1: '1 sao — Rất không hài lòng',
    2: '2 sao — Không hài lòng',
    3: '3 sao — Bình thường',
    4: '4 sao — Hài lòng',
    5: '5 sao — Rất hài lòng, uy tín!',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialReview != null) {
      _applyExistingReview(widget.initialReview!);
    }
  }

  void _applyExistingReview(ReviewModel review) {
    if (_initializedFromExisting) return;
    _initializedFromExisting = true;
    _editingReview = review;
    _selectedRating = review.rating.clamp(1, 5);
    _commentController.text = review.comment;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(reviewSubmissionProvider.notifier)
          .setInitialImages(review.images);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages() async {
    final currentImages = ref.read(reviewSubmissionProvider).uploadedImageUrls;
    if (currentImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mỗi đánh giá chỉ được đính kèm tối đa 5 ảnh thực tế.'),
        ),
      );
      return;
    }

    try {
      final picked = await _imagePicker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;

      final remainingSlots = 5 - currentImages.length;
      final selectedFiles = <UploadableImageFile>[];
      for (final xfile in picked.take(remainingSlots)) {
        final bytes = await xfile.readAsBytes();
        final ext = xfile.name.split('.').last.toLowerCase();
        final mimeType = switch (ext) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
        selectedFiles.add(
          UploadableImageFile(
            bytes: bytes,
            fileName: xfile.name,
            mimeType: mimeType,
          ),
        );
      }

      await ref
          .read(reviewSubmissionProvider.notifier)
          .uploadSelectedImages(selectedFiles);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(reviewSubmissionProvider.notifier);
    final comment = _commentController.text.trim();

    ReviewModel? result;
    if (_editingReview != null) {
      result = await notifier.updateExistingReview(
        reviewId: _editingReview!.id,
        rating: _selectedRating,
        comment: comment,
      );
    } else {
      result = await notifier.submitReview(
        orderId: widget.orderId,
        rating: _selectedRating,
        comment: comment,
      );
    }

    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingReview != null
                ? 'Đã cập nhật đánh giá thành công!'
                : 'Cảm ơn bạn đã gửi đánh giá cho người bán!',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      }
    } else {
      final err = ref.read(reviewSubmissionProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.message),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final existingReviewAsync = ref.watch(orderReviewProvider(widget.orderId));
    final submissionState = ref.watch(reviewSubmissionProvider);

    existingReviewAsync.whenData((rev) {
      if (rev != null && !_initializedFromExisting) {
        _applyExistingReview(rev);
      }
    });

    final isEditing = _editingReview != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Chỉnh sửa đánh giá' : 'Đánh giá người bán',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            orderAsync.when(
              data: (order) => _buildOrderSummaryCard(order),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            _buildStarSelectorCard(),
            const SizedBox(height: 16),
            _buildCommentSection(),
            const SizedBox(height: 16),
            _buildImagesSection(submissionState),
            if (submissionState.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  submissionState.error!.message,
                  style: const TextStyle(
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                key: const Key('submit_review_button'),
                onPressed: (submissionState.isSubmitting ||
                        submissionState.isUploadingImages)
                    ? null
                    : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: submissionState.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rate_review_outlined),
                label: Text(
                  isEditing ? 'Lưu thay đổi đánh giá' : 'Gửi đánh giá',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.backgroundLight,
              child: order.productSnapshot.imageUrl != null &&
                      order.productSnapshot.imageUrl!.isNotEmpty
                  ? Image.network(
                      order.productSnapshot.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textMuted,
                      ),
                    )
                  : const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.textMuted,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.productSnapshot.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Người bán: ${order.seller?.displayName ?? 'Người bán ReMarket'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatters.formatVnd(order.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Mức độ hài lòng của bạn với người bán',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = starValue <= _selectedRating;
              return IconButton(
                key: Key('review_star_$starValue'),
                onPressed: () {
                  setState(() {
                    _selectedRating = starValue;
                  });
                },
                iconSize: 38,
                icon: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : AppColors.textMuted,
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            _ratingLabels[_selectedRating] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Nhận xét chi tiết *',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('review_comment_input'),
            controller: _commentController,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText:
                  'Chia sẻ trải nghiệm thực tế của bạn: Tình trạng sản phẩm so với mô tả, thái độ người bán, đóng gói và thời gian giao hàng...',
              filled: true,
              fillColor: AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
            ),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return 'Vui lòng nhập nội dung đánh giá';
              }
              if (trimmed.length < 10) {
                return 'Nội dung đánh giá cần tối thiểu 10 ký tự';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection(ReviewSubmissionState submissionState) {
    final images = submissionState.uploadedImageUrls;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Hình ảnh thực tế sau khi nhận hàng (tối đa 5 ảnh)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${images.length}/5',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (int i = 0; i < images.length; i++)
                Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 78,
                        height: 78,
                        color: AppColors.backgroundLight,
                        child: Image.network(
                          images[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.image_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        key: Key('remove_review_image_$i'),
                        onTap: () {
                          ref
                              .read(reviewSubmissionProvider.notifier)
                              .removeImageAt(i);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (images.length < 5)
                InkWell(
                  key: const Key('add_review_image_button'),
                  onTap: submissionState.isUploadingImages
                      ? null
                      : _pickAndUploadImages,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: submissionState.isUploadingImages
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.primaryGreen,
                                size: 22,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Thêm ảnh',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
