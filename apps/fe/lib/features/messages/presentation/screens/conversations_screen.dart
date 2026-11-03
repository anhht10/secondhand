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
import '../providers/messages_providers.dart';

/// Conversations List Screen (`GET /api/v1/messages/conversations`).
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convState = ref.watch(conversationsControllerProvider);
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tin nhắn trao đổi'),
        actions: [
          const Center(child: RealtimeLiveBadge()),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Làm mới danh sách tin nhắn',
            onPressed: () => ref
                .read(conversationsControllerProvider.notifier)
                .loadConversations(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref
            .read(conversationsControllerProvider.notifier)
            .loadConversations(),
        child: convState.isLoading && convState.items.isEmpty
            ? const RmLoadingIndicator(
                message: 'Đang tải danh sách cuộc trò chuyện...',
              )
            : convState.error != null && convState.items.isEmpty
                ? RmErrorState(
                    message: convState.error!.message,
                    onRetry: () => ref
                        .read(conversationsControllerProvider.notifier)
                        .loadConversations(),
                  )
                : convState.items.isEmpty
                    ? RmEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Chưa có cuộc trò chuyện nào',
                        subtitle:
                            'Khi bạn nhắn tin hỏi mua hoặc có người mua liên hệ, cuộc trò chuyện gắn với sản phẩm sẽ hiển thị tại đây.',
                        actionLabel: 'Khám phá sản phẩm',
                        onAction: () => context.go(RouteNames.homePath),
                      )
                    : ListView.separated(
                        padding: AppSpacing.screenPadding,
                        itemCount: convState.items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final conv = convState.items[index];
                          final counterpart =
                              conv.counterpartFor(currentUserId);
                          final productImg = config
                              .resolveMediaUrl(conv.product.primaryImageUrl);

                          final isUnread = conv.hasUnread;

                          return RmCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            onTap: () async {
                              ref
                                  .read(conversationsControllerProvider.notifier)
                                  .markConversationReadLocally(conv.id);
                              await context.push(
                                RouteNames.chatDetail(conv.id),
                              );
                              ref
                                  .read(conversationsControllerProvider.notifier)
                                  .loadConversations(silent: true);
                            },
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: isUnread
                                          ? AppColors.primary.withValues(alpha: 0.16)
                                          : AppColors.primaryTintBg,
                                      child: Text(
                                        (counterpart.displayName.trim().isNotEmpty
                                                ? counterpart.displayName
                                                    .trim()
                                                    .substring(0, 1)
                                                : 'U')
                                            .toUpperCase(),
                                        style: AppTypography.titleLarge.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: isUnread
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        right: -1,
                                        top: -1,
                                        child: Container(
                                          width: 13,
                                          height: 13,
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.surface,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              counterpart.displayName,
                                              style: AppTypography.titleMedium
                                                  .copyWith(
                                                fontWeight: isUnread
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            AppFormatters.formatRelativeDate(
                                              conv.lastMessageAt ??
                                                  conv.updatedAt,
                                            ),
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              fontSize: 11,
                                              fontWeight: isUnread
                                                  ? FontWeight.w800
                                                  : FontWeight.w400,
                                              color: isUnread
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${conv.product.title} • ${AppFormatters.formatVnd(conv.product.price)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              conv.lastMessage?.trim().isNotEmpty ==
                                                      true
                                                  ? conv.lastMessage!
                                                  : 'Bắt đầu trao đổi về sản phẩm...',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                fontWeight: isUnread
                                                    ? FontWeight.w800
                                                    : FontWeight.w400,
                                                color: isUnread
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.error,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                conv.unreadCount > 99
                                                    ? '99+'
                                                    : '${conv.unreadCount}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                ClipRRect(
                                  borderRadius: AppSpacing.borderRadiusSm,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    color: AppColors.surfaceVariant,
                                    child: productImg.isNotEmpty
                                        ? Image.network(
                                            productImg,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 20,
                                              color: AppColors.textMuted,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 20,
                                            color: AppColors.textMuted,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
