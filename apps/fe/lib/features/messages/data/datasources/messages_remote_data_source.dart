import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../models/message_models.dart';

/// Remote data source for Buyer–Seller Messaging (`/api/v1/messages/*`).
class MessagesRemoteDataSource {
  const MessagesRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /api/v1/messages/conversations`
  Future<NetworkResult<ConversationModel>> createOrGetConversation({
    required String productId,
    String? initialMessage,
  }) {
    final payload = <String, dynamic>{
      'productId': productId.trim(),
      if (initialMessage != null && initialMessage.trim().isNotEmpty)
        'initialMessage': initialMessage.trim(),
    };
    return _apiClient.post<ConversationModel>(
      ApiEndpoints.conversations,
      data: payload,
      parser: (rawData) =>
          ConversationModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/messages/conversations`
  Future<NetworkResult<List<ConversationModel>>> getConversations({
    int page = 1,
    int limit = 30,
  }) {
    return _apiClient.get<List<ConversationModel>>(
      ApiEndpoints.conversations,
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(ConversationModel.fromJson)
              .toList(growable: false);
        }
        return const <ConversationModel>[];
      },
    );
  }

  /// `GET /api/v1/messages/conversations/:id`
  Future<NetworkResult<ConversationModel>> getConversationById(
    String conversationId,
  ) {
    return _apiClient.get<ConversationModel>(
      ApiEndpoints.conversationById(conversationId),
      parser: (rawData) =>
          ConversationModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/messages/conversations/:id/messages`
  Future<NetworkResult<List<MessageModel>>> getConversationMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) {
    return _apiClient.get<List<MessageModel>>(
      ApiEndpoints.conversationMessages(conversationId),
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(MessageModel.fromJson)
              .toList(growable: false);
        }
        return const <MessageModel>[];
      },
    );
  }

  /// `POST /api/v1/messages/conversations/:id/messages`
  Future<NetworkResult<MessageModel>> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
  }) {
    return _apiClient.post<MessageModel>(
      ApiEndpoints.conversationMessages(conversationId),
      data: <String, dynamic>{
        'content': content.trim(),
        'messageType': messageType.apiValue,
      },
      parser: (rawData) =>
          MessageModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `PATCH /api/v1/messages/:id/read`
  Future<NetworkResult<MessageModel>> markMessageAsRead(String messageId) {
    return _apiClient.patch<MessageModel>(
      ApiEndpoints.markMessageRead(messageId),
      parser: (rawData) =>
          MessageModel.fromJson(rawData as Map<String, dynamic>),
    );
  }
}
