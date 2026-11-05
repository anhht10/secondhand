import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../../../../core/widgets/rm_network_image.dart';
import '../../data/models/order_model.dart';
import '../../data/models/payment_model.dart';
import '../providers/order_providers.dart';

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  static const _tabs = <({String key, String label})>[
    (key: 'ALL', label: 'Tất cả'),
    (key: 'PENDING', label: 'Chờ xác nhận'),
    (key: 'PROCESSING', label: 'Đang xử lý'),
    (key: 'COMPLETED', label: 'Hoàn thành'),
    (key: 'CANCELLED', label: 'Đã hủy'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(buyerOrdersProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn mua của tôi'),
          actions: <Widget>[
            const Center(child: RealtimeLiveBadge()),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => context.push(RouteNames.sellerOrdersPath),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Đơn bán'),
            ),
            IconButton(
              tooltip: 'Làm mới',
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(buyerOrdersProvider.notifier).loadOrders(),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
          ),
        ),
        body: ordersState.isLoading && ordersState.orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: _tabs.map((t) {
                  final list = ordersState.filterByTab(t.key);
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 52,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Chưa có đơn hàng nào trong mục "${t.label}"',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(buyerOrdersProvider.notifier).loadOrders(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = list[index];
                        return OrderSummaryListCard(
                          order: order,
                          isSellerView: false,
                          onTap: () =>
                              context.push(RouteNames.orderDetail(order.id)),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class OrderSummaryListCard extends StatelessWidget {
  const OrderSummaryListCard({
    super.key,
    required this.order,
    required this.isSellerView,
    required this.onTap,
  });

  final OrderModel order;
  final bool isSellerView;
  final VoidCallback onTap;

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
      case OrderStatus.shipping:
      case OrderStatus.delivered:
        return AppColors.primary;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(order.status);
    final counterpartyLabel = isSellerView
        ? 'Người mua: ${order.buyer?.displayName ?? "Khách hàng"}'
        : 'Người bán: ${order.seller?.displayName ?? "Người bán"}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.status.labelVi,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        counterpartyLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.deliveryMethod.labelVi} • ${order.paymentMethod.labelVi}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      order.paymentStatus == PaymentStatus.paid
                          ? Icons.verified_rounded
                          : Icons.payments_outlined,
                      size: 16,
                      color: order.paymentStatus == PaymentStatus.paid
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.paymentStatus.labelVi,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: order.paymentStatus == PaymentStatus.paid
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  AppFormatters.formatVnd(order.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (!isSellerView && order.isCompleted) ...<Widget>[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: order.hasReview
                    ? OutlinedButton.icon(
                        key: Key('view_review_btn_${order.id}'),
                        onPressed: () {
                          if (order.reviewId != null &&
                              order.reviewId!.isNotEmpty) {
                            context.push(
                              RouteNames.reviewDetail(order.reviewId!),
                            );
                          } else {
                            context.push(RouteNames.writeReview(order.id));
                          }
                        },
                        icon: const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        label: const Text('Đã đánh giá (Xem / Sửa)'),
                      )
                    : FilledButton.icon(
                        key: Key('write_review_btn_${order.id}'),
                        onPressed: () =>
                            context.push(RouteNames.writeReview(order.id)),
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: const Text('Đánh giá người bán'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
