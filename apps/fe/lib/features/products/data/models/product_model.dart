import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Product condition enum matching `ProductCondition` in NestJS Backend.
enum ProductCondition {
  newItem('NEW', 'Mới 100%', 'Chưa qua sử dụng, nguyên hộp'),
  likeNew('LIKE_NEW', 'Như mới (99%)', 'Hầu như không có vết xước'),
  good('GOOD', 'Tốt (90%)', 'Xước nhẹ ngoài vỏ, hoạt động hoàn hảo'),
  fair('FAIR', 'Khá (80%)', 'Có dấu hiệu hao mòn rõ theo thời gian');

  const ProductCondition(this.apiValue, this.label, this.subtitle);

  final String apiValue;
  final String label;
  final String subtitle;

  String get labelVi => label;
  String get shortLabelVi => label;

  Color get badgeBgColor => switch (this) {
        ProductCondition.newItem => AppColors.successBg,
        ProductCondition.likeNew => AppColors.primaryTintBg,
        ProductCondition.good => const Color(0xFFF1F5F9),
        ProductCondition.fair => AppColors.warningBg,
      };

  Color get badgeTextColor => switch (this) {
        ProductCondition.newItem => AppColors.successText,
        ProductCondition.likeNew => AppColors.primaryDark,
        ProductCondition.good => AppColors.textSecondary,
        ProductCondition.fair => AppColors.warningText,
      };

  static ProductCondition fromApi(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'NEW':
        return ProductCondition.newItem;
      case 'LIKE_NEW':
        return ProductCondition.likeNew;
      case 'FAIR':
        return ProductCondition.fair;
      case 'GOOD':
      default:
        return ProductCondition.good;
    }
  }
}

/// Product status enum matching `ProductStatus` and state machine in NestJS Backend.
enum ProductStatus {
  draft('DRAFT', 'Bản nháp'),
  active('ACTIVE', 'Đang bán'),
  reserved('RESERVED', 'Đã đặt gạch'),
  sold('SOLD', 'Đã bán'),
  archived('ARCHIVED', 'Đã lưu trữ');

  const ProductStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  String get labelVi => label;
  bool get canEditAndDelete => this != ProductStatus.sold;

  /// Mirrors `ProductsService.ALLOWED_STATUS_TRANSITIONS` in NestJS Backend.
  List<ProductStatus> get allowedTransitions => switch (this) {
        ProductStatus.draft => const [
            ProductStatus.active,
            ProductStatus.archived,
          ],
        ProductStatus.active => const [
            ProductStatus.reserved,
            ProductStatus.sold,
            ProductStatus.archived,
            ProductStatus.draft,
          ],
        ProductStatus.reserved => const [
            ProductStatus.active,
            ProductStatus.sold,
            ProductStatus.archived,
          ],
        ProductStatus.sold => const [
            ProductStatus.archived,
          ],
        ProductStatus.archived => const [
            ProductStatus.draft,
            ProductStatus.active,
          ],
      };

  static ProductStatus fromApi(String? raw) {
    switch (raw?.trim().toUpperCase()) {
      case 'DRAFT':
        return ProductStatus.draft;
      case 'RESERVED':
        return ProductStatus.reserved;
      case 'SOLD':
        return ProductStatus.sold;
      case 'ARCHIVED':
        return ProductStatus.archived;
      case 'ACTIVE':
      default:
        return ProductStatus.active;
    }
  }
}

/// Populated seller summary embedded inside `ProductModel`.
class ProductSellerSummary {
  const ProductSellerSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.location,
    this.isEmailVerified = false,
    this.status = 'ACTIVE',
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.completedOrdersCount = 0,
    this.reputationScore = 66,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? location;
  final bool isEmailVerified;
  final String status;
  final double averageRating;
  final int totalReviews;
  final int completedOrdersCount;
  final int reputationScore;

  int get trustScore => reputationScore;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory ProductSellerSummary.fromDynamic(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final repCache = raw['reputationCache'] is Map<String, dynamic>
          ? raw['reputationCache'] as Map<String, dynamic>
          : null;
      final stats = raw['stats'] is Map<String, dynamic>
          ? raw['stats'] as Map<String, dynamic>
          : null;

      return ProductSellerSummary(
        id: (raw['id'] ?? raw['_id'] ?? '').toString(),
        displayName: (raw['displayName'] as String?) ?? 'Người bán ReMarket',
        avatarUrl: raw['avatarUrl'] as String?,
        location: raw['location'] as String?,
        isEmailVerified: (raw['isEmailVerified'] as bool?) ?? false,
        status: (raw['status'] as String?) ?? 'ACTIVE',
        averageRating: ((repCache?['averageRating'] ??
                    stats?['rating'] ??
                    raw['averageRating']) as num?)
                ?.toDouble() ??
            0.0,
        totalReviews: ((repCache?['totalReviews'] ??
                    stats?['totalReviews'] ??
                    raw['totalReviews']) as num?)
                ?.toInt() ??
            0,
        completedOrdersCount: ((repCache?['completedOrdersCount'] ??
                    stats?['completedOrdersCount'] ??
                    stats?['soldListingsCount'] ??
                    raw['completedOrdersCount']) as num?)
                ?.toInt() ??
            0,
        reputationScore: ((repCache?['reputationScore'] ??
                    stats?['reputationScore'] ??
                    raw['reputationScore']) as num?)
                ?.toInt() ??
            66,
      );
    }
    return ProductSellerSummary(
      id: raw?.toString() ?? '',
      displayName: 'Người bán ReMarket',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      '_id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'location': location,
      'isEmailVerified': isEmailVerified,
      'status': status,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'completedOrdersCount': completedOrdersCount,
    };
  }
}

/// Populated category summary embedded inside `ProductModel`.
class ProductCategorySummary {
  const ProductCategorySummary({
    required this.id,
    required this.name,
    this.slug = '',
    this.icon,
  });

  final String id;
  final String name;
  final String slug;
  final String? icon;

  factory ProductCategorySummary.fromDynamic(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return ProductCategorySummary(
        id: (raw['id'] ?? raw['_id'] ?? '').toString(),
        name: (raw['name'] as String?) ?? 'Danh mục',
        slug: (raw['slug'] as String?) ?? '',
        icon: raw['icon'] as String?,
      );
    }
    return ProductCategorySummary(
      id: raw?.toString() ?? '',
      name: 'Danh mục',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      '_id': id,
      'name': name,
      'slug': slug,
      'icon': icon,
    };
  }
}

/// Optional AI metadata stored on a Product document (`Product.aiMetadata`).
class ProductAiMetadata {
  const ProductAiMetadata({
    this.suggestedPriceMin,
    this.suggestedPriceRecommended,
    this.suggestedPriceMax,
    this.aiGeneratedDescription,
    this.priceReasoning,
    this.buyerChecklist = const <String>[],
    this.questionsForSeller = const <String>[],
  });

  final double? suggestedPriceMin;
  final double? suggestedPriceRecommended;
  final double? suggestedPriceMax;
  final String? aiGeneratedDescription;
  final String? priceReasoning;
  final List<String> buyerChecklist;
  final List<String> questionsForSeller;

  factory ProductAiMetadata.fromJson(Map<String, dynamic> json) {
    return ProductAiMetadata(
      suggestedPriceMin: (json['suggestedPriceMin'] as num?)?.toDouble(),
      suggestedPriceRecommended:
          (json['suggestedPriceRecommended'] as num?)?.toDouble(),
      suggestedPriceMax: (json['suggestedPriceMax'] as num?)?.toDouble(),
      aiGeneratedDescription: json['aiGeneratedDescription'] as String?,
      buyerChecklist: (json['buyerChecklist'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      questionsForSeller: (json['questionsForSeller'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (suggestedPriceMin != null) 'suggestedPriceMin': suggestedPriceMin,
      if (suggestedPriceRecommended != null)
        'suggestedPriceRecommended': suggestedPriceRecommended,
      if (suggestedPriceMax != null) 'suggestedPriceMax': suggestedPriceMax,
      if (aiGeneratedDescription != null)
        'aiGeneratedDescription': aiGeneratedDescription,
      'buyerChecklist': buyerChecklist,
      'questionsForSeller': questionsForSeller,
    };
  }
}

/// Core Product model matching `ProductResponseDto` in `docs/api/API_CONTRACT.md`.
class ProductModel {
  const ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.condition,
    this.defectDisclosure = '',
    this.images = const <String>[],
    this.tags = const <String>[],
    required this.status,
    this.location,
    required this.seller,
    required this.category,
    this.aiMetadata,
    this.viewsCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final double? originalPrice;
  final ProductCondition condition;
  final String defectDisclosure;
  final List<String> images;
  final List<String> tags;
  final ProductStatus status;
  final String? location;
  final ProductSellerSummary seller;
  final ProductCategorySummary category;
  final ProductAiMetadata? aiMetadata;
  final int viewsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get primaryImageUrl => images.isNotEmpty ? images.first : null;

  bool get hasTransparentDefectDisclosure =>
      defectDisclosure.trim().isNotEmpty;

  bool get hasDefectDisclosure => hasTransparentDefectDisclosure;
  String get defects => defectDisclosure;
  String get sellerId => seller.id;
  String get categoryId => category.id;

  /// Computes percentage discount relative to `originalPrice` if applicable.
  int? get discountPercent {
    final orig = originalPrice;
    if (orig == null || orig <= 0 || orig <= price) {
      return null;
    }
    return (((orig - price) / orig) * 100).round();
  }

  int? get discountPercentage => discountPercent;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final imageList = rawImages is List
        ? rawImages
            .map((e) {
              if (e is Map<String, dynamic>) {
                return (e['url'] ?? '').toString();
              }
              return e.toString();
            })
            .where((url) => url.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final rawTags = json['tags'];
    final tagList = rawTags is List
        ? rawTags
            .map((e) => e.toString().trim())
            .where((t) => t.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final rawAiMeta = json['aiMetadata'];
    final rawViews = json['viewCount'] ?? json['viewsCount'];
    return ProductModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      condition: ProductCondition.fromApi(json['condition'] as String?),
      defectDisclosure: (json['defectDisclosure'] as String?) ?? '',
      images: imageList,
      tags: tagList,
      status: ProductStatus.fromApi(json['status'] as String?),
      location: json['location'] as String?,
      seller: ProductSellerSummary.fromDynamic(
        json['sellerId'] ?? json['seller'],
      ),
      category: ProductCategorySummary.fromDynamic(
        json['categoryId'] ?? json['category'],
      ),
      aiMetadata: rawAiMeta is Map<String, dynamic>
          ? ProductAiMetadata.fromJson(rawAiMeta)
          : null,
      viewsCount: (rawViews as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      '_id': id,
      'title': title,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'condition': condition.apiValue,
      'defectDisclosure': defectDisclosure,
      'images': images,
      'tags': tags,
      'status': status.apiValue,
      'location': location,
      'sellerId': seller.toJson(),
      'categoryId': category.toJson(),
      if (aiMetadata != null) 'aiMetadata': aiMetadata!.toJson(),
      'viewCount': viewsCount,
      'viewsCount': viewsCount,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}

/// Query filter parameters matching `QueryProductDto` (`GET /api/v1/products`).
class ProductFilterQuery {
  const ProductFilterQuery({
    this.page = 1,
    this.limit = 20,
    this.search,
    this.categoryId,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.sellerId,
    this.status,
    this.sortBy = 'createdAt',
    this.sortOrder = 'desc',
  });

  final int page;
  final int limit;
  final String? search;
  final String? categoryId;
  final ProductCondition? condition;
  final double? minPrice;
  final double? maxPrice;
  final String? sellerId;
  final ProductStatus? status;
  final String sortBy;
  final String sortOrder;

  bool get hasActiveFilters =>
      (search != null && search!.trim().isNotEmpty) ||
      (categoryId != null && categoryId!.trim().isNotEmpty) ||
      condition != null ||
      minPrice != null ||
      maxPrice != null ||
      sortBy != 'createdAt' ||
      sortOrder != 'desc';

  ProductFilterQuery copyWith({
    int? page,
    int? limit,
    String? search,
    bool clearSearch = false,
    String? categoryId,
    bool clearCategory = false,
    ProductCondition? condition,
    bool clearCondition = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    String? sellerId,
    ProductStatus? status,
    bool clearStatus = false,
    String? sortBy,
    String? sortOrder,
  }) {
    return ProductFilterQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: clearSearch ? null : (search ?? this.search),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      condition: clearCondition ? null : (condition ?? this.condition),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      sellerId: sellerId ?? this.sellerId,
      status: clearStatus ? null : (status ?? this.status),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Resolves [sortBy] and [sortOrder] into the NestJS `ProductSortBy` enum
  /// (`newest`, `price_asc`, `price_desc`, `popular`).
  String get resolvedSortParam {
    if (sortBy == 'price_asc' || (sortBy == 'price' && sortOrder == 'asc')) {
      return 'price_asc';
    }
    if (sortBy == 'price_desc' || (sortBy == 'price' && sortOrder == 'desc')) {
      return 'price_desc';
    }
    if (sortBy == 'viewsCount' || sortBy == 'popular') {
      return 'popular';
    }
    return 'newest';
  }

  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
      if (categoryId != null && categoryId!.trim().isNotEmpty)
        'categoryId': categoryId!.trim(),
      if (condition != null) 'condition': condition!.apiValue,
      if (minPrice != null) 'minPrice': minPrice!.round(),
      if (maxPrice != null) 'maxPrice': maxPrice!.round(),
      if (sellerId != null && sellerId!.trim().isNotEmpty)
        'sellerId': sellerId!.trim(),
      if (status != null) 'status': status!.apiValue,
      'sort': resolvedSortParam,
    };
  }
}
