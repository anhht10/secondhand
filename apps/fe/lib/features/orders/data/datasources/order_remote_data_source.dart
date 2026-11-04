import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';

class OrderRemoteDataSource {
  const OrderRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /api/v1/orders`
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
    final payload = <String, dynamic>{
      'productId': productId,
      'deliveryMethod': deliveryMethod.apiValue,
      'paymentMethod': paymentMethod.apiValue,
      if (shippingAddress != null && shippingAddress.trim().isNotEmpty)
        'shippingAddress': shippingAddress.trim(),
      if (recipientName != null && recipientName.trim().isNotEmpty)
        'recipientName': recipientName.trim(),
      if (recipientPhone != null && recipientPhone.trim().isNotEmpty)
        'recipientPhone': recipientPhone.trim(),
      if (meetupLocation != null && meetupLocation.trim().isNotEmpty)
        'meetupLocation': meetupLocation.trim(),
      if (buyerNote != null && buyerNote.trim().isNotEmpty)
        'buyerNote': buyerNote.trim(),
      if (conversationId != null && conversationId.trim().isNotEmpty)
        'conversationId': conversationId.trim(),
    };

    return _apiClient.post<OrderModel>(
      ApiEndpoints.orders,
      data: payload,
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/orders/buyer`
  Future<NetworkResult<List<OrderModel>>> getBuyerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) {
    return _apiClient.get<List<OrderModel>>(
      ApiEndpoints.buyerOrders,
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(OrderModel.fromJson)
              .toList(growable: false);
        }
        return const <OrderModel>[];
      },
    );
  }

  /// `GET /api/v1/orders/seller`
  Future<NetworkResult<List<OrderModel>>> getSellerOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) {
    return _apiClient.get<List<OrderModel>>(
      ApiEndpoints.sellerOrders,
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(OrderModel.fromJson)
              .toList(growable: false);
        }
        return const <OrderModel>[];
      },
    );
  }

  /// `GET /api/v1/orders/:id`
  Future<NetworkResult<OrderModel>> getOrderById(String orderId) {
    return _apiClient.get<OrderModel>(
      ApiEndpoints.orderById(orderId),
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/orders/by-product/:productId`
  Future<NetworkResult<OrderModel?>> getLatestOrderByProduct(String productId) {
    return _apiClient.get<OrderModel?>(
      ApiEndpoints.orderByProduct(productId),
      parser: (rawData) {
        if (rawData is Map<String, dynamic> && rawData.isNotEmpty) {
          return OrderModel.fromJson(rawData);
        }
        return null;
      },
    );
  }

  /// `PATCH /api/v1/orders/:id/confirm`
  Future<NetworkResult<OrderModel>> confirmOrder(
    String orderId, {
    String? note,
  }) {
    return _apiClient.patch<OrderModel>(
      ApiEndpoints.confirmOrder(orderId),
      data: <String, dynamic>{
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/orders/:id/reject`
  Future<NetworkResult<OrderModel>> rejectOrder(
    String orderId, {
    String? reason,
  }) {
    return _apiClient.patch<OrderModel>(
      ApiEndpoints.rejectOrder(orderId),
      data: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/orders/:id/cancel`
  Future<NetworkResult<OrderModel>> cancelOrder(
    String orderId, {
    String? reason,
  }) {
    return _apiClient.patch<OrderModel>(
      ApiEndpoints.cancelOrder(orderId),
      data: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/orders/:id/delivery`
  Future<NetworkResult<OrderModel>> updateDeliveryStatus(
    String orderId, {
    required String deliveryStatus,
    String? note,
  }) {
    return _apiClient.patch<OrderModel>(
      ApiEndpoints.updateOrderDelivery(orderId),
      data: <String, dynamic>{
        'deliveryStatus': deliveryStatus,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/orders/:id/complete`
  Future<NetworkResult<OrderModel>> completeOrder(
    String orderId, {
    String? note,
  }) {
    return _apiClient.patch<OrderModel>(
      ApiEndpoints.completeOrder(orderId),
      data: <String, dynamic>{
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/orders/:id/payment-confirmation`
  Future<NetworkResult<OrderModel>> confirmBuyerPayment(
    String orderId, {
    String? transactionReference,
    String? transferNote,
  }) {
    return _apiClient.post<OrderModel>(
      ApiEndpoints.confirmBuyerPayment(orderId),
      data: <String, dynamic>{
        if (transactionReference != null &&
            transactionReference.trim().isNotEmpty)
          'transactionReference': transactionReference.trim(),
        if (transferNote != null && transferNote.trim().isNotEmpty)
          'transferNote': transferNote.trim(),
      },
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/orders/:id/payment/confirm`
  Future<NetworkResult<OrderModel>> confirmSellerPayment(
    String orderId, {
    String? note,
  }) {
    return _apiClient.patch<OrderModel>(
      ApiEndpoints.confirmSellerPayment(orderId),
      data: <String, dynamic>{
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      parser: (rawData) => OrderModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/notifications`
  Future<NetworkResult<List<NotificationModel>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) {
    return _apiClient.get<List<NotificationModel>>(
      ApiEndpoints.notifications,
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(NotificationModel.fromJson)
              .toList(growable: false);
        }
        return const <NotificationModel>[];
      },
    );
  }

  /// `PATCH /api/v1/notifications/:id/read`
  Future<NetworkResult<NotificationModel>> markNotificationRead(
    String notificationId,
  ) {
    return _apiClient.patch<NotificationModel>(
      ApiEndpoints.notificationRead(notificationId),
      data: const <String, dynamic>{},
      parser: (rawData) =>
          NotificationModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/notifications/read-all`
  Future<NetworkResult<void>> markAllNotificationsRead() {
    return _apiClient.patch<void>(
      ApiEndpoints.notificationsReadAll,
      data: const <String, dynamic>{},
      parser: (_) {},
    );
  }
}
