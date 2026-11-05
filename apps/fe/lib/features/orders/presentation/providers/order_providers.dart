import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../data/datasources/order_remote_data_source.dart';
import '../../data/models/order_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/payment_repository.dart';

final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSource(ref.watch(apiClientProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(orderRemoteDataSourceProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(orderRemoteDataSourceProvider));
});

/// Fetches a single order by `orderId`.
final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderModel, String>((ref, orderId) async {
  final repo = ref.watch(orderRepositoryProvider);
  final result = await repo.getOrderById(orderId);
  return result.when(
    success: (order, _, _) => order,
    failure: (error) => throw error,
  );
});

/// Fetches the latest order for a specific `productId` involving the current user (used in Chat & Product Detail).
final productOrderSummaryProvider = FutureProvider.autoDispose
    .family<OrderModel?, String>((ref, productId) async {
  final repo = ref.watch(orderRepositoryProvider);
  final result = await repo.getLatestOrderByProduct(productId);
  return result.when(
    success: (order, _, _) => order,
    failure: (_) => null,
  );
});

/// Fetches in-app notifications for the current user.
final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final result = await repo.getNotifications(page: 1, limit: 30);
  return result.when(
    success: (items, _, _) => items,
    failure: (_) => const <NotificationModel>[],
  );
});

/// State for Buyer or Seller order list screens.
class OrdersListState {
  const OrdersListState({
    this.orders = const <OrderModel>[],
    this.isLoading = false,
    this.error,
  });

  final List<OrderModel> orders;
  final bool isLoading;
  final ApiException? error;

  List<OrderModel> filterByTab(String tabKey) {
    switch (tabKey) {
      case 'PENDING':
        return orders.where((o) => o.isPending).toList();
      case 'PROCESSING':
        return orders.where((o) => o.isProcessing).toList();
      case 'COMPLETED':
        return orders.where((o) => o.isCompleted).toList();
      case 'CANCELLED':
        return orders.where((o) => o.isCancelledOrRejected).toList();
      case 'ALL':
      default:
        return orders;
    }
  }
}

class BuyerOrdersNotifier extends StateNotifier<OrdersListState> {
  BuyerOrdersNotifier(this._repository) : super(const OrdersListState()) {
    loadOrders();
    _realtimeTimer = startRealtimePeriodicSync(
      interval: const Duration(seconds: 3),
      onTick: () => loadOrders(silent: true),
    );
  }

  final OrderRepository _repository;
  Timer? _realtimeTimer;

  Future<void> loadOrders({bool silent = false}) async {
    if (!silent) {
      state = OrdersListState(orders: state.orders, isLoading: true);
    }
    final res = await _repository.getBuyerOrders(page: 1, limit: 50);
    if (!mounted) return;
    res.when(
      success: (items, _, _) {
        state = OrdersListState(orders: items, isLoading: false);
      },
      failure: (err) {
        if (!silent) {
          state = OrdersListState(
            orders: state.orders,
            isLoading: false,
            error: err,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }
}

final buyerOrdersProvider =
    StateNotifierProvider.autoDispose<BuyerOrdersNotifier, OrdersListState>(
        (ref) {
  return BuyerOrdersNotifier(ref.watch(orderRepositoryProvider));
});

class SellerOrdersNotifier extends StateNotifier<OrdersListState> {
  SellerOrdersNotifier(this._repository) : super(const OrdersListState()) {
    loadOrders();
    _realtimeTimer = startRealtimePeriodicSync(
      interval: const Duration(seconds: 3),
      onTick: () => loadOrders(silent: true),
    );
  }

  final OrderRepository _repository;
  Timer? _realtimeTimer;

  Future<void> loadOrders({bool silent = false}) async {
    if (!silent) {
      state = OrdersListState(orders: state.orders, isLoading: true);
    }
    final res = await _repository.getSellerOrders(page: 1, limit: 50);
    if (!mounted) return;
    res.when(
      success: (items, _, _) {
        state = OrdersListState(orders: items, isLoading: false);
      },
      failure: (err) {
        if (!silent) {
          state = OrdersListState(
            orders: state.orders,
            isLoading: false,
            error: err,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }
}

final sellerOrdersProvider =
    StateNotifierProvider.autoDispose<SellerOrdersNotifier, OrdersListState>(
        (ref) {
  return SellerOrdersNotifier(ref.watch(orderRepositoryProvider));
});

/// State for Checkout & Order Action mutations.
class CheckoutState {
  const CheckoutState({
    this.deliveryMethod = DeliveryMethod.meetup,
    this.paymentMethod = PaymentMethod.cash,
    this.isSubmitting = false,
    this.createdOrder,
    this.error,
  });

  final DeliveryMethod deliveryMethod;
  final PaymentMethod paymentMethod;
  final bool isSubmitting;
  final OrderModel? createdOrder;
  final ApiException? error;

  CheckoutState copyWith({
    DeliveryMethod? deliveryMethod,
    PaymentMethod? paymentMethod,
    bool? isSubmitting,
    OrderModel? createdOrder,
    ApiException? error,
    bool clearError = false,
  }) {
    return CheckoutState(
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      createdOrder: createdOrder ?? this.createdOrder,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CheckoutController extends StateNotifier<CheckoutState> {
  CheckoutController({
    required this.orderRepository,
    required this.paymentRepository,
    required this.ref,
  }) : super(const CheckoutState());

  final OrderRepository orderRepository;
  final PaymentRepository paymentRepository;
  final Ref ref;

  void setDeliveryMethod(DeliveryMethod method) {
    var nextPayment = state.paymentMethod;
    if (method == DeliveryMethod.delivery &&
        nextPayment == PaymentMethod.cash) {
      nextPayment = PaymentMethod.cod;
    } else if (method == DeliveryMethod.meetup &&
        nextPayment == PaymentMethod.cod) {
      nextPayment = PaymentMethod.cash;
    }
    state = state.copyWith(
      deliveryMethod: method,
      paymentMethod: nextPayment,
      clearError: true,
    );
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method, clearError: true);
  }

  Future<OrderModel?> submitOrder({
    required String productId,
    String? shippingAddress,
    String? recipientName,
    String? recipientPhone,
    String? meetupLocation,
    String? buyerNote,
    String? conversationId,
  }) async {
    if (state.isSubmitting) return null;

    if (state.deliveryMethod == DeliveryMethod.delivery &&
        (shippingAddress == null || shippingAddress.trim().length < 5)) {
      state = state.copyWith(
        error: const ApiException(
          code: 'VALIDATION_ERROR',
          message: 'Vui lòng nhập địa chỉ nhận hàng cụ thể (tối thiểu 5 ký tự).',
          statusCode: 400,
        ),
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    final res = await orderRepository.createOrder(
      productId: productId,
      deliveryMethod: state.deliveryMethod,
      paymentMethod: state.paymentMethod,
      shippingAddress: shippingAddress,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      meetupLocation: meetupLocation,
      buyerNote: buyerNote,
      conversationId: conversationId,
    );

    OrderModel? created;
    res.when(
      success: (order, _, _) {
        created = order;
        state = state.copyWith(
          isSubmitting: false,
          createdOrder: order,
          clearError: true,
        );
        ref.invalidate(productDetailProvider(productId));
        ref.invalidate(productOrderSummaryProvider(productId));
        ref.invalidate(notificationsProvider);
      },
      failure: (err) {
        state = state.copyWith(isSubmitting: false, error: err);
      },
    );
    return created;
  }
}

final checkoutControllerProvider =
    StateNotifierProvider.autoDispose<CheckoutController, CheckoutState>((ref) {
  return CheckoutController(
    orderRepository: ref.watch(orderRepositoryProvider),
    paymentRepository: ref.watch(paymentRepositoryProvider),
    ref: ref,
  );
});
