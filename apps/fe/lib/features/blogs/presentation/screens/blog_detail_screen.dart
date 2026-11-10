import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/data/datasources/product_remote_data_source.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../data/models/blog_models.dart';
import '../providers/blog_providers.dart';

class BlogDetailScreen extends ConsumerStatefulWidget {
  const BlogDetailScreen({
    super.key,
    required this.postId,
  });

  final String postId;

  @override
  ConsumerState<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends ConsumerState<BlogDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<String> _commentImages = <String>[];
  BlogPostModel? _post;
  bool _isLoading = true;
  bool _isUploadingCommentImage = false;
  bool _isSubmittingComment = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadPost);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    final result = await ref
        .read(blogRepositoryProvider)
        .getBlogPostById(widget.postId);
    if (!mounted) return;
    result.when(
      success: (post, _, _) {
        setState(() {
          _post = post;
          _isLoading = false;
          _errorMessage = null;
        });
      },
      failure: (err) {
        if (!silent) {
          setState(() {
            _isLoading = false;
            _errorMessage = err.message;
          });
        }
      },
    );
  }

  Future<void> _handleToggleLike() async {
    final current = _post;
    if (current == null) return;

    await ref.read(blogFeedControllerProvider.notifier).toggleLike(current.id);
    await _loadPost(silent: true);
  }

  Future<void> _pickCommentImage() async {
    if (_isUploadingCommentImage || _commentImages.length >= 4) {
      if (_commentImages.length >= 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mỗi bình luận đính kèm tối đa 4 hình ảnh.'),
          ),
        );
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingCommentImage = true);
      final bytes = await picked.readAsBytes();
      final uploadRes = await ref
          .read(productRemoteDataSourceProvider)
          .uploadImages(<UploadableImageFile>[
        UploadableImageFile(
          bytes: bytes,
          fileName: picked.name.isNotEmpty ? picked.name : 'comment_image.jpg',
        ),
      ]);
      if (!mounted) return;
      setState(() => _isUploadingCommentImage = false);

      uploadRes.when(
        success: (urls, _, _) {
          if (urls.isNotEmpty) {
            setState(() => _commentImages.addAll(urls));
          }
        },
        failure: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tải ảnh thất bại: ${err.message}')),
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingCommentImage = false);
    }
  }

  void _showImageZoom(String resolvedUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(
                resolvedUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmitComment() async {
    final text = _commentController.text.trim();
    if ((text.isEmpty && _commentImages.isEmpty) || _isSubmittingComment) {
      return;
    }

    setState(() => _isSubmittingComment = true);
    final result = await ref.read(blogRepositoryProvider).addComment(
          postId: widget.postId,
          content: text,
          images: List<String>.from(_commentImages),
        );
    if (!mounted) return;
    setState(() => _isSubmittingComment = false);

    result.when(
      success: (comment, _, _) {
        _commentController.clear();
        setState(() => _commentImages.clear());
        _loadPost(silent: true);
        ref.read(blogFeedControllerProvider.notifier).loadPosts(silent: true);
      },
      failure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      },
    );
  }

  Future<void> _handleDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài viết Blog?'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa bài viết này khỏi bảng tin cộng đồng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa bài'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(blogRepositoryProvider)
        .deleteBlogPost(widget.postId);
    if (!mounted) return;
    result.when(
      success: (_, _, _) {
        ref.read(blogFeedControllerProvider.notifier).loadPosts();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      },
      failure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      },
    );
  }

  Widget _buildFormattedBody(String rawText) {
    final baseStyle = AppTypography.bodyLarge.copyWith(
      color: AppColors.textPrimary,
      height: 1.55,
    );
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in pattern.allMatches(rawText)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: rawText.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(text: match.group(1), style: boldStyle));
      }
      lastEnd = match.end;
    }
    if (lastEnd < rawText.length) {
      spans.add(TextSpan(
        text: rawText.substring(lastEnd),
        style: baseStyle,
      ));
    }
    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';
    final config = ref.watch(appConfigProvider);
    final post = _post;
    final isAuthor =
        post != null && post.author.id.isNotEmpty && post.author.id == currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết bài viết Blog'),
        actions: [
          if (isAuthor)
            IconButton(
              tooltip: 'Xóa bài viết',
              onPressed: _handleDeletePost,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const RmLoadingIndicator(message: 'Đang tải nội dung bài viết...')
          : _errorMessage != null || post == null
              ? RmErrorState(
                  message: _errorMessage ?? 'Không tìm thấy bài viết',
                  onRetry: _loadPost,
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: AppSpacing.screenPadding,
                        children: [
                          RmCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTintBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${post.category.emoji} ${post.category.labelVi}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Title
                                Text(
                                  post.title,
                                  style: AppTypography.titleLarge.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Author row
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: post.author.id.isNotEmpty
                                      ? () => context.push(
                                            RouteNames.sellerProfile(
                                              post.author.id,
                                            ),
                                          )
                                      : null,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primaryTintBg,
                                        child: Text(
                                          (post.author.displayName.isNotEmpty
                                                  ? post.author.displayName
                                                      .substring(0, 1)
                                                  : 'U')
                                              .toUpperCase(),
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              post.author.displayName,
                                              style: AppTypography.titleMedium
                                                  .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${AppFormatters.formatRelativeDate(post.createdAt)} • ${post.viewsCount} lượt xem',
                                              style: AppTypography.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                const Divider(height: 1),
                                const SizedBox(height: AppSpacing.md),

                                // Body content
                                _buildFormattedBody(post.content),

                                // Images
                                if (post.images.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  for (final img in post.images) ...[
                                    ClipRRect(
                                      borderRadius: AppSpacing.borderRadiusMd,
                                      child: Image.network(
                                        config.resolveMediaUrl(img),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                  ],
                                ],

                                // Attached Product Card
                                if (post.attachedProduct != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  InkWell(
                                    borderRadius: AppSpacing.borderRadiusMd,
                                    onTap: () => context.push(
                                      RouteNames.productDetail(
                                        post.attachedProduct!.id,
                                      ),
                                    ),
                                    child: Container(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryTintBg,
                                        borderRadius: AppSpacing.borderRadiusMd,
                                        border: Border.all(
                                          color:
                                              AppColors.primaryTintBorderStrong,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.shopping_bag_rounded,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Sản phẩm đính kèm trên ReMarket',
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                    fontSize: 11,
                                                    color: AppColors.primaryDark,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  post.attachedProduct!.title,
                                                  style: AppTypography
                                                      .titleMedium
                                                      .copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  '${AppFormatters.formatVnd(post.attachedProduct!.price)} • ${post.attachedProduct!.condition.labelVi}',
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                    color: AppColors.primaryDark,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          FilledButton.tonal(
                                            onPressed: () => context.push(
                                              RouteNames.productDetail(
                                                post.attachedProduct!.id,
                                              ),
                                            ),
                                            child: const Text('Xem ngay'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                // Tags
                                if (post.tags.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      for (final tag in post.tags)
                                        Chip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text('#$tag'),
                                        ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: AppSpacing.md),
                                const Divider(height: 1),
                                const SizedBox(height: AppSpacing.sm),

                                // Like & Comment Bar
                                Row(
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: _handleToggleLike,
                                      icon: Icon(
                                        post.isLiked
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: post.isLiked
                                            ? AppColors.error
                                            : AppColors.textPrimary,
                                      ),
                                      label: Text(
                                        '${post.likesCount} Thích',
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Text(
                                      '${post.comments.length} bình luận',
                                      style: AppTypography.titleMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Comments section
                          Text(
                            'Bình luận cộng đồng (${post.comments.length})',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (post.comments.isEmpty)
                            RmCard(
                              child: Text(
                                'Chưa có bình luận nào. Hãy là người đầu tiên chia sẻ ý kiến dưới bài viết này!',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          else
                            for (final c in post.comments) ...[
                              RmCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primaryTintBg,
                                      child: Text(
                                        (c.author.displayName.isNotEmpty
                                                ? c.author.displayName
                                                    .substring(0, 1)
                                                : 'U')
                                            .toUpperCase(),
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                c.author.displayName,
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                AppFormatters
                                                    .formatRelativeDate(
                                                  c.createdAt,
                                                ),
                                                style: AppTypography.bodySmall
                                                    .copyWith(fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          if (c.content.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              c.content,
                                              style: AppTypography.bodyMedium,
                                            ),
                                          ],
                                          if (c.images.isNotEmpty) ...[
                                            const SizedBox(
                                              height: AppSpacing.sm,
                                            ),
                                            Wrap(
                                              spacing: AppSpacing.xs,
                                              runSpacing: AppSpacing.xs,
                                              children: [
                                                for (final img in c.images)
                                                  GestureDetector(
                                                    onTap: () => _showImageZoom(
                                                      config.resolveMediaUrl(
                                                        img,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppSpacing.radiusSm,
                                                          ),
                                                      child: Container(
                                                        color:
                                                            AppColors.background,
                                                        child: Image.network(
                                                          config.resolveMediaUrl(
                                                            img,
                                                          ),
                                                          width: 96,
                                                          height: 96,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (_, _, _) =>
                                                                  const SizedBox(
                                                                    width: 96,
                                                                    height: 96,
                                                                    child: Icon(
                                                                      Icons
                                                                          .broken_image_outlined,
                                                                      color: AppColors
                                                                          .textMuted,
                                                                    ),
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                        ],
                      ),
                    ),

                    // Comment Input Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_commentImages.isNotEmpty) ...[
                              SizedBox(
                                height: 76,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _commentImages.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: AppSpacing.xs),
                                  itemBuilder: (context, index) {
                                    final imgUrl = config.resolveMediaUrl(
                                      _commentImages[index],
                                    );
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusSm,
                                          ),
                                          child: Container(
                                            color: AppColors.background,
                                            child: Image.network(
                                              imgUrl,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const SizedBox(
                                                    width: 72,
                                                    height: 72,
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _commentImages.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                            ],
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Đính kèm ảnh vào bình luận',
                                  onPressed: _isUploadingCommentImage ||
                                          _isSubmittingComment
                                      ? null
                                      : _pickCommentImage,
                                  icon: _isUploadingCommentImage
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Badge(
                                          isLabelVisible:
                                              _commentImages.isNotEmpty,
                                          label: Text(
                                            '${_commentImages.length}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          backgroundColor: AppColors.primary,
                                          child: const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _handleSubmitComment(),
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Viết bình luận hoặc đính kèm ảnh...',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _isSubmittingComment ||
                                          _isUploadingCommentImage
                                      ? null
                                      : _handleSubmitComment,
                                  icon: _isSubmittingComment
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
