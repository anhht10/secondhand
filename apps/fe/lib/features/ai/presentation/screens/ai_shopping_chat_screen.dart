import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../providers/ai_providers.dart';

/// Multi-turn AI Shopping Assistant Screen (`17 - AI Shopping Chatbot` — `POST /api/v1/ai/chat`).
class AiShoppingChatScreen extends ConsumerStatefulWidget {
  const AiShoppingChatScreen({super.key});

  @override
  ConsumerState<AiShoppingChatScreen> createState() =>
      _AiShoppingChatScreenState();
}

class _AiShoppingChatScreenState extends ConsumerState<AiShoppingChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double? _selectedMaxBudget;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendPrompt([String? presetText]) {
    final text = (presetText ?? _inputController.text).trim();
    if (text.isEmpty) return;
    if (presetText == null) {
      _inputController.clear();
    }
    ref.read(aiChatControllerProvider.notifier).sendMessage(
          text,
          maxBudget: _selectedMaxBudget,
        );
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatControllerProvider);
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryTintBg,
                borderRadius: AppSpacing.borderRadiusSm,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trợ lý Mua sắm Gemini AI',
                    style: AppTypography.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    chatState.threadId != null
                        ? 'Đang nhớ ngữ cảnh hội thoại • Agent + RAG'
                        : 'Tìm đồ cũ hợp ngân sách & phân tích khuyết điểm',
                    style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (chatState.turns.isNotEmpty)
            IconButton(
              tooltip: 'Xóa lịch sử & bắt đầu hội thoại mới',
              onPressed: () {
                ref.read(aiChatControllerProvider.notifier).resetConversation();
              },
              icon: const Icon(Icons.restart_alt_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Optional Budget Filter Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs + 2,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Ngân sách:',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _BudgetChip(
                    label: 'Tất cả',
                    selected: _selectedMaxBudget == null,
                    onTap: () => setState(() => _selectedMaxBudget = null),
                  ),
                  const SizedBox(width: 6),
                  _BudgetChip(
                    label: '≤ 1 triệu',
                    selected: _selectedMaxBudget == 1000000,
                    onTap: () => setState(() => _selectedMaxBudget = 1000000),
                  ),
                  const SizedBox(width: 6),
                  _BudgetChip(
                    label: '≤ 3 triệu',
                    selected: _selectedMaxBudget == 3000000,
                    onTap: () => setState(() => _selectedMaxBudget = 3000000),
                  ),
                  const SizedBox(width: 6),
                  _BudgetChip(
                    label: '≤ 10 triệu',
                    selected: _selectedMaxBudget == 10000000,
                    onTap: () => setState(() => _selectedMaxBudget = 10000000),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 2. Attached Product Context Banner (when navigated from ProductDetailScreen)
          if (chatState.focusedProduct != null)
            Container(
              width: double.infinity,
              color: AppColors.primaryTintBg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppSpacing.borderRadiusSm,
                    child: Container(
                      width: 44,
                      height: 44,
                      color: AppColors.surface,
                      child: chatState.focusedProduct!.primaryImageUrl != null
                          ? Image.network(
                              config.resolveMediaUrl(
                                chatState.focusedProduct!.primaryImageUrl,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.inventory_2_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(
                        RouteNames.productDetail(chatState.focusedProduct!.id),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 13,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Đang hỏi AI về sản phẩm này:',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            chatState.focusedProduct!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${AppFormatters.formatVnd(chatState.focusedProduct!.price)} • ${chatState.focusedProduct!.condition.shortLabelVi}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.5,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bỏ ghim sản phẩm này',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ref
                          .read(aiChatControllerProvider.notifier)
                          .clearFocusedProduct();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // 3. Error Banner (if any)
          if (chatState.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: RmErrorBanner(message: chatState.error!.message),
            ),

          // 3. Conversation Messages Area
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: AppSpacing.screenPadding,
              children: [
                // Intro Hero Card
                RmCard(
                  backgroundColor: AppColors.primaryTintBg,
                  borderColor: AppColors.primaryTintBorderStrong,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.tips_and_updates_outlined,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Xin chào! Tôi là Trợ lý Mua sắm ReMarket',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tôi có thể truy vấn trực tiếp kho sản phẩm thật trên ReMarket, đối chiếu khuyết điểm công khai của người bán và tư vấn kinh nghiệm kiểm tra hàng cũ an toàn.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Turns
                for (final turn in chatState.turns) ...[
                  Align(
                    alignment: turn.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: turn.isUser
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(AppSpacing.radiusLg),
                            topRight:
                                const Radius.circular(AppSpacing.radiusLg),
                            bottomLeft: Radius.circular(
                              turn.isUser ? AppSpacing.radiusLg : 4,
                            ),
                            bottomRight: Radius.circular(
                              turn.isUser ? 4 : AppSpacing.radiusLg,
                            ),
                          ),
                          border: turn.isUser
                              ? null
                              : Border.all(color: AppColors.border),
                          boxShadow: AppSpacing.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!turn.isUser && turn.toolsUsed.isNotEmpty) ...[
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final tool in turn.toolsUsed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryTintBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '⚡ $tool',
                                        style:
                                            AppTypography.bodySmall.copyWith(
                                          fontSize: 10,
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                            turn.isUser
                                ? Text(
                                    turn.text,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  )
                                : _buildFormattedAiText(turn.text),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Matched Products Cards (if AI returned matching products)
                  if (!turn.isUser && turn.matchedProducts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 126,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: turn.matchedProducts.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = turn.matchedProducts[index];
                          final imgUrl =
                              config.resolveMediaUrl(item.primaryImageUrl);
                          return SizedBox(
                            width: 260,
                            child: RmCard(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              onTap: () => context.push(
                                RouteNames.productDetail(item.id),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: AppSpacing.borderRadiusSm,
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      color: AppColors.surfaceVariant,
                                      child: imgUrl.isNotEmpty
                                          ? Image.network(
                                              imgUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
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
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppFormatters.formatVnd(item.price),
                                          style:
                                              AppTypography.priceText.copyWith(
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          item.condition.shortLabelVi,
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],

                // Thinking indicator
                if (chatState.isSending)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppSpacing.borderRadiusLg,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'Gemini AI đang tra cứu sản phẩm & kiến thức...',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. Suggested Follow-up Questions Chips
          if (chatState.followUpQuestions.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final question in chatState.followUpQuestions) ...[
                      ActionChip(
                        avatar: const Icon(
                          Icons.auto_awesome_outlined,
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
                        onPressed: chatState.isSending
                            ? null
                            : () => _sendPrompt(question),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
            ),

          // 5. Message Input Bar
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
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendPrompt(),
                      decoration: const InputDecoration(
                        hintText:
                            'Hỏi tìm sản phẩm, so sánh giá hoặc cách kiểm tra...',
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
                    onPressed: chatState.isSending ? null : () => _sendPrompt(),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFormattedAiText(String rawText) {
    final baseStyle = AppTypography.bodyMedium.copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);
    final italicStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: AppColors.textSecondary,
    );
    final codeStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.primaryDark,
      backgroundColor: AppColors.primaryTintBg,
    );

    final normalized = rawText
        .replaceAll('`LIKE_NEW`', '`Như mới`')
        .replaceAll('`NEW`', '`Mới 100%`')
        .replaceAll('`GOOD`', '`Tốt`')
        .replaceAll('`FAIR`', '`Khá`');

    final pattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\*([^*]+)\*');
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in pattern.allMatches(normalized)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: normalized.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(text: match.group(1), style: boldStyle));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(text: match.group(2), style: codeStyle));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(text: match.group(3), style: italicStyle));
      }
      lastEnd = match.end;
    }
    if (lastEnd < normalized.length) {
      spans.add(TextSpan(
        text: normalized.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }
}
