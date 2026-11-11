import '../../../products/data/models/product_model.dart';

enum MessageType {
  text('TEXT'),
  image('IMAGE'),
  order('ORDER'),
  system('SYSTEM');

  const MessageType(this.apiValue);
  final String apiValue;

  static MessageType fromApi(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'IMAGE':
        return MessageType.image;
      case 'ORDER':
        return MessageType.order;
      case 'SYSTEM':
        return MessageType.system;
      case 'TEXT':
      default:
        return MessageType.text;
    }
  }
}

/// Product summary embedded inside a `ConversationModel` or `ReportModel`.
class ConversationProductSummary {
  const ConversationProductSummary({
    required this.id,
    required this.title,
    required this.price,
    required this.condition,
    required this.status,
    this.images = const <String>[],
    this.location,
  });

  final String id;
  final String title;
  final double price;
  final ProductCondition condition;
  final ProductStatus status;
  final List<String> images;
  final String? location;

  String? get primaryImageUrl => images.isNotEmpty ? images.first : null;

  factory ConversationProductSummary.fromDynamic(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return ConversationProductSummary(
        id: (raw['id'] ?? raw['_id'] ?? '').toString(),
        title: (raw['title'] as String?) ?? 'Sản phẩm ReMarket',
        price: (raw['price'] as num?)?.toDouble() ?? 0,
        condition: ProductCondition.fromApi(raw['condition'] as String?),
        status: ProductStatus.fromApi(raw['status'] as String?),
        images: (raw['images'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const <String>[],
        location: raw['location'] as String?,
      );
    }
    return ConversationProductSummary(
      id: raw?.toString() ?? '',
      title: 'Sản phẩm ReMarket',
      price: 0,
      condition: ProductCondition.good,
      status: ProductStatus.active,
    );
  }
}

/// Buyer–Seller Conversation model (`GET /api/v1/messages/conversations`).
class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.buyer,
    required this.seller,
    required this.product,
    this.activeOrderId,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ProductSellerSummary buyer;
  final ProductSellerSummary seller;
  final ConversationProductSummary product;
  final String? activeOrderId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasUnread => unreadCount > 0;

  /// Returns the counterpart user (`buyer` or `seller`) relative to [currentUserId].
  ProductSellerSummary counterpartFor(String currentUserId) {
    if (buyer.id == currentUserId) {
      return seller;
    }
    return buyer;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final rawActiveOrder = json['activeOrderId'];
    String? activeOrderId;
    if (rawActiveOrder is Map<String, dynamic>) {
      activeOrderId = (rawActiveOrder['id'] ?? rawActiveOrder['_id'])?.toString();
    } else if (rawActiveOrder != null) {
      activeOrderId = rawActiveOrder.toString();
    }

    final parsedUnreadCount = (json['unreadCount'] as num?)?.toInt() ??
        (json['hasUnread'] == true ? 1 : 0);

    return ConversationModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      buyer: ProductSellerSummary.fromDynamic(json['buyerId']),
      seller: ProductSellerSummary.fromDynamic(json['sellerId']),
      product: ConversationProductSummary.fromDynamic(json['productId']),
      activeOrderId: activeOrderId,
      lastMessage: json['lastMessage'] as String?,
      lastMessageAt: json['lastMessageAt'] is String
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
      unreadCount: parsedUnreadCount,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Individual Message model (`GET/POST /api/v1/messages/conversations/:id/messages`).
class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.content,
    this.messageType = MessageType.text,
    this.orderId,
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final MessageType messageType;
  final String? orderId;
  final bool isRead;
  final DateTime? createdAt;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawSender = json['senderId'];
    String senderId = '';
    String senderName = 'Thành viên';
    String? senderAvatar;
    if (rawSender is Map<String, dynamic>) {
      senderId = (rawSender['id'] ?? rawSender['_id'] ?? '').toString();
      senderName = (rawSender['displayName'] as String?) ?? 'Thành viên';
      senderAvatar = rawSender['avatarUrl'] as String?;
    } else if (rawSender != null) {
      senderId = rawSender.toString();
    }

    final rawOrder = json['orderId'];
    String? orderId;
    if (rawOrder is Map<String, dynamic>) {
      orderId = (rawOrder['id'] ?? rawOrder['_id'])?.toString();
    } else if (rawOrder != null) {
      orderId = rawOrder.toString();
    }

    return MessageModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatar,
      content: (json['content'] as String?) ?? '',
      messageType: MessageType.fromApi(json['messageType'] as String?),
      orderId: orderId,
      isRead: (json['isRead'] as bool?) ?? false,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
