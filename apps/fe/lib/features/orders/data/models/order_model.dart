import 'payment_model.dart';

enum DeliveryMethod {
  meetup(
    'MEETUP',
    'Giao dịch trực tiếp',
    'Hẹn gặp kiểm tra sản phẩm trực tiếp tại trường / nơi công cộng',
  ),
  delivery(
    'DELIVERY',
    'Giao hàng tận nơi',
    'Giao hàng tới địa chỉ ký túc xá / nhà riêng của bạn',
  );

  const DeliveryMethod(this.apiValue, this.labelVi, this.subtitleVi);

  final String apiValue;
  final String labelVi;
  final String subtitleVi;

  static DeliveryMethod fromApi(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    for (final item in DeliveryMethod.values) {
      if (item.apiValue == normalized) return item;
    }
    return DeliveryMethod.meetup;
  }
}

enum OrderStatus {
  pending('PENDING', 'Chờ xác nhận'),
  confirmed('CONFIRMED', 'Đã xác nhận'),
  shipping('SHIPPING', 'Đang giao hàng'),
  delivered('DELIVERED', 'Đã giao hàng'),
  completed('COMPLETED', 'Hoàn thành'),
  rejected('REJECTED', 'Đã từ chối'),
  cancelled('CANCELLED', 'Đã hủy');

  const OrderStatus(this.apiValue, this.labelVi);

  final String apiValue;
  final String labelVi;

  static OrderStatus fromApi(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    for (final item in OrderStatus.values) {
      if (item.apiValue == normalized) return item;
    }
    return OrderStatus.pending;
  }
}

class OrderProductSnapshotModel {
  const OrderProductSnapshotModel({
    required this.title,
    required this.price,
    required this.condition,
    this.imageUrl,
    this.location,
  });

  final String title;
  final double price;
  final String condition;
  final String? imageUrl;
  final String? location;

  factory OrderProductSnapshotModel.fromJson(Map<String, dynamic> json) {
    return OrderProductSnapshotModel(
      title: (json['title'] ?? 'Sản phẩm ReMarket').toString(),
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0,
      condition: (json['condition'] ?? 'GOOD').toString(),
      imageUrl: json['imageUrl']?.toString(),
      location: json['location']?.toString(),
    );
  }
}

class OrderPartySummaryModel {
  const OrderPartySummaryModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.phoneNumber,
    this.location,
    this.university,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? location;
  final String? university;

  factory OrderPartySummaryModel.fromJson(Map<String, dynamic> json) {
    return OrderPartySummaryModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Người dùng ReMarket').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      location: json['location']?.toString(),
      university: json['university']?.toString(),
    );
  }
}

class OrderTimelineEntryModel {
  const OrderTimelineEntryModel({
    required this.status,
    required this.actorRole,
    this.note,
    required this.timestamp,
  });

  final String status;
  final String actorRole;
  final String? note;
  final DateTime timestamp;

  factory OrderTimelineEntryModel.fromJson(Map<String, dynamic> json) {
    final tsRaw = json['timestamp']?.toString();
    return OrderTimelineEntryModel(
      status: (json['status'] ?? '').toString(),
      actorRole: (json['actorRole'] ?? 'SYSTEM').toString(),
      note: json['note']?.toString(),
      timestamp:
          (tsRaw != null ? DateTime.tryParse(tsRaw) : null) ?? DateTime.now(),
    );
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    this.conversationId,
    required this.productSnapshot,
    required this.itemPrice,
    required this.shippingFee,
    required this.totalAmount,
    required this.deliveryMethod,
    this.shippingAddress,
    this.recipientName,
    this.recipientPhone,
    this.meetupLocation,
    this.buyerNote,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    this.cancelReason,
    this.rejectReason,
    required this.timeline,
    this.buyer,
    this.seller,
    this.sellerBankInfo,
    this.payment,
    this.reviewId,
    this.hasReview = false,
    required this.createdAt,
    this.confirmedAt,
    this.completedAt,
  });

  final String id;
  final String orderCode;
  final String productId;
  final String buyerId;
  final String sellerId;
  final String? conversationId;
  final OrderProductSnapshotModel productSnapshot;
  final double itemPrice;
  final double shippingFee;
  final double totalAmount;
  final DeliveryMethod deliveryMethod;
  final String? shippingAddress;
  final String? recipientName;
  final String? recipientPhone;
  final String? meetupLocation;
  final String? buyerNote;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final String? cancelReason;
  final String? rejectReason;
  final List<OrderTimelineEntryModel> timeline;
  final OrderPartySummaryModel? buyer;
  final OrderPartySummaryModel? seller;
  final SellerBankInfoModel? sellerBankInfo;
  final PaymentModel? payment;
  final String? reviewId;
  final bool hasReview;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;

  bool get isPending => status == OrderStatus.pending;

  bool get isProcessing =>
      status == OrderStatus.confirmed ||
      status == OrderStatus.shipping ||
      status == OrderStatus.delivered;

  bool get isCompleted => status == OrderStatus.completed;

  bool get isCancelledOrRejected =>
      status == OrderStatus.cancelled || status == OrderStatus.rejected;

  bool get canBuyerReview =>
      status == OrderStatus.completed && !hasReview && reviewId == null;

  bool get canBuyerCancel =>
      (status == OrderStatus.pending || status == OrderStatus.confirmed) &&
      paymentStatus != PaymentStatus.paid;

  bool get canBuyerSubmitTransferConfirmation =>
      paymentMethod == PaymentMethod.bankTransfer &&
      (status == OrderStatus.pending ||
          status == OrderStatus.confirmed ||
          status == OrderStatus.shipping) &&
      paymentStatus == PaymentStatus.unpaid;

  bool get canBuyerComplete =>
      (status == OrderStatus.confirmed ||
          status == OrderStatus.shipping ||
          status == OrderStatus.delivered) &&
      (paymentMethod != PaymentMethod.bankTransfer ||
          paymentStatus == PaymentStatus.paid);

  bool get canSellerConfirm => status == OrderStatus.pending;

  bool get canSellerReject => status == OrderStatus.pending;

  bool get canSellerConfirmPayment =>
      paymentMethod == PaymentMethod.bankTransfer &&
      paymentStatus == PaymentStatus.buyerConfirmed &&
      !isCancelledOrRejected &&
      !isCompleted;

  bool get canSellerUpdateShipping =>
      (status == OrderStatus.confirmed || status == OrderStatus.shipping) &&
      (paymentMethod != PaymentMethod.bankTransfer ||
          paymentStatus == PaymentStatus.paid);

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final rawSnapshot = json['productSnapshot'];
    final snapshot = rawSnapshot is Map<String, dynamic>
        ? OrderProductSnapshotModel.fromJson(rawSnapshot)
        : const OrderProductSnapshotModel(
            title: 'Sản phẩm ReMarket',
            price: 0,
            condition: 'GOOD',
          );

    final rawTimeline = json['timeline'];
    final timelineList = rawTimeline is List
        ? rawTimeline
            .whereType<Map<String, dynamic>>()
            .map(OrderTimelineEntryModel.fromJson)
            .toList()
        : <OrderTimelineEntryModel>[];

    final rawBuyer = json['buyer'];
    final rawSeller = json['seller'];
    final rawBank = json['sellerBankInfo'];
    final rawPayment = json['payment'];

    return OrderModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      orderCode: (json['orderCode'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      buyerId: (json['buyerId'] ?? '').toString(),
      sellerId: (json['sellerId'] ?? '').toString(),
      conversationId: json['conversationId']?.toString(),
      productSnapshot: snapshot,
      itemPrice: (json['itemPrice'] is num)
          ? (json['itemPrice'] as num).toDouble()
          : snapshot.price,
      shippingFee: (json['shippingFee'] is num)
          ? (json['shippingFee'] as num).toDouble()
          : 0,
      totalAmount: (json['totalAmount'] is num)
          ? (json['totalAmount'] as num).toDouble()
          : snapshot.price,
      deliveryMethod:
          DeliveryMethod.fromApi(json['deliveryMethod']?.toString()),
      shippingAddress: json['shippingAddress']?.toString(),
      recipientName: json['recipientName']?.toString(),
      recipientPhone: json['recipientPhone']?.toString(),
      meetupLocation: json['meetupLocation']?.toString(),
      buyerNote: json['buyerNote']?.toString(),
      paymentMethod: PaymentMethod.fromApi(json['paymentMethod']?.toString()),
      paymentStatus: PaymentStatus.fromApi(json['paymentStatus']?.toString()),
      status: OrderStatus.fromApi(json['status']?.toString()),
      cancelReason: json['cancelReason']?.toString(),
      rejectReason: json['rejectReason']?.toString(),
      timeline: timelineList,
      buyer: rawBuyer is Map<String, dynamic>
          ? OrderPartySummaryModel.fromJson(rawBuyer)
          : null,
      seller: rawSeller is Map<String, dynamic>
          ? OrderPartySummaryModel.fromJson(rawSeller)
          : null,
      sellerBankInfo: rawBank is Map<String, dynamic>
          ? SellerBankInfoModel.fromJson(rawBank)
          : null,
      payment: rawPayment is Map<String, dynamic>
          ? PaymentModel.fromJson(rawPayment)
          : null,
      reviewId: json['reviewId']?.toString(),
      hasReview:
          json['hasReview'] == true ||
          (json['reviewId'] != null &&
              json['reviewId'].toString().trim().isNotEmpty),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      confirmedAt: parseDate(json['confirmedAt']),
      completedAt: parseDate(json['completedAt']),
    );
  }
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.productId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? orderId;
  final String? productId;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt']?.toString();
    return NotificationModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      orderId: json['orderId']?.toString(),
      productId: json['productId']?.toString(),
      isRead: json['isRead'] == true,
      createdAt: (createdRaw != null ? DateTime.tryParse(createdRaw) : null) ??
          DateTime.now(),
    );
  }
}
