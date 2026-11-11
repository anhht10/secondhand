import '../../../../core/network/network_result.dart';
import '../datasources/messages_remote_data_source.dart';
import '../models/message_models.dart';

/// Repository for Buyer–Seller Messaging (`/api/v1/messages/*`).
class MessagesRepository {
  const MessagesRepository(this.remoteDataSource);

  final MessagesRemoteDataSource remoteDataSource;

  Future<NetworkResult<ConversationModel>> createOrGetConversation({
    required String productId,
    String? initialMessage,
  }) {
    return remoteDataSource.createOrGetConversation(
      productId: productId,
      initialMessage: initialMessage,
    );
  }

  Future<NetworkResult<List<ConversationModel>>> getConversations({
    int page = 1,
    int limit = 30,
  }) {
    return remoteDataSource.getConversations(page: page, limit: limit);
  }

  Future<NetworkResult<ConversationModel>> getConversationById(
    String conversationId,
  ) {
    return remoteDataSource.getConversationById(conversationId);
  }

  Future<NetworkResult<List<MessageModel>>> getConversationMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) {
    return remoteDataSource.getConversationMessages(
      conversationId,
      page: page,
      limit: limit,
    );
  }

  Future<NetworkResult<MessageModel>> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
  }) {
    return remoteDataSource.sendMessage(
      conversationId: conversationId,
      content: content,
      messageType: messageType,
    );
  }

  Future<NetworkResult<MessageModel>> markMessageAsRead(String messageId) {
    return remoteDataSource.markMessageAsRead(messageId);
  }
}
