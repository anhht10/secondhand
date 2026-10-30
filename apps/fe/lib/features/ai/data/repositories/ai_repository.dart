import '../../../../core/network/network_result.dart';
import '../../../products/data/models/product_model.dart';
import '../datasources/ai_remote_data_source.dart';
import '../models/ai_models.dart';

/// Repository for all 4 AI capabilities (`generate-listing`, `estimate-price`,
/// `buyer-checklist`, `chat`).
class AiRepository {
  const AiRepository(this.remoteDataSource);

  final AiRemoteDataSource remoteDataSource;

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
    return remoteDataSource.generateListing(
      title: title,
      brand: brand,
      category: category,
      condition: condition,
      price: price,
      originalPrice: originalPrice,
      defectDisclosure: defectDisclosure,
      imageUrls: imageUrls,
    );
  }

  Future<NetworkResult<AiPriceEstimateModel>> estimatePrice({
    required String title,
    String? brand,
    String? category,
    required ProductCondition condition,
    double? originalPrice,
    String? defectDisclosure,
  }) {
    return remoteDataSource.estimatePrice(
      title: title,
      brand: brand,
      category: category,
      condition: condition,
      originalPrice: originalPrice,
      defectDisclosure: defectDisclosure,
    );
  }

  Future<NetworkResult<AiBuyerChecklistModel>> getBuyerChecklist({
    String? productId,
    String? title,
    String? category,
    ProductCondition? condition,
    double? price,
    String? defectDisclosure,
    bool forceRefresh = false,
  }) {
    return remoteDataSource.getBuyerChecklist(
      productId: productId,
      title: title,
      category: category,
      condition: condition,
      price: price,
      defectDisclosure: defectDisclosure,
      forceRefresh: forceRefresh,
    );
  }

  Future<NetworkResult<AiChatResponseModel>> sendChatMessage({
    required String message,
    String? threadId,
    double? maxBudget,
    String? category,
  }) {
    return remoteDataSource.sendChatMessage(
      message: message,
      threadId: threadId,
      maxBudget: maxBudget,
      category: category,
    );
  }

  Future<NetworkResult<void>> deleteConversation(String conversationId) {
    return remoteDataSource.deleteConversation(conversationId);
  }
}
