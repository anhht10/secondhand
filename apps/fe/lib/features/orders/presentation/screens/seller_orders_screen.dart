import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../providers/order_providers.dart';
import 'my_orders_screen.dart';

class SellerOrdersScreen extends ConsumerWidget {
  const SellerOrdersScreen({super.key});

  static const _tabs = <({String key, String label})>[
    (key: 'ALL', label: 'Tất cả'),
    (key: 'PENDING', label: 'Đơn mới'),
    (key: 'PROCESSING', label: 'Đang xử lý'),
    (key: 'COMPLETED', label: 'Hoàn thành'),
    (key: 'CANCELLED', label: 'Bị hủy / Từ chối'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(sellerOrdersProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý đơn bán hàng'),
          actions: <Widget>[
            const Center(child: RealtimeLiveBadge()),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => context.push(RouteNames.myOrdersPath),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Đơn mua'),
            ),
            IconButton(
              tooltip: 'Làm mới',
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(sellerOrdersProvider.notifier).loadOrders(),
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
                            Icons.storefront_outlined,
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
                        ref.read(sellerOrdersProvider.notifier).loadOrders(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = list[index];
                        return OrderSummaryListCard(
                          order: order,
                          isSellerView: true,
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
