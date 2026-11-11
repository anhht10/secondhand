import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_network_image.dart';
import '../../../../shared/widgets/location_map_picker_sheet.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../data/models/order_model.dart';
import '../../data/models/payment_model.dart';
import '../providers/order_providers.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isMutating = false;
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _realtimeTimer = startRealtimePeriodicSync(
      interval: const Duration(milliseconds: 2500),
      onTick: () {
        if (!mounted || _isMutating) return;
        ref.invalidate(orderDetailProvider(widget.orderId));
      },
    );
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  void _refreshOrder(OrderModel order) {
    ref.invalidate(orderDetailProvider(order.id));
    ref.invalidate(buyerOrdersProvider);
    ref.invalidate(sellerOrdersProvider);
    ref.invalidate(productDetailProvider(order.productId));
    ref.invalidate(productOrderSummaryProvider(order.productId));
    ref.invalidate(notificationsProvider);
  }

  Future<void> _executeAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        actions: <Widget>[
          const Center(child: RealtimeLiveBadge()),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () =>
                ref.invalidate(orderDetailProvider(widget.orderId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: orderAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Không thể tải chi tiết đơn hàng: $err'),
          ),
        ),
        data: (order) {
          final isBuyer = order.buyerId == currentUserId;
          final isSeller = order.sellerId == currentUserId;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: <Widget>[
              // 1. Status Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Mã đơn: ${order.orderCode}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Chip(
                          label: Text(
                            order.status.labelVi,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thanh toán: ${order.paymentStatus.labelVi} (${order.paymentMethod.labelVi})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (order.payment?.transactionReference != null &&
                        order.payment!.transactionReference!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Mã GD chuyển khoản: ${order.payment!.transactionReference}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Product Snapshot Card
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () =>
                    context.push(RouteNames.productDetail(order.productId)),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: RmNetworkImage(
                            imageUrl: order.productSnapshot.imageUrl,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tổng tiền: ${AppFormatters.formatVnd(order.totalAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Buyer & Seller & Delivery Info
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
                      'Thông tin giao nhận & đối tác',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DetailItem(
                      label: 'Người bán',
                      value: order.seller?.displayName ?? 'Người bán ReMarket',
                    ),
                    _DetailItem(
                      label: 'Người mua',
                      value:
                          '${order.buyer?.displayName ?? order.recipientName ?? "Người mua"}'
                          '${order.recipientPhone != null ? " (${order.recipientPhone})" : ""}',
                    ),
                    _DetailItem(
                      label: 'Hình thức nhận hàng',
                      value: order.deliveryMethod.labelVi,
                    ),
                    if (order.deliveryMethod == DeliveryMethod.delivery &&
                        order.shippingAddress != null)
                      _DetailItem(
                        label: 'Địa chỉ giao hàng',
                        value: order.shippingAddress!,
                        onOpenMap: () => LocationMapPickerSheet.showPreview(
                          context,
                          address: order.shippingAddress!,
                          isMeetup: false,
                        ),
                      ),
                    if (order.deliveryMethod == DeliveryMethod.meetup &&
                        order.meetupLocation != null)
                      _DetailItem(
                        label: 'Địa điểm hẹn gặp',
                        value: order.meetupLocation!,
                        onOpenMap: () => LocationMapPickerSheet.showPreview(
                          context,
                          address: order.meetupLocation!,
                          isMeetup: true,
                        ),
                      ),
                    if (order.buyerNote != null && order.buyerNote!.isNotEmpty)
                      _DetailItem(
                        label: 'Ghi chú của người mua',
                        value: order.buyerNote!,
                      ),
                    if (order.conversationId != null &&
                        order.conversationId!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      RmButton(
                        label: isSeller
                            ? 'Nhắn tin với người mua'
                            : 'Nhắn tin với người bán',
                        variant: RmButtonVariant.outlined,
                        icon: Icons.chat_bubble_outline,
                        onPressed: () => context.push(
                          RouteNames.chatDetail(order.conversationId!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Role-based Valid Actions
              if (isBuyer) ..._buildBuyerActions(context, order),
              if (isSeller) ..._buildSellerActions(context, order),

              const SizedBox(height: 18),

              // 5. Order Timeline
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
                      'Lịch sử trạng thái đơn hàng',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...order.timeline.reversed.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(
                                Icons.circle,
                                size: 10,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${entry.status} (${entry.actorRole})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (entry.note != null &&
                                      entry.note!.isNotEmpty)
                                    Text(
                                      entry.note!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  Text(
                                    AppFormatters.formatRelativeTime(
                                      entry.timestamp,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBuyerActions(BuildContext context, OrderModel order) {
    final repo = ref.read(orderRepositoryProvider);
    final widgets = <Widget>[];

    if (order.paymentMethod == PaymentMethod.bankTransfer &&
        !order.isCancelledOrRejected) {
      widgets.add(
        RmButton(
          label: order.paymentStatus == PaymentStatus.unpaid
              ? 'Xem thông tin chuyển khoản & Xác nhận đã chuyển'
              : 'Xem thông tin chuyển khoản ngân hàng',
          icon: Icons.account_balance_outlined,
          variant: order.paymentStatus == PaymentStatus.unpaid
              ? RmButtonVariant.primary
              : RmButtonVariant.outlined,
          onPressed: () => context.push(RouteNames.bankTransfer(order.id)),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    if (order.canBuyerComplete) {
      widgets.add(
        RmButton(
          label: 'Đã nhận hàng & Hoàn tất đơn hàng',
          icon: Icons.task_alt_rounded,
          isLoading: _isMutating,
          onPressed: () => _executeAction(
            () async {
              final res = await repo.completeOrder(order.id);
              res.when(
                success: (_, _, _) => _refreshOrder(order),
                failure: (err) => throw err.message,
              );
            },
            successMessage:
                'Giao dịch hoàn tất! Sản phẩm đã được chuyển sang Đã bán.',
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    if (order.canBuyerCancel) {
      widgets.add(
        RmButton(
          label: 'Hủy đơn hàng',
          variant: RmButtonVariant.danger,
          icon: Icons.cancel_outlined,
          isLoading: _isMutating,
          onPressed: () => _executeAction(
            () async {
              final res = await repo.cancelOrder(
                order.id,
                reason: 'Người mua chủ động hủy đơn hàng',
              );
              res.when(
                success: (_, _, _) => _refreshOrder(order),
                failure: (err) => throw err.message,
              );
            },
            successMessage: 'Đã hủy đơn hàng và mở lại trạng thái sản phẩm.',
          ),
        ),
      );
    }

    if (order.isCompleted) {
      if (order.hasReview) {
        widgets.add(
          RmButton(
            label: 'Xem / Chỉnh sửa đánh giá đã gửi',
            variant: RmButtonVariant.outlined,
            icon: Icons.star_rounded,
            onPressed: () {
              if (order.reviewId != null && order.reviewId!.isNotEmpty) {
                context.push(RouteNames.reviewDetail(order.reviewId!));
              } else {
                context.push(RouteNames.writeReview(order.id));
              }
            },
          ),
        );
      } else {
        widgets.add(
          RmButton(
            label: 'Đánh giá người bán',
            icon: Icons.rate_review_outlined,
            onPressed: () => context.push(RouteNames.writeReview(order.id)),
          ),
        );
      }
    }

    return widgets;
  }

  List<Widget> _buildSellerActions(BuildContext context, OrderModel order) {
    final orderRepo = ref.read(orderRepositoryProvider);
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final widgets = <Widget>[];

    if (order.canSellerConfirm) {
      widgets.add(
        RmButton(
          label: 'Xác nhận đơn hàng',
          icon: Icons.check_circle_outline,
          isLoading: _isMutating,
          onPressed: () => _executeAction(
            () async {
              final res = await orderRepo.confirmOrder(order.id);
              res.when(
                success: (_, _, _) => _refreshOrder(order),
                failure: (err) => throw err.message,
              );
            },
            successMessage: 'Đã xác nhận đơn hàng!',
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    if (order.canSellerConfirmPayment) {
      widgets.add(
        RmButton(
          label: 'Xác nhận đã nhận tiền chuyển khoản',
          icon: Icons.verified_outlined,
          isLoading: _isMutating,
          onPressed: () => _executeAction(
            () async {
              final res = await paymentRepo.confirmSellerPayment(order.id);
              res.when(
                success: (_, _, _) => _refreshOrder(order),
                failure: (err) => throw err.message,
              );
            },
            successMessage: 'Đã xác nhận nhận tiền thành công!',
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    if (order.canSellerUpdateShipping) {
      final nextDeliveryStatus =
          order.status == OrderStatus.confirmed ? 'SHIPPING' : 'DELIVERED';
      final btnLabel = nextDeliveryStatus == 'SHIPPING'
          ? 'Cập nhật: Đang giao hàng / Đi điểm hẹn'
          : 'Cập nhật: Đã bàn giao sản phẩm cho người mua';
      widgets.add(
        RmButton(
          label: btnLabel,
          variant: RmButtonVariant.secondary,
          icon: Icons.local_shipping_outlined,
          isLoading: _isMutating,
          onPressed: () => _executeAction(
            () async {
              final res = await orderRepo.updateDeliveryStatus(
                order.id,
                deliveryStatus: nextDeliveryStatus,
              );
              res.when(
                success: (_, _, _) => _refreshOrder(order),
                failure: (err) => throw err.message,
              );
            },
            successMessage: 'Đã cập nhật tiến độ giao nhận!',
          ),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    if (order.canSellerReject) {
      widgets.add(
        RmButton(
          label: 'Từ chối đơn hàng',
          variant: RmButtonVariant.danger,
          icon: Icons.block_flipped,
          isLoading: _isMutating,
          onPressed: () => _executeAction(
            () async {
              final res = await orderRepo.rejectOrder(
                order.id,
                reason: 'Người bán từ chối đơn hàng',
              );
              res.when(
                success: (_, _, _) => _refreshOrder(order),
                failure: (err) => throw err.message,
              );
            },
            successMessage:
                'Đã từ chối đơn hàng và khôi phục sản phẩm về Đang bán.',
          ),
        ),
      );
    }

    if (order.isCompleted &&
        order.hasReview &&
        order.reviewId != null &&
        order.reviewId!.isNotEmpty) {
      widgets.add(
        RmButton(
          label: 'Xem & Phản hồi đánh giá từ người mua',
          variant: RmButtonVariant.outlined,
          icon: Icons.reviews_outlined,
          onPressed: () =>
              context.push(RouteNames.reviewDetail(order.reviewId!)),
        ),
      );
    }

    return widgets;
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    this.onOpenMap,
  });

  final String label;
  final String value;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          if (onOpenMap != null) ...<Widget>[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onOpenMap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTintBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.map_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Bản đồ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
