import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../products/data/models/product_model.dart';
import '../../data/models/message_models.dart';
import '../providers/messages_providers.dart';

/// Buyer–Seller Chat Screen (`18 - Buyer Seller Chat`).
///
/// Uses REST endpoints (`GET /messages/conversations/:id`,
/// `GET/POST /messages/conversations/:id/messages`, `PATCH /messages/:id/read`)
/// with manual/pull-to-refresh and immediate message append.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
  });

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ConversationModel? _conversation;
  List<MessageModel> _messages = const <MessageModel>[];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _realtimeTimer;

  static const List<String> _quickQuestions = <String>[
    'Sản phẩm này hiện còn không bạn?',
    'Cho mình xin thêm thông tin về tình trạng/khuyết điểm nhé.',
    'Mình có thể hẹn kiểm tra trực tiếp ở đâu?',
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadChatData);
    _realtimeTimer = startRealtimePeriodicSync(
      interval: const Duration(milliseconds: 2500),
      onTick: () => _loadChatData(silent: true),
    );
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final repo = ref.read(messagesRepositoryProvider);
    final convResult = await repo.getConversationById(widget.conversationId);
    final msgsResult =
        await repo.getConversationMessages(widget.conversationId);

    if (!mounted) return;

    convResult.when(
      success: (conv, _, _) {
        _conversation = conv;
        if (silent && conv.product.id.isNotEmpty) {
          ref.invalidate(productOrderSummaryProvider(conv.product.id));
        }
      },
      failure: (err) {
        if (!silent) {
          _errorMessage = err.message;
        }
      },
    );

    var hasNewMessages = false;
    msgsResult.when(
      success: (msgs, _, _) {
        // Backend returns newest or chronological; sort ascending by createdAt
        final sorted = List<MessageModel>.from(msgs)
          ..sort((a, b) {
            final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return ta.compareTo(tb);
          });
        hasNewMessages = sorted.length != _messages.length ||
            (sorted.isNotEmpty &&
                (_messages.isEmpty || sorted.last.id != _messages.last.id));
        _messages = sorted;
        _markUnreadIncomingAsRead(sorted);
      },
      failure: (err) {
        if (!silent) {
          _errorMessage ??= err.message;
        }
      },
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!silent || hasNewMessages) {
        _scrollToBottom();
      }
    }
  }

  Future<void> _markUnreadIncomingAsRead(List<MessageModel> messages) async {
    final currentUserId = ref.read(authControllerProvider).user?.id ?? '';
    final repo = ref.read(messagesRepositoryProvider);
    var markedAny = false;
    for (final msg in messages) {
      if (!msg.isRead &&
          msg.senderId.isNotEmpty &&
          msg.senderId != currentUserId) {
        markedAny = true;
        await repo.markMessageAsRead(msg.id);
      }
    }
    if (!mounted) return;
    ref
        .read(conversationsControllerProvider.notifier)
        .markConversationReadLocally(widget.conversationId);
    if (markedAny) {
      ref
          .read(conversationsControllerProvider.notifier)
          .loadConversations(silent: true);
    }
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final content = (presetText ?? _messageController.text).trim();
    if (content.isEmpty || _isSending) return;

    if (presetText == null) {
      _messageController.clear();
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final result = await ref.read(messagesRepositoryProvider).sendMessage(
          conversationId: widget.conversationId,
          content: content,
        );

    if (!mounted) return;
    setState(() => _isSending = false);

    result.when(
      success: (newMsg, _, _) {
        setState(() {
          _messages = <MessageModel>[..._messages, newMsg];
        });
        ref
            .read(conversationsControllerProvider.notifier)
            .loadConversations();
        _scrollToBottom();
      },
      failure: (err) {
        setState(() => _errorMessage = err.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';
    final config = ref.watch(appConfigProvider);
    final counterpart = _conversation?.counterpartFor(currentUserId);
    final product = _conversation?.product;
    final activeOrder = (product != null && product.id.isNotEmpty)
        ? ref.watch(productOrderSummaryProvider(product.id)).valueOrNull
        : null;
    final isBuyer = _conversation != null &&
        (_conversation!.buyer.id == currentUserId ||
            (_conversation!.seller.id.isNotEmpty &&
                _conversation!.seller.id != currentUserId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              counterpart?.displayName ?? 'Trao đổi mua bán',
              style: AppTypography.titleMedium,
            ),
            if (counterpart?.location != null)
              Text(
                counterpart!.location!,
                style: AppTypography.bodySmall.copyWith(fontSize: 11),
              ),
          ],
        ),
        actions: [
          const Center(child: RealtimeLiveBadge()),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Tải tin nhắn mới nhất',
            onPressed: _loadChatData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading && _conversation == null
          ? const RmLoadingIndicator(message: 'Đang mở cuộc trò chuyện...')
          : _errorMessage != null && _conversation == null
              ? RmErrorState(
                  message: _errorMessage!,
                  onRetry: _loadChatData,
                )
              : Column(
                  children: [
                    // 1. Pinned Product Context Header Card (`18 - Buyer Seller Chat`)
                    if (product != null && product.id.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm + 2,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTintBg,
                          border: Border(
                            bottom:
                                BorderSide(color: AppColors.primaryTintBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: AppSpacing.borderRadiusSm,
                              child: Container(
                                width: 46,
                                height: 46,
                                color: AppColors.surface,
                                child: config
                                        .resolveMediaUrl(
                                          product.primaryImageUrl,
                                        )
                                        .isNotEmpty
                                    ? Image.network(
                                        config.resolveMediaUrl(
                                          product.primaryImageUrl,
                                        ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
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
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${AppFormatters.formatVnd(product.price)} • ${product.condition.shortLabelVi} • ${product.status.labelVi}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                             TextButton(
                              onPressed: () => context.push(
                                RouteNames.productDetail(product.id),
                              ),
                              child: const Text('Xem tin'),
                            ),
                            if (activeOrder == null &&
                                isBuyer &&
                                product.status == ProductStatus.active)
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  await context.push(
                                    RouteNames.checkout(
                                      product.id,
                                      conversationId: widget.conversationId,
                                    ),
                                  );
                                  if (mounted) {
                                    ref.invalidate(
                                      productOrderSummaryProvider(product.id),
                                    );
                                    _loadChatData();
                                  }
                                },
                                icon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 16,
                                ),
                                label: const Text('Mua ngay'),
                              ),
                          ],
                        ),
                      ),

                    // 1b. Active Order Summary Banner in Chat (`Section 11 - Messaging Integration`)
                    if (activeOrder != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: const Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đơn hàng ${activeOrder.orderCode} • ${activeOrder.status.labelVi}',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Thanh toán: ${activeOrder.paymentStatus.labelVi} (${AppFormatters.formatVnd(activeOrder.totalAmount)})',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                await context.push(
                                  RouteNames.orderDetail(activeOrder.id),
                                );
                                if (mounted && product != null) {
                                  ref.invalidate(
                                    productOrderSummaryProvider(product.id),
                                  );
                                  _loadChatData();
                                }
                              },
                              child: const Text('Mở đơn'),
                            ),
                          ],
                        ),
                      ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: RmErrorBanner(message: _errorMessage!),
                      ),

                    // 2. Messages List
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadChatData,
                        child: _messages.isEmpty
                            ? ListView(
                                padding: AppSpacing.screenPadding,
                                children: [
                                  const SizedBox(height: AppSpacing.xxl),
                                  Center(
                                    child: Text(
                                      'Hãy gửi lời chào hoặc chọn câu hỏi gợi ý bên dưới để trao đổi với người bán.',
                                      style: AppTypography.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: AppSpacing.screenPadding,
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  final isMe = msg.senderId == currentUserId;
                                  final isOrderMsg =
                                      msg.messageType == MessageType.order;

                                  if (isOrderMsg) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.md,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryTintBg,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppColors.primaryTintBorder,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.local_mall_outlined,
                                                  size: 18,
                                                  color: AppColors.primaryDark,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Cập nhật đơn hàng',
                                                  style: AppTypography.bodySmall
                                                      .copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  AppFormatters
                                                      .formatRelativeDate(
                                                    msg.createdAt,
                                                  ),
                                                  style: AppTypography.bodySmall
                                                      .copyWith(fontSize: 10.5),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              msg.content,
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            if (msg.orderId != null &&
                                                msg.orderId!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: TextButton.icon(
                                                  onPressed: () => context.push(
                                                    RouteNames.orderDetail(
                                                      msg.orderId!,
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.open_in_new_rounded,
                                                    size: 15,
                                                  ),
                                                  label: const Text(
                                                    'Xem chi tiết đơn hàng',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Align(
                                      alignment: isMe
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 310,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm + 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? AppColors.primary
                                                : AppColors.surface,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(
                                                AppSpacing.radiusLg,
                                              ),
                                              topRight: const Radius.circular(
                                                AppSpacing.radiusLg,
                                              ),
                                              bottomLeft: Radius.circular(
                                                isMe ? AppSpacing.radiusLg : 4,
                                              ),
                                              bottomRight: Radius.circular(
                                                isMe ? 4 : AppSpacing.radiusLg,
                                              ),
                                            ),
                                            border: isMe
                                                ? null
                                                : Border.all(
                                                    color: AppColors.border,
                                                  ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: isMe
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                msg.content,
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                  color: isMe
                                                      ? Colors.white
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${AppFormatters.formatRelativeDate(msg.createdAt)}${isMe ? (msg.isRead ? " • Đã xem" : " • Đã gửi") : ""}',
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                  fontSize: 10,
                                                  color: isMe
                                                      ? Colors.white.withValues(
                                                          alpha: 0.8,
                                                        )
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),

                    // 3. Quick Inquiry Chips
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xs,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final q in _quickQuestions) ...[
                              ActionChip(
                                label: Text(
                                  q,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    _isSending ? null : () => _sendMessage(q),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // 4. Message Input Bar
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
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: const InputDecoration(
                                  hintText: 'Nhập tin nhắn trao đổi...',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed:
                                  _isSending ? null : () => _sendMessage(),
                              icon: _isSending
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
                      ),
                    ),
                  ],
                ),
    );
  }
}
