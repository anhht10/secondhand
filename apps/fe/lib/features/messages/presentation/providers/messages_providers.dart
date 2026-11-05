import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/messages_remote_data_source.dart';
import '../../data/models/message_models.dart';
import '../../data/repositories/messages_repository.dart';

final messagesRemoteDataSourceProvider =
    Provider<MessagesRemoteDataSource>((ref) {
  return MessagesRemoteDataSource(ref.watch(apiClientProvider));
});

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.watch(messagesRemoteDataSourceProvider));
});

class ConversationsState {
  const ConversationsState({
    this.items = const <ConversationModel>[],
    this.isLoading = false,
    this.error,
  });

  final List<ConversationModel> items;
  final bool isLoading;
  final ApiException? error;

  int get totalUnreadCount =>
      items.fold<int>(0, (sum, conv) => sum + conv.unreadCount);

  int get unreadConversationsCount =>
      items.where((conv) => conv.hasUnread).length;

  bool get hasUnread => totalUnreadCount > 0;

  ConversationsState copyWith({
    List<ConversationModel>? items,
    bool? isLoading,
    ApiException? error,
    bool clearError = false,
  }) {
    return ConversationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ConversationsController extends StateNotifier<ConversationsState> {
  ConversationsController({
    required this.repository,
    bool autoLoad = true,
  }) : super(const ConversationsState()) {
    if (autoLoad) {
      Future<void>.microtask(loadConversations);
      _realtimeTimer = startRealtimePeriodicSync(
        interval: const Duration(seconds: 3),
        onTick: () => loadConversations(silent: true),
      );
    }
  }

  final MessagesRepository repository;
  Timer? _realtimeTimer;

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    final result = await repository.getConversations();
    if (!mounted) return;

    result.when(
      success: (items, _, _) {
        state = state.copyWith(
          items: items,
          isLoading: false,
          clearError: true,
        );
      },
      failure: (error) {
        if (!silent) {
          state = state.copyWith(isLoading: false, error: error);
        }
      },
    );
  }

  void markConversationReadLocally(String conversationId) {
    final updated = state.items.map((c) {
      if (c.id == conversationId && c.unreadCount > 0) {
        return ConversationModel(
          id: c.id,
          buyer: c.buyer,
          seller: c.seller,
          product: c.product,
          activeOrderId: c.activeOrderId,
          lastMessage: c.lastMessage,
          lastMessageAt: c.lastMessageAt,
          unreadCount: 0,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
        );
      }
      return c;
    }).toList();
    state = state.copyWith(items: updated);
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }
}

final conversationsControllerProvider =
    StateNotifierProvider<ConversationsController, ConversationsState>((ref) {
  final authState = ref.watch(authControllerProvider);
  return ConversationsController(
    repository: ref.watch(messagesRepositoryProvider),
    autoLoad: authState.isAuthenticated,
  );
});
