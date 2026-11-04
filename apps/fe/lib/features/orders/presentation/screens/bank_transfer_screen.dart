import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../data/models/payment_model.dart';
import '../providers/order_providers.dart';

class BankTransferScreen extends ConsumerStatefulWidget {
  const BankTransferScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  ConsumerState<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends ConsumerState<BankTransferScreen> {
  final _refController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _refController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _copyText(BuildContext context, String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép $label: $text')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin chuyển khoản'),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Không thể tải thông tin: $err')),
        data: (order) {
          final bankInfo = order.sellerBankInfo;
          final isValidOrder = !order.isCancelledOrRejected;
          final hasBankConfigured =
              isValidOrder && bankInfo != null && bankInfo.isConfigured;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Advisory notice required by specification
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lưu ý: Sau khi chuyển khoản và bấm "Tôi đã chuyển khoản", người bán vẫn cần kiểm tra tài khoản và xác nhận đã nhận tiền để hoàn tất trạng thái thanh toán.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!hasBankConfigured)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 44,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        !isValidOrder
                            ? 'Đơn hàng này đã bị hủy hoặc từ chối nên thông tin tài khoản được ẩn.'
                            : 'Người bán hiện chưa cấu hình thông tin tài khoản ngân hàng. Bạn hãy nhắn tin trực tiếp với người bán trong cuộc trò chuyện đơn hàng nhé.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Tài khoản ngân hàng người bán',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CopyableBankField(
                        label: 'Tên ngân hàng',
                        value: bankInfo.bankName,
                        onCopy: () =>
                            _copyText(context, 'tên ngân hàng', bankInfo.bankName),
                      ),
                      _CopyableBankField(
                        label: 'Tên người nhận',
                        value: bankInfo.accountHolder,
                        onCopy: () => _copyText(
                            context, 'tên người nhận', bankInfo.accountHolder),
                      ),
                      _CopyableBankField(
                        label: 'Số tài khoản',
                        value: bankInfo.accountNumber,
                        highlight: true,
                        onCopy: () => _copyText(
                            context, 'số tài khoản', bankInfo.accountNumber),
                      ),
                      _CopyableBankField(
                        label: 'Số tiền chuyển khoản',
                        value: AppFormatters.formatVnd(order.totalAmount),
                        highlight: true,
                        onCopy: () => _copyText(
                          context,
                          'số tiền',
                          order.totalAmount.toInt().toString(),
                        ),
                      ),
                      _CopyableBankField(
                        label: 'Nội dung chuyển khoản',
                        value: bankInfo.transferContent.isNotEmpty
                            ? bankInfo.transferContent
                            : order.orderCode,
                        highlight: true,
                        onCopy: () => _copyText(
                          context,
                          'nội dung chuyển khoản',
                          bankInfo.transferContent.isNotEmpty
                              ? bankInfo.transferContent
                              : order.orderCode,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              if (order.paymentStatus == PaymentStatus.paid)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.verified_rounded, color: AppColors.success),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Người bán đã xác nhận nhận đủ tiền chuyển khoản cho đơn hàng này!',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (order.paymentStatus == PaymentStatus.buyerConfirmed)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.hourglass_top_rounded, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bạn đã gửi xác nhận chuyển khoản. Hệ thống đã thông báo cho người bán kiểm tra và xác nhận.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isValidOrder) ...<Widget>[
                TextField(
                  controller: _refController,
                  decoration: const InputDecoration(
                    labelText: 'Mã giao dịch ngân hàng (tùy chọn)',
                    hintText: 'Ví dụ: FT263129988 (Không nhập mật khẩu/OTP)',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú chuyển khoản (tùy chọn)',
                    hintText: 'Ví dụ: Đã chuyển khoản qua VCB lúc 14:30',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                RmButton(
                  label: 'Tôi đã chuyển khoản',
                  icon: Icons.check_circle_outline,
                  isLoading: _isSubmitting,
                  onPressed: () async {
                    setState(() => _isSubmitting = true);
                    final paymentRepo = ref.read(paymentRepositoryProvider);
                    final res = await paymentRepo.confirmBuyerPayment(
                      order.id,
                      transactionReference: _refController.text,
                      transferNote: _noteController.text,
                    );
                    if (!mounted) return;
                    setState(() => _isSubmitting = false);
                    res.when(
                      success: (_, _, _) {
                        ref.invalidate(orderDetailProvider(order.id));
                        ref.invalidate(buyerOrdersProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã gửi xác nhận chuyển khoản! Đang chờ người bán kiểm tra và xác nhận.',
                            ),
                          ),
                        );
                        context.pushReplacement(
                          RouteNames.orderDetail(order.id),
                        );
                      },
                      failure: (err) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err.message)),
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CopyableBankField extends StatelessWidget {
  const _CopyableBankField({
    required this.label,
    required this.value,
    required this.onCopy,
    this.highlight = false,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                    fontSize: highlight ? 16 : 14.5,
                    color: highlight ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }
}
