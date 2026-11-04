/// Payment method and status models for ReMarket Orders (`PaymentModel` & `SellerBankInfoModel`).
enum PaymentMethod {
  cash('CASH', 'Tiền mặt trực tiếp', 'Thanh toán trực tiếp khi gặp mặt kiểm tra hàng'),
  cod('COD', 'Thanh toán khi nhận hàng (COD)', 'Trả tiền mặt cho shipper khi nhận và kiểm tra hàng'),
  bankTransfer(
    'BANK_TRANSFER',
    'Chuyển khoản ngân hàng',
    'Chuyển khoản trực tiếp vào tài khoản người bán và gửi xác nhận',
  );

  const PaymentMethod(this.apiValue, this.labelVi, this.subtitleVi);

  final String apiValue;
  final String labelVi;
  final String subtitleVi;

  static PaymentMethod fromApi(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    for (final item in PaymentMethod.values) {
      if (item.apiValue == normalized) return item;
    }
    return PaymentMethod.cash;
  }
}

enum PaymentStatus {
  unpaid('UNPAID', 'Chưa thanh toán'),
  buyerConfirmed('BUYER_CONFIRMED', 'Chờ người bán xác nhận tiền'),
  paid('PAID', 'Đã thanh toán'),
  cancelled('CANCELLED', 'Đã hủy');

  const PaymentStatus(this.apiValue, this.labelVi);

  final String apiValue;
  final String labelVi;

  static PaymentStatus fromApi(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    for (final item in PaymentStatus.values) {
      if (item.apiValue == normalized) return item;
    }
    return PaymentStatus.unpaid;
  }
}

class SellerBankInfoModel {
  const SellerBankInfoModel({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.branch,
    required this.amount,
    required this.transferContent,
  });

  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String? branch;
  final double amount;
  final String transferContent;

  bool get isConfigured =>
      bankName.trim().isNotEmpty &&
      accountNumber.trim().isNotEmpty &&
      accountHolder.trim().isNotEmpty;

  factory SellerBankInfoModel.fromJson(Map<String, dynamic> json) {
    return SellerBankInfoModel(
      bankName: (json['bankName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      accountHolder: (json['accountHolder'] ?? '').toString(),
      branch: json['branch']?.toString(),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0,
      transferContent: (json['transferContent'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountHolder': accountHolder,
        if (branch != null && branch!.trim().isNotEmpty) 'branch': branch,
        'amount': amount,
        'transferContent': transferContent,
      };
}

class PaymentModel {
  const PaymentModel({
    required this.paymentId,
    required this.orderId,
    required this.payerId,
    required this.receiverId,
    required this.method,
    required this.amount,
    required this.status,
    this.transactionReference,
    this.transferNote,
    this.buyerConfirmationAt,
    this.sellerConfirmationAt,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  final String paymentId;
  final String orderId;
  final String payerId;
  final String receiverId;
  final PaymentMethod method;
  final double amount;
  final PaymentStatus status;
  final String? transactionReference;
  final String? transferNote;
  final DateTime? buyerConfirmationAt;
  final DateTime? sellerConfirmationAt;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return PaymentModel(
      paymentId: (json['paymentId'] ?? json['id'] ?? json['_id'] ?? '').toString(),
      orderId: (json['orderId'] ?? '').toString(),
      payerId: (json['payerId'] ?? '').toString(),
      receiverId: (json['receiverId'] ?? '').toString(),
      method: PaymentMethod.fromApi(json['method']?.toString()),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0,
      status: PaymentStatus.fromApi(json['status']?.toString()),
      transactionReference: json['transactionReference']?.toString(),
      transferNote: json['transferNote']?.toString(),
      buyerConfirmationAt: parseDate(json['buyerConfirmationAt']),
      sellerConfirmationAt: parseDate(json['sellerConfirmationAt']),
      paidAt: parseDate(json['paidAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'paymentId': paymentId,
        'orderId': orderId,
        'payerId': payerId,
        'receiverId': receiverId,
        'method': method.apiValue,
        'amount': amount,
        'status': status.apiValue,
        'transactionReference': transactionReference,
        'transferNote': transferNote,
        'buyerConfirmationAt': buyerConfirmationAt?.toIso8601String(),
        'sellerConfirmationAt': sellerConfirmationAt?.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
      };
}
