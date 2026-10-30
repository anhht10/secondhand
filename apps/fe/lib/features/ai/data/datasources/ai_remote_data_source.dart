import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../../../products/data/models/product_model.dart';
import '../models/ai_models.dart';

/// Remote data source for the 4 AI features proxied via NestJS (`/api/v1/ai/*`).
///
/// Strictly calls NestJS Gateway (`:3000/api/v1/ai/*`); never calls FastAPI (`:8000`) directly.
class AiRemoteDataSource {
  const AiRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /api/v1/ai/generate-listing` (`AI 1`)
  Future<NetworkResult<AiGeneratedListingModel>> generateListing({
    required String title,
    String? brand,
    String? category,
    required ProductCondition condition,
    double? price,
    double? originalPrice,
    String? defectDisclosure,
    List<String> imageUrls = const <String>[],
  }) {
    final payload = <String, dynamic>{
      'title': title.trim(),
      if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      'condition': condition.apiValue,
      if (price != null && price > 0) 'price': price.round(),
      if (originalPrice != null && originalPrice > 0)
        'originalPrice': originalPrice.round(),
      if (defectDisclosure != null && defectDisclosure.trim().isNotEmpty)
        'defectDisclosure': defectDisclosure.trim(),
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
    };

    return _apiClient.post<AiGeneratedListingModel>(
      ApiEndpoints.aiGenerateListing,
      data: payload,
      parser: (rawData) =>
          AiGeneratedListingModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/ai/estimate-price` (`AI 2`)
  Future<NetworkResult<AiPriceEstimateModel>> estimatePrice({
    required String title,
    String? brand,
    String? category,
    required ProductCondition condition,
    double? originalPrice,
    String? defectDisclosure,
  }) {
    final payload = <String, dynamic>{
      'title': title.trim(),
      if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      'condition': condition.apiValue,
      if (originalPrice != null && originalPrice > 0)
        'originalPrice': originalPrice.round(),
      if (defectDisclosure != null && defectDisclosure.trim().isNotEmpty)
        'defectDisclosure': defectDisclosure.trim(),
    };

    return _apiClient.post<AiPriceEstimateModel>(
      ApiEndpoints.aiEstimatePrice,
      data: payload,
      parser: (rawData) =>
          AiPriceEstimateModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/ai/buyer-checklist` (`AI 3`)
  Future<NetworkResult<AiBuyerChecklistModel>> getBuyerChecklist({
    String? productId,
    String? title,
    String? category,
    ProductCondition? condition,
    double? price,
    String? defectDisclosure,
    bool forceRefresh = false,
  }) {
    final payload = <String, dynamic>{
      if (productId != null && productId.trim().isNotEmpty)
        'productId': productId.trim(),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (condition != null) 'condition': condition.apiValue,
      if (price != null && price > 0) 'price': price.round(),
      if (defectDisclosure != null && defectDisclosure.trim().isNotEmpty)
        'defectDisclosure': defectDisclosure.trim(),
      'forceRefresh': forceRefresh,
    };

    return _apiClient.post<AiBuyerChecklistModel>(
      ApiEndpoints.aiBuyerChecklist,
      data: payload,
      parser: (rawData) =>
          AiBuyerChecklistModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/ai/chat` (`AI 4`)
  Future<NetworkResult<AiChatResponseModel>> sendChatMessage({
    required String message,
    String? threadId,
    double? maxBudget,
    String? category,
  }) {
    final payload = <String, dynamic>{
      'message': message.trim(),
      if (threadId != null && threadId.trim().isNotEmpty)
        'thread_id': threadId.trim(),
      if (maxBudget != null && maxBudget > 0) 'maxBudget': maxBudget.round(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
    };

    return _apiClient.post<AiChatResponseModel>(
      ApiEndpoints.aiChat,
      data: payload,
      parser: (rawData) =>
          AiChatResponseModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `DELETE /api/v1/ai/conversations/:conversationId`
  Future<NetworkResult<void>> deleteConversation(String conversationId) {
    return _apiClient.delete<void>(
      ApiEndpoints.aiConversationById(conversationId),
      parser: (_) {},
    );
  }
}
