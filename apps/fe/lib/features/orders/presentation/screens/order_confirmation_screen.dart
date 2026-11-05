import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../data/models/payment_model.dart';
import '../providers/order_providers.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt mua thành công'),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi tải đơn hàng: $err')),
        data: (order) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Yêu cầu mua hàng đã được gửi!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mã đơn: ${order.orderCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sản phẩm đã được giữ chỗ (Reserved) cho bạn. Vui lòng chờ người bán xác nhận đơn hàng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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
                    _InfoRow(
                      label: 'Sản phẩm',
                      value: order.productSnapshot.title,
                    ),
                    _InfoRow(
                      label: 'Người bán',
                      value: order.seller?.displayName ?? 'Người bán ReMarket',
                    ),
                    _InfoRow(
                      label: 'Phương thức nhận hàng',
                      value: order.deliveryMethod.labelVi,
                    ),
                    _InfoRow(
                      label: 'Phương thức thanh toán',
                      value: order.paymentMethod.labelVi,
                    ),
                    _InfoRow(
                      label: 'Tổng thanh toán',
                      value: AppFormatters.formatVnd(order.totalAmount),
                      highlight: true,
                    ),
                    _InfoRow(
                      label: 'Trạng thái đơn',
                      value: order.status.labelVi,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (order.paymentMethod == PaymentMethod.bankTransfer) ...<Widget>[
                RmButton(
                  label: 'Xem thông tin chuyển khoản ngân hàng',
                  icon: Icons.account_balance_outlined,
                  onPressed: () =>
                      context.push(RouteNames.bankTransfer(order.id)),
                ),
                const SizedBox(height: 12),
              ],
              RmButton(
                label: 'Xem chi tiết đơn hàng',
                variant: order.paymentMethod == PaymentMethod.bankTransfer
                    ? RmButtonVariant.outlined
                    : RmButtonVariant.primary,
                icon: Icons.receipt_long_outlined,
                onPressed: () =>
                    context.pushReplacement(RouteNames.orderDetail(order.id)),
              ),
              const SizedBox(height: 10),
              RmButton(
                label: 'Quản lý đơn mua của tôi',
                variant: RmButtonVariant.ghost,
                onPressed: () => context.pushReplacement(RouteNames.myOrdersPath),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                fontSize: highlight ? 15.5 : 13.5,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
