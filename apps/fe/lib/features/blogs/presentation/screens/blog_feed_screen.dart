import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_empty_state.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/blog_models.dart';
import '../providers/blog_providers.dart';

class BlogFeedScreen extends ConsumerStatefulWidget {
  const BlogFeedScreen({super.key});

  @override
  ConsumerState<BlogFeedScreen> createState() => _BlogFeedScreenState();
}

class _BlogFeedScreenState extends ConsumerState<BlogFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(blogFeedControllerProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Blog Cộng đồng ReMarket'),
        actions: [
          const Center(child: RealtimeLiveBadge()),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () async {
              final created = await context.push<bool>(RouteNames.createBlogPath);
              if (created == true && mounted) {
                ref.read(blogFeedControllerProvider.notifier).loadPosts();
              }
            },
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Viết bài'),
          ),
          IconButton(
            tooltip: 'Làm mới bảng tin Blog',
            onPressed: () =>
                ref.read(blogFeedControllerProvider.notifier).loadPosts(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await context.push<bool>(RouteNames.createBlogPath);
          if (created == true && mounted) {
            ref.read(blogFeedControllerProvider.notifier).loadPosts();
          }
        },
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text(
          'Đăng bài Blog',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // 1. Search & Category Filter Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (val) => ref
                      .read(blogFeedControllerProvider.notifier)
                      .setKeyword(val),
                  decoration: InputDecoration(
                    hintText: 'Tìm bài viết kinh nghiệm, review đồ cũ, góc học tập...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(blogFeedControllerProvider.notifier)
                                  .setKeyword('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded, size: 18),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tất cả'),
                        selected: feedState.selectedCategory == null,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => ref
                            .read(blogFeedControllerProvider.notifier)
                            .setCategory(null),
                      ),
                      const SizedBox(width: 6),
                      for (final cat in BlogCategory.values) ...[
                        ChoiceChip(
                          label: Text('${cat.emoji} ${cat.labelVi}'),
                          selected: feedState.selectedCategory == cat,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => ref
                              .read(blogFeedControllerProvider.notifier)
                              .setCategory(cat),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Blog Posts Feed
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(blogFeedControllerProvider.notifier).loadPosts(),
              child: feedState.isLoading && feedState.items.isEmpty
                  ? const RmLoadingIndicator(
                      message: 'Đang tải bài viết cộng đồng...',
                    )
                  : feedState.error != null && feedState.items.isEmpty
                      ? RmErrorState(
                          message: feedState.error!.message,
                          onRetry: () => ref
                              .read(blogFeedControllerProvider.notifier)
                              .loadPosts(),
                        )
                      : feedState.items.isEmpty
                          ? RmEmptyState(
                              icon: Icons.article_outlined,
                              title: 'Chưa có bài viết nào trong mục này',
                              subtitle:
                                  'Hãy là người đầu tiên chia sẻ kinh nghiệm mua bán đồ cũ, review sản phẩm hoặc góc học tập của bạn!',
                              actionLabel: 'Viết bài đầu tiên',
                              onAction: () =>
                                  context.push(RouteNames.createBlogPath),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                AppSpacing.md,
                                AppSpacing.lg,
                                92,
                              ),
                              itemCount: feedState.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final post = feedState.items[index];
                                return _BlogPostCard(
                                  post: post,
                                  resolveMediaUrl: config.resolveMediaUrl,
                                  onTap: () async {
                                    await context.push(
                                      RouteNames.blogDetail(post.id),
                                    );
                                    if (mounted) {
                                      ref
                                          .read(blogFeedControllerProvider
                                              .notifier)
                                          .loadPosts(silent: true);
                                    }
                                  },
                                  onToggleLike: () => ref
                                      .read(blogFeedControllerProvider.notifier)
                                      .toggleLike(post.id),
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

class _BlogPostCard extends StatelessWidget {
  const _BlogPostCard({
    required this.post,
    required this.resolveMediaUrl,
    required this.onTap,
    required this.onToggleLike,
  });

  final BlogPostModel post;
  final String Function(String?) resolveMediaUrl;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final cleanPreview = post.content
        .replaceAll('**', '')
        .replaceAll('*', '')
        .trim();

    return RmCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author + Category Badge
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryTintBg,
                child: Text(
                  (post.author.displayName.isNotEmpty
                          ? post.author.displayName.substring(0, 1)
                          : 'U')
                      .toUpperCase(),
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.displayName,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppFormatters.formatRelativeDate(post.createdAt),
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTintBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${post.category.emoji} ${post.category.labelVi}',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Title
          Text(
            post.title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Content snippet
          Text(
            cleanPreview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),

          // Image preview (if any)
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusMd,
              child: SizedBox(
                height: 165,
                width: double.infinity,
                child: Image.network(
                  resolveMediaUrl(post.images.first),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surfaceVariant,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Attached Product Mini Card (if any)
          if (post.attachedProduct != null) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              borderRadius: AppSpacing.borderRadiusSm,
              onTap: () => context.push(
                RouteNames.productDetail(post.attachedProduct!.id),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryTintBg.withValues(alpha: 0.65),
                  borderRadius: AppSpacing.borderRadiusSm,
                  border: Border.all(color: AppColors.primaryTintBorderStrong),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sản phẩm đính kèm: ${post.attachedProduct!.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${AppFormatters.formatVnd(post.attachedProduct!.price)} • ${post.attachedProduct!.condition.shortLabelVi}',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.5,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Tags
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in post.tags.take(4))
                  Text(
                    '#$tag',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Footer: Like, Comment, Views
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onToggleLike,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        post.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: post.isLiked
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount} Thích',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: post.isLiked
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: post.isLiked
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.mode_comment_outlined,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentsCount} Bình luận',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.viewsCount}',
                    style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
