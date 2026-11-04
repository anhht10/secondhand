import '../../../../core/network/network_result.dart';
import '../datasources/order_remote_data_source.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';

class OrderRepository {
  const OrderRepository(this._remoteDataSource);

  final OrderRemoteDataSource _remoteDataSource;

  Future<NetworkResult<OrderModel>> createOrder({
    required String productId,
    required DeliveryMethod deliveryMethod,
    required PaymentMethod paymentMethod,
    String? shippingAddress,
    String? recipientName,
    String? recipientPhone,
    String? meetupLocation,
    String? buyerNote,
    String? conversationId,
  }) {
    return _remoteDataSource.createOrder(
      productId: productId,
      deliveryMethod: deliveryMethod,
      paymentMethod: paymentMethod,
      shippingAddress: shippingAddress,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      meetupLocation: meetupLocation,
      buyerNote: buyerNote,
      conversationId: conversationId,
    );
  }

  Future<NetworkResult<List<OrderModel>>> getBuyerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) {
    return _remoteDataSource.getBuyerOrders(
      status: status,
      page: page,
      limit: limit,
    );
  }

  Future<NetworkResult<List<OrderModel>>> getSellerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) {
    return _remoteDataSource.getSellerOrders(
      status: status,
      page: page,
      limit: limit,
    );
  }

  Future<NetworkResult<OrderModel>> getOrderById(String orderId) {
    return _remoteDataSource.getOrderById(orderId);
  }

  Future<NetworkResult<OrderModel?>> getLatestOrderByProduct(
    String productId,
  ) {
    return _remoteDataSource.getLatestOrderByProduct(productId);
  }

  Future<NetworkResult<OrderModel>> confirmOrder(
    String orderId, {
    String? note,
  }) {
    return _remoteDataSource.confirmOrder(orderId, note: note);
  }

  Future<NetworkResult<OrderModel>> rejectOrder(
    String orderId, {
    String? reason,
  }) {
    return _remoteDataSource.rejectOrder(orderId, reason: reason);
  }

  Future<NetworkResult<OrderModel>> cancelOrder(
    String orderId, {
    String? reason,
  }) {
    return _remoteDataSource.cancelOrder(orderId, reason: reason);
  }

  Future<NetworkResult<OrderModel>> updateDeliveryStatus(
    String orderId, {
    required String deliveryStatus,
    String? note,
  }) {
    return _remoteDataSource.updateDeliveryStatus(
      orderId,
      deliveryStatus: deliveryStatus,
      note: note,
    );
  }

  Future<NetworkResult<OrderModel>> completeOrder(
    String orderId, {
    String? note,
  }) {
    return _remoteDataSource.completeOrder(orderId, note: note);
  }

  Future<NetworkResult<List<NotificationModel>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) {
    return _remoteDataSource.getNotifications(page: page, limit: limit);
  }

  Future<NetworkResult<NotificationModel>> markNotificationRead(
    String notificationId,
  ) {
    return _remoteDataSource.markNotificationRead(notificationId);
  }

  Future<NetworkResult<void>> markAllNotificationsRead() {
    return _remoteDataSource.markAllNotificationsRead();
  }
}
