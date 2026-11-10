import '../../../products/data/models/product_model.dart';

/// Local listing draft model persisted in `SharedPreferences` (`F09 - Local Draft Saving`).
class ListingDraftModel {
  const ListingDraftModel({
    this.title = '',
    this.brand = '',
    this.categoryId,
    this.categoryName = '',
    this.condition = ProductCondition.likeNew,
    this.priceText = '',
    this.originalPriceText = '',
    this.defectDisclosure = '',
    this.description = '',
    this.location = '',
    this.uploadedImageUrls = const <String>[],
    this.aiTransparencyNote,
    this.aiTags = const <String>[],
    this.aiQuickSellPrice,
    this.aiRecommendedPrice,
    this.aiMaxFairPrice,
    this.updatedAt,
  });

  final String title;
  final String brand;
  final String? categoryId;
  final String categoryName;
  final ProductCondition condition;
  final String priceText;
  final String originalPriceText;
  final String defectDisclosure;
  final String description;
  final String location;
  final List<String> uploadedImageUrls;
  final String? aiTransparencyNote;
  final List<String> aiTags;
  final double? aiQuickSellPrice;
  final double? aiRecommendedPrice;
  final double? aiMaxFairPrice;
  final DateTime? updatedAt;

  bool get isNotEmpty =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      defectDisclosure.trim().isNotEmpty ||
      priceText.trim().isNotEmpty ||
      uploadedImageUrls.isNotEmpty;

  factory ListingDraftModel.fromJson(Map<String, dynamic> json) {
    return ListingDraftModel(
      title: (json['title'] as String?) ?? '',
      brand: (json['brand'] as String?) ?? '',
      categoryId: json['categoryId'] as String?,
      categoryName: (json['categoryName'] as String?) ?? '',
      condition: ProductCondition.fromApi(json['condition'] as String?),
      priceText: (json['priceText'] as String?) ?? '',
      originalPriceText: (json['originalPriceText'] as String?) ?? '',
      defectDisclosure: (json['defectDisclosure'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      uploadedImageUrls: (json['uploadedImageUrls'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      aiTransparencyNote: json['aiTransparencyNote'] as String?,
      aiTags: (json['aiTags'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      aiQuickSellPrice: (json['aiQuickSellPrice'] as num?)?.toDouble(),
      aiRecommendedPrice: (json['aiRecommendedPrice'] as num?)?.toDouble(),
      aiMaxFairPrice: (json['aiMaxFairPrice'] as num?)?.toDouble(),
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'brand': brand,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'condition': condition.apiValue,
      'priceText': priceText,
      'originalPriceText': originalPriceText,
      'defectDisclosure': defectDisclosure,
      'description': description,
      'location': location,
      'uploadedImageUrls': uploadedImageUrls,
      'aiTransparencyNote': aiTransparencyNote,
      'aiTags': aiTags,
      'aiQuickSellPrice': aiQuickSellPrice,
      'aiRecommendedPrice': aiRecommendedPrice,
      'aiMaxFairPrice': aiMaxFairPrice,
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }
}
