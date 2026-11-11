import '../../../../core/network/network_result.dart';
import '../datasources/order_remote_data_source.dart';
import '../models/order_model.dart';

class PaymentRepository {
  const PaymentRepository(this._remoteDataSource);

  final OrderRemoteDataSource _remoteDataSource;

  /// Buyer submits manual bank transfer confirmation (`POST /api/v1/orders/:id/payment-confirmation`).
  Future<NetworkResult<OrderModel>> confirmBuyerPayment(
    String orderId, {
    String? transactionReference,
    String? transferNote,
  }) {
    return _remoteDataSource.confirmBuyerPayment(
      orderId,
      transactionReference: transactionReference,
      transferNote: transferNote,
    );
  }

  /// Seller confirms receiving bank transfer payment (`PATCH /api/v1/orders/:id/payment/confirm`).
  Future<NetworkResult<OrderModel>> confirmSellerPayment(
    String orderId, {
    String? note,
  }) {
    return _remoteDataSource.confirmSellerPayment(orderId, note: note);
  }
}
