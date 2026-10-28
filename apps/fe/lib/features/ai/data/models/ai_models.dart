import '../../../products/data/models/product_model.dart';

/// Response model for `POST /api/v1/ai/generate-listing` (`AI 1`).
///
/// Mirrors `GeneratedListingResponseDto` in `docs/api/AI_API_CONTRACT.md`.
class AiGeneratedListingModel {
  const AiGeneratedListingModel({
    required this.suggestedTitle,
    required this.description,
    required this.suggestedCategory,
    this.tags = const <String>[],
    this.highlights = const <String>[],
    this.transparencyNote = '',
    this.conditionTips = const <String>[],
    this.model = 'gemini-3.8-flash',
  });

  final String suggestedTitle;
  final String description;
  final String suggestedCategory;
  final List<String> tags;
  final List<String> highlights;
  final String transparencyNote;
  final List<String> conditionTips;
  final String model;

  String get title => suggestedTitle;

  factory AiGeneratedListingModel.fromJson(Map<String, dynamic> json) {
    final rawTips = json['ConditionTips'] ??
        json['condition_tips'] ??
        json['clarificationQuestions'] ??
        json['clarification_questions'];
    final rawTags =
        json['tags'] ?? json['suggestedTags'] ?? json['suggested_tags'];
    String resolvedDescription =
        (json['suggestedDescriptionText'] ?? json['description'] ?? '')
            .toString();
    if (resolvedDescription.trim().isEmpty &&
        json['suggestedDescription'] is Map<String, dynamic>) {
      final descMap = json['suggestedDescription'] as Map<String, dynamic>;
      final parts = <String>[
        if ((descMap['overview'] ?? '').toString().trim().isNotEmpty)
          '【1. Tổng quan】\n${descMap['overview']}',
        if ((descMap['condition'] ?? '').toString().trim().isNotEmpty)
          '【2. Tình trạng thực tế】\n${descMap['condition']}',
        if ((descMap['defects'] ?? '').toString().trim().isNotEmpty)
          '【3. Lỗi & Khuyết điểm】\n${descMap['defects']}',
      ];
      resolvedDescription = parts.join('\n\n');
    }

    return AiGeneratedListingModel(
      suggestedTitle:
          (json['suggestedTitle'] ?? json['suggested_title'] ?? '').toString(),
      description: resolvedDescription,
      suggestedCategory:
          (json['suggestedCategory'] ?? json['suggested_category'] ?? '')
              .toString(),
      tags: rawTags is List
          ? rawTags.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      highlights: (json['highlights'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      transparencyNote:
          (json['transparencyNote'] ?? json['suggestedCategoryReason'] ?? '')
              .toString(),
      conditionTips: rawTips is List
          ? rawTips.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      model: (json['model'] as String?) ?? 'gemini-3.8-flash',
    );
  }
}

/// Comparable active marketplace item returned in `POST /api/v1/ai/estimate-price`.
class AiComparableProductModel {
  const AiComparableProductModel({
    required this.id,
    required this.title,
    required this.price,
    required this.condition,
  });

  final String id;
  final String title;
  final double price;
  final String condition;

  factory AiComparableProductModel.fromJson(Map<String, dynamic> json) {
    return AiComparableProductModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      condition: (json['condition'] as String?) ?? 'GOOD',
    );
  }
}

/// Response model for `POST /api/v1/ai/estimate-price` (`AI 2`).
///
/// Mirrors `EstimatedPriceResponseDto` in `docs/api/AI_API_CONTRACT.md`.
class AiPriceEstimateModel {
  const AiPriceEstimateModel({
    required this.quickSellPrice,
    required this.recommendedPrice,
    required this.maxFairPrice,
    required this.confidence,
    required this.reasoning,
    this.factors = const <String>[],
    this.comparableProducts = const <AiComparableProductModel>[],
    this.model = 'gemini-3.8-flash',
  });

  final double quickSellPrice;
  final double recommendedPrice;
  final double maxFairPrice;
  final double confidence;
  final String reasoning;
  final List<String> factors;
  final List<AiComparableProductModel> comparableProducts;
  final String model;

  String get confidenceLabelVi =>
      confidence >= 0.75 ? 'Độ tin cậy cao' : 'Độ tin cậy trung bình';

  static double _parseConfidence(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final upper = raw.trim().toUpperCase();
      if (upper == 'HIGH') return 0.9;
      if (upper == 'MEDIUM') return 0.7;
      if (upper == 'LOW') return 0.45;
      final parsed = double.tryParse(raw.trim());
      if (parsed != null) return parsed;
    }
    return 0.8;
  }

  factory AiPriceEstimateModel.fromJson(Map<String, dynamic> json) {
    final rawQuick = json['quickSellPrice'] ??
        json['quick_sell_price'] ??
        json['minPrice'] ??
        0;
    final rawRec = json['recommendedPrice'] ??
        json['recommended_price'] ??
        json['suggestedPrice'] ??
        0;
    final rawMax =
        json['maxFairPrice'] ?? json['max_fair_price'] ?? json['maxPrice'] ?? 0;
    final rawComparables =
        json['comparableProducts'] ?? json['marketComparables'];

    return AiPriceEstimateModel(
      quickSellPrice: (rawQuick as num).toDouble(),
      recommendedPrice: (rawRec as num).toDouble(),
      maxFairPrice: (rawMax as num).toDouble(),
      confidence: _parseConfidence(json['confidence']),
      reasoning: (json['reasoning'] as String?) ?? '',
      factors: (json['factors'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      comparableProducts: rawComparables is List
          ? rawComparables
              .whereType<Map<String, dynamic>>()
              .map(AiComparableProductModel.fromJson)
              .toList(growable: false)
          : const <AiComparableProductModel>[],
      model: (json['model'] as String?) ?? 'gemini-3.8-flash',
    );
  }
}

/// Response model for `POST /api/v1/ai/buyer-checklist` (`AI 3`).
///
/// Mirrors `BuyerChecklistResponseDto` in `docs/api/AI_API_CONTRACT.md`.
class AiBuyerChecklistModel {
  const AiBuyerChecklistModel({
    this.productId,
    required this.checklist,
    required this.questionsForSeller,
    this.riskNotes = const <String>[],
    this.inspectionSummary = '',
    this.cached = false,
    this.model = 'gemini-3.8-flash',
  });

  final String? productId;
  final List<String> checklist;
  final List<String> questionsForSeller;
  final List<String> riskNotes;
  final String inspectionSummary;
  final bool cached;
  final String model;

  bool get recommendedExpandedView => riskNotes.isNotEmpty;

  factory AiBuyerChecklistModel.fromJson(Map<String, dynamic> json) {
    final rawChecklist = json['checklist'] ?? json['inspectionPoints'];
    final parsedChecklist = rawChecklist is List
        ? rawChecklist
            .map((item) {
              if (item is Map<String, dynamic>) {
                final title = (item['title'] ?? '').toString().trim();
                final desc = (item['description'] ?? '').toString().trim();
                if (title.isNotEmpty && desc.isNotEmpty) {
                  return '$title: $desc';
                }
                return title.isNotEmpty ? title : desc;
              }
              return item.toString();
            })
            .where((s) => s.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final rawQuestions = json['questionsForSeller'] ??
        json['suggestedQuestions'] ??
        json['suggested_questions'];
    final rawRisks = json['riskNotes'] ??
        json['risk_notes'] ??
        json['safetyTips'] ??
        json['redFlags'];

    return AiBuyerChecklistModel(
      productId: json['productId']?.toString(),
      checklist: parsedChecklist,
      questionsForSeller: rawQuestions is List
          ? rawQuestions.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      riskNotes: rawRisks is List
          ? rawRisks.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      inspectionSummary: (json['inspectionSummary'] as String?) ?? '',
      cached: (json['cached'] as bool?) ?? false,
      model: (json['model'] as String?) ?? 'gemini-3.8-flash',
    );
  }
}

/// Response model for `POST /api/v1/ai/chat` (`AI 4`).
///
/// Mirrors `AiChatResponseDto` in `docs/api/AI_API_CONTRACT.md`.
class AiChatResponseModel {
  const AiChatResponseModel({
    required this.reply,
    required this.threadId,
    this.toolsUsed = const <String>[],
    this.matchedProducts = const <ProductModel>[],
    this.followUpQuestions = const <String>[],
    this.model = 'gemini-3.8-flash',
  });

  final String reply;
  final String threadId;
  final List<String> toolsUsed;
  final List<ProductModel> matchedProducts;
  final List<String> followUpQuestions;
  final String model;

  factory AiChatResponseModel.fromJson(Map<String, dynamic> json) {
    final rawMatched = json['matchedProducts'] ??
        json['recommended_products'] ??
        json['referencedProducts'];
    final rawTools =
        json['tools_used'] ?? json['toolsUsed'] ?? json['sources'];
    final rawFollowUps = json['follow_up_questions'] ??
        json['followUpQuestions'] ??
        json['suggestedActions'] ??
        json['suggestedFollowUps'];

    return AiChatResponseModel(
      reply:
          (json['reply'] ?? json['message'] ?? json['response'] ?? '')
              .toString(),
      threadId: (json['thread_id'] ??
              json['threadId'] ??
              json['conversation_id'] ??
              json['interactionId'] ??
              '')
          .toString(),
      toolsUsed: rawTools is List
          ? rawTools.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      matchedProducts: rawMatched is List
          ? rawMatched
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList(growable: false)
          : const <ProductModel>[],
      followUpQuestions: rawFollowUps is List
          ? rawFollowUps.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      model: (json['model'] as String?) ?? 'gemini-3.8-flash',
    );
  }
}

/// Single chat turn displayed in the AI Shopping Assistant UI (`17 - AI Shopping Chatbot`).
class AiChatTurn {
  const AiChatTurn({
    required this.isUser,
    required this.text,
    this.matchedProducts = const <ProductModel>[],
    this.toolsUsed = const <String>[],
    required this.timestamp,
  });

  final bool isUser;
  final String text;
  final List<ProductModel> matchedProducts;
  final List<String> toolsUsed;
  final DateTime timestamp;
}
