import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../products/data/models/product_model.dart';
import '../../data/datasources/ai_remote_data_source.dart';
import '../../data/models/ai_models.dart';
import '../../data/repositories/ai_repository.dart';

final aiRemoteDataSourceProvider = Provider<AiRemoteDataSource>((ref) {
  return AiRemoteDataSource(ref.watch(apiClientProvider));
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(aiRemoteDataSourceProvider));
});

/// Fetches or generates the AI Buyer Inspection Checklist (`POST /api/v1/ai/buyer-checklist`)
/// for a given `productId`.
final buyerChecklistProvider =
    FutureProvider.family<AiBuyerChecklistModel, String>((ref, productId) async {
  final repo = ref.watch(aiRepositoryProvider);
  final result = await repo.getBuyerChecklist(productId: productId);
  return result.when(
    success: (checklist, _, _) => checklist,
    failure: (error) => throw error,
  );
});

/// State for the Multi-turn AI Shopping Assistant (`POST /api/v1/ai/chat`).
class AiChatState {
  const AiChatState({
    this.turns = const <AiChatTurn>[],
    this.threadId,
    this.focusedProduct,
    this.followUpQuestions = const <String>[
      'Tìm bàn phím cơ hoặc phụ kiện máy tính dưới 2 triệu',
      'Gợi ý tai nghe chống ồn tình trạng Như mới',
      'Mẹo kiểm tra đồ điện tử cũ khi giao dịch trực tiếp',
    ],
    this.isSending = false,
    this.error,
  });

  final List<AiChatTurn> turns;
  final String? threadId;
  final ProductModel? focusedProduct;
  final List<String> followUpQuestions;
  final bool isSending;
  final ApiException? error;

  AiChatState copyWith({
    List<AiChatTurn>? turns,
    String? threadId,
    bool clearThreadId = false,
    ProductModel? focusedProduct,
    bool clearFocusedProduct = false,
    List<String>? followUpQuestions,
    bool? isSending,
    ApiException? error,
    bool clearError = false,
  }) {
    return AiChatState(
      turns: turns ?? this.turns,
      threadId: clearThreadId ? null : (threadId ?? this.threadId),
      focusedProduct:
          clearFocusedProduct ? null : (focusedProduct ?? this.focusedProduct),
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages multi-turn conversation with the LangGraph Shopping Assistant.
class AiChatController extends StateNotifier<AiChatState> {
  AiChatController({required this.repository}) : super(const AiChatState());

  final AiRepository repository;

  /// Attaches [product] from `ProductDetailScreen` into the AI chat and
  /// immediately asks Gemini AI to evaluate the item for the buyer.
  Future<void> askAboutProduct(ProductModel product) async {
    final priceStr = AppFormatters.formatVnd(product.price);
    final defectStr = product.hasDefectDisclosure
        ? product.defects
        : 'Người bán cam kết không có lỗi/trầy xước';

    state = state.copyWith(
      focusedProduct: product,
      followUpQuestions: <String>[
        'Mức giá $priceStr cho "${product.title}" có hợp lý không?',
        'Cần kiểm tra kỹ những gì với tình trạng: $defectStr?',
        'Tìm các sản phẩm tương tự "${product.title}" để so sánh',
      ],
      clearError: true,
    );

    final displayQuestion =
        'Tư vấn giúp mình sản phẩm "${product.title}" (Giá: $priceStr, Tình trạng: ${product.condition.labelVi}) xem có đáng mua không và cần lưu ý gì?';

    final categoryParam = product.category.slug.isNotEmpty
        ? product.category.slug
        : product.category.id;

    await sendMessage(
      displayQuestion,
      category: categoryParam.isNotEmpty ? categoryParam : null,
    );
  }

  /// Clears the currently attached product context without wiping the chat history.
  void clearFocusedProduct() {
    state = state.copyWith(
      clearFocusedProduct: true,
      followUpQuestions: const <String>[
        'Tìm bàn phím cơ hoặc phụ kiện máy tính dưới 2 triệu',
        'Gợi ý tai nghe chống ồn tình trạng Như mới',
        'Mẹo kiểm tra đồ điện tử cũ khi giao dịch trực tiếp',
      ],
    );
  }

  Future<void> sendMessage(
    String rawMessage, {
    double? maxBudget,
    String? category,
  }) async {
    final trimmed = rawMessage.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userTurn = AiChatTurn(
      isUser: true,
      text: trimmed,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      turns: <AiChatTurn>[...state.turns, userTurn],
      isSending: true,
      clearError: true,
    );

    final focused = state.focusedProduct;
    final descSnippet = focused != null && focused.description.length > 400
        ? '${focused.description.substring(0, 400)}...'
        : (focused?.description ?? '');
    final messageForBackend = focused != null
        ? '[Ngữ cảnh sản phẩm người dùng đang xem: Tên="${focused.title}", '
            'ID="${focused.id}", Giá=${focused.price.toInt()} VNĐ, '
            'Giá gốc=${focused.originalPrice?.toInt() ?? 0}, '
            'Tình trạng=${focused.condition.apiValue}, '
            'Danh mục="${focused.category.name}", '
            'SlugDanhMuc="${focused.category.slug}", '
            'CategoryId="${focused.category.id}", '
            'Khuyết điểm công khai="${focused.hasDefectDisclosure ? focused.defects : "Không có lỗi"}", '
            'Mô tả="$descSnippet"]\n'
            'Câu hỏi của người mua: $trimmed'
        : trimmed;

    final result = await repository.sendChatMessage(
      message: messageForBackend,
      threadId: state.threadId,
      maxBudget: maxBudget,
      category: category,
    );
    if (!mounted) return;

    result.when(
      success: (response, _, _) {
        final assistantTurn = AiChatTurn(
          isUser: false,
          text: response.reply,
          matchedProducts: response.matchedProducts,
          toolsUsed: response.toolsUsed,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          turns: <AiChatTurn>[...state.turns, assistantTurn],
          threadId: response.threadId.isNotEmpty
              ? response.threadId
              : state.threadId,
          followUpQuestions: response.followUpQuestions.isNotEmpty
              ? response.followUpQuestions
              : state.followUpQuestions,
          isSending: false,
          clearError: true,
        );
      },
      failure: (error) {
        state = state.copyWith(
          isSending: false,
          error: error,
        );
      },
    );
  }

  Future<void> resetConversation() async {
    final activeThread = state.threadId;
    state = const AiChatState();
    if (activeThread != null && activeThread.trim().isNotEmpty) {
      await repository.deleteConversation(activeThread);
    }
  }
}

final aiChatControllerProvider =
    StateNotifierProvider<AiChatController, AiChatState>((ref) {
  return AiChatController(repository: ref.watch(aiRepositoryProvider));
});
