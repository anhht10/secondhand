import 'package:flutter/foundation.dart';

enum ReviewSortOption {
  newest('newest', 'Mới nhất'),
  oldest('oldest', 'Cũ nhất'),
  highest('highest', 'Sao cao nhất'),
  lowest('lowest', 'Sao thấp nhất');

  const ReviewSortOption(this.apiValue, this.labelVi);
  final String apiValue;
  final String labelVi;
}

@immutable
class ReviewParticipantSummary {
  const ReviewParticipantSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.location,
    this.isEmailVerified = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? location;
  final bool isEmailVerified;

  factory ReviewParticipantSummary.fromJson(Map<String, dynamic> json) {
    return ReviewParticipantSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Người dùng ReMarket').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      location: json['location']?.toString(),
      isEmailVerified: json['isEmailVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (location != null) 'location': location,
      'isEmailVerified': isEmailVerified,
    };
  }
}

@immutable
class ReviewProductSummary {
  const ReviewProductSummary({
    required this.id,
    required this.title,
    required this.price,
    this.condition = 'good',
    this.primaryImageUrl,
    this.status = 'sold',
    this.location,
  });

  final String id;
  final String title;
  final double price;
  final String condition;
  final String? primaryImageUrl;
  final String status;
  final String? location;

  factory ReviewProductSummary.fromJson(Map<String, dynamic> json) {
    return ReviewProductSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? 'Sản phẩm').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      condition: (json['condition'] ?? 'good').toString(),
      primaryImageUrl: json['primaryImageUrl']?.toString(),
      status: (json['status'] ?? 'sold').toString(),
      location: json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'price': price,
      'condition': condition,
      if (primaryImageUrl != null) 'primaryImageUrl': primaryImageUrl,
      'status': status,
      if (location != null) 'location': location,
    };
  }
}

@immutable
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    this.buyer,
    this.seller,
    this.product,
    this.images = const <String>[],
    this.sellerReply,
    this.sellerRepliedAt,
    this.status = 'VISIBLE',
    this.reportCount = 0,
    this.canBuyerEdit = false,
    this.canSellerReply = false,
  });

  final String id;
  final String orderId;
  final String buyerId;
  final String sellerId;
  final String productId;
  final ReviewParticipantSummary? buyer;
  final ReviewParticipantSummary? seller;
  final ReviewProductSummary? product;
  final int rating;
  final String comment;
  final List<String> images;
  final String? sellerReply;
  final DateTime? sellerRepliedAt;
  final String status;
  final int reportCount;
  final bool canBuyerEdit;
  final bool canSellerReply;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSellerReply =>
      sellerReply != null && sellerReply!.trim().isNotEmpty;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final rawImages = (json['images'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return ReviewModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      orderId: (json['orderId'] ?? '').toString(),
      buyerId: (json['buyerId'] ?? '').toString(),
      sellerId: (json['sellerId'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      buyer: json['buyer'] is Map<String, dynamic>
          ? ReviewParticipantSummary.fromJson(
              json['buyer'] as Map<String, dynamic>,
            )
          : null,
      seller: json['seller'] is Map<String, dynamic>
          ? ReviewParticipantSummary.fromJson(
              json['seller'] as Map<String, dynamic>,
            )
          : null,
      product: json['product'] is Map<String, dynamic>
          ? ReviewProductSummary.fromJson(
              json['product'] as Map<String, dynamic>,
            )
          : null,
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: (json['comment'] ?? '').toString(),
      images: rawImages,
      sellerReply: json['sellerReply']?.toString(),
      sellerRepliedAt: json['sellerRepliedAt'] != null
          ? DateTime.tryParse(json['sellerRepliedAt'].toString())
          : null,
      status: (json['status'] ?? 'VISIBLE').toString(),
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      canBuyerEdit: json['canBuyerEdit'] == true,
      canSellerReply: json['canSellerReply'] == true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'orderId': orderId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'productId': productId,
      if (buyer != null) 'buyer': buyer!.toJson(),
      if (seller != null) 'seller': seller!.toJson(),
      if (product != null) 'product': product!.toJson(),
      'rating': rating,
      'comment': comment,
      'images': images,
      if (sellerReply != null) 'sellerReply': sellerReply,
      if (sellerRepliedAt != null)
        'sellerRepliedAt': sellerRepliedAt!.toIso8601String(),
      'status': status,
      'reportCount': reportCount,
      'canBuyerEdit': canBuyerEdit,
      'canSellerReply': canSellerReply,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

@immutable
class RatingSummaryModel {
  const RatingSummaryModel({
    this.averageRating = 0,
    this.totalReviews = 0,
    this.star5Count = 0,
    this.star4Count = 0,
    this.star3Count = 0,
    this.star2Count = 0,
    this.star1Count = 0,
    this.ratingDistribution = const <int, int>{
      5: 0,
      4: 0,
      3: 0,
      2: 0,
      1: 0,
    },
  });

  final double averageRating;
  final int totalReviews;
  final int star5Count;
  final int star4Count;
  final int star3Count;
  final int star2Count;
  final int star1Count;
  final Map<int, int> ratingDistribution;

  int countForStar(int star) {
    switch (star) {
      case 5:
        return star5Count;
      case 4:
        return star4Count;
      case 3:
        return star3Count;
      case 2:
        return star2Count;
      case 1:
        return star1Count;
      default:
        return ratingDistribution[star] ?? 0;
    }
  }

  double ratioForStar(int star) {
    if (totalReviews <= 0) return 0;
    return (countForStar(star) / totalReviews).clamp(0.0, 1.0);
  }

  factory RatingSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawDist = json['ratingDistribution'];
    final distMap = <int, int>{
      5: (json['star5Count'] as num?)?.toInt() ?? 0,
      4: (json['star4Count'] as num?)?.toInt() ?? 0,
      3: (json['star3Count'] as num?)?.toInt() ?? 0,
      2: (json['star2Count'] as num?)?.toInt() ?? 0,
      1: (json['star1Count'] as num?)?.toInt() ?? 0,
    };

    if (rawDist is Map) {
      for (final entry in rawDist.entries) {
        final star = int.tryParse(entry.key.toString());
        if (star != null && star >= 1 && star <= 5) {
          distMap[star] = (entry.value as num?)?.toInt() ?? 0;
        }
      }
    }

    return RatingSummaryModel(
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      star5Count: distMap[5] ?? 0,
      star4Count: distMap[4] ?? 0,
      star3Count: distMap[3] ?? 0,
      star2Count: distMap[2] ?? 0,
      star1Count: distMap[1] ?? 0,
      ratingDistribution: distMap,
    );
  }
}

@immutable
class TransactionStatsModel {
  const TransactionStatsModel({
    this.completedOrdersCount = 0,
    this.buyerCancelledOrdersCount = 0,
    this.sellerRejectedOrdersCount = 0,
    this.pendingOrdersCount = 0,
    this.successfulTransactionCount = 0,
    this.successfulTransactionRate = 100.0,
    this.repliedReviewsCount = 0,
    this.sellerReplyRate = 100.0,
  });

  final int completedOrdersCount;
  final int buyerCancelledOrdersCount;
  final int sellerRejectedOrdersCount;
  final int pendingOrdersCount;
  final int successfulTransactionCount;
  final double successfulTransactionRate;
  final int repliedReviewsCount;
  final double sellerReplyRate;

  factory TransactionStatsModel.fromJson(Map<String, dynamic> json) {
    return TransactionStatsModel(
      completedOrdersCount:
          (json['completedOrdersCount'] as num?)?.toInt() ?? 0,
      buyerCancelledOrdersCount:
          (json['buyerCancelledOrdersCount'] as num?)?.toInt() ?? 0,
      sellerRejectedOrdersCount:
          (json['sellerRejectedOrdersCount'] as num?)?.toInt() ?? 0,
      pendingOrdersCount: (json['pendingOrdersCount'] as num?)?.toInt() ?? 0,
      successfulTransactionCount:
          (json['successfulTransactionCount'] as num?)?.toInt() ?? 0,
      successfulTransactionRate:
          (json['successfulTransactionRate'] as num?)?.toDouble() ?? 100.0,
      repliedReviewsCount: (json['repliedReviewsCount'] as num?)?.toInt() ?? 0,
      sellerReplyRate: (json['sellerReplyRate'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

@immutable
class ReputationBreakdownModel {
  const ReputationBreakdownModel({
    this.ratingQualityPoints = 0,
    this.transactionVolumePoints = 0,
    this.fulfillmentReliabilityPoints = 0,
    this.formulaDescription = '',
  });

  final double ratingQualityPoints;
  final double transactionVolumePoints;
  final double fulfillmentReliabilityPoints;
  final String formulaDescription;

  factory ReputationBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ReputationBreakdownModel(
      ratingQualityPoints:
          (json['ratingQualityPoints'] as num?)?.toDouble() ?? 0.0,
      transactionVolumePoints:
          (json['transactionVolumePoints'] as num?)?.toDouble() ?? 0.0,
      fulfillmentReliabilityPoints:
          (json['fulfillmentReliabilityPoints'] as num?)?.toDouble() ?? 0.0,
      formulaDescription: (json['formulaDescription'] ?? '').toString(),
    );
  }
}

@immutable
class SellerReputationModel {
  const SellerReputationModel({
    required this.sellerId,
    this.reputationScore = 66,
    this.reputationTier = 'NEW_SELLER',
    this.averageRating = 0,
    this.ratingSummary = const RatingSummaryModel(),
    this.transactionStats = const TransactionStatsModel(),
    this.breakdown = const ReputationBreakdownModel(),
  });

  final String sellerId;
  final int reputationScore;
  final String reputationTier;
  final double averageRating;
  final RatingSummaryModel ratingSummary;
  final TransactionStatsModel transactionStats;
  final ReputationBreakdownModel breakdown;

  String get tierLabelVi {
    switch (reputationTier) {
      case 'TRUSTED_SELLER':
        return 'Người bán Uy tín cao';
      case 'RELIABLE_SELLER':
        return 'Người bán Đáng tin cậy';
      case 'NEW_SELLER':
        return 'Người bán mới';
      case 'NEEDS_IMPROVEMENT':
      default:
        return 'Cần cải thiện';
    }
  }

  factory SellerReputationModel.fromJson(Map<String, dynamic> json) {
    return SellerReputationModel(
      sellerId: (json['sellerId'] ?? '').toString(),
      reputationScore: (json['reputationScore'] as num?)?.toInt() ?? 66,
      reputationTier: (json['reputationTier'] ?? 'NEW_SELLER').toString(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingSummary: json['ratingSummary'] is Map<String, dynamic>
          ? RatingSummaryModel.fromJson(
              json['ratingSummary'] as Map<String, dynamic>,
            )
          : const RatingSummaryModel(),
      transactionStats: json['transactionStats'] is Map<String, dynamic>
          ? TransactionStatsModel.fromJson(
              json['transactionStats'] as Map<String, dynamic>,
            )
          : const TransactionStatsModel(),
      breakdown: json['breakdown'] is Map<String, dynamic>
          ? ReputationBreakdownModel.fromJson(
              json['breakdown'] as Map<String, dynamic>,
            )
          : const ReputationBreakdownModel(),
    );
  }
}

@immutable
class PaginatedSellerReviewsModel {
  const PaginatedSellerReviewsModel({
    this.items = const <ReviewModel>[],
    this.ratingSummary = const RatingSummaryModel(),
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.totalPages = 1,
    this.hasNextPage = false,
    this.hasPrevPage = false,
  });

  final List<ReviewModel> items;
  final RatingSummaryModel ratingSummary;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  factory PaginatedSellerReviewsModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ReviewModel.fromJson)
        .toList(growable: false);

    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return PaginatedSellerReviewsModel(
      items: rawItems,
      ratingSummary: json['ratingSummary'] is Map<String, dynamic>
          ? RatingSummaryModel.fromJson(
              json['ratingSummary'] as Map<String, dynamic>,
            )
          : const RatingSummaryModel(),
      total: (meta['total'] as num?)?.toInt() ?? rawItems.length,
      page: (meta['page'] as num?)?.toInt() ?? 1,
      limit: (meta['limit'] as num?)?.toInt() ?? 10,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: meta['hasNextPage'] == true,
      hasPrevPage: meta['hasPrevPage'] == true,
    );
  }
}
