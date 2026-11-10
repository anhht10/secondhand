import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/utils/realtime_poller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/blog_remote_data_source.dart';
import '../../data/models/blog_models.dart';
import '../../data/repositories/blog_repository.dart';

final blogRemoteDataSourceProvider = Provider<BlogRemoteDataSource>((ref) {
  return BlogRemoteDataSource(ref.watch(apiClientProvider));
});

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  return BlogRepository(ref.watch(blogRemoteDataSourceProvider));
});

class BlogFeedState {
  const BlogFeedState({
    this.items = const <BlogPostModel>[],
    this.selectedCategory,
    this.keyword = '',
    this.isLoading = false,
    this.error,
  });

  final List<BlogPostModel> items;
  final BlogCategory? selectedCategory;
  final String keyword;
  final bool isLoading;
  final ApiException? error;

  BlogFeedState copyWith({
    List<BlogPostModel>? items,
    BlogCategory? selectedCategory,
    bool clearCategory = false,
    String? keyword,
    bool? isLoading,
    ApiException? error,
    bool clearError = false,
  }) {
    return BlogFeedState(
      items: items ?? this.items,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      keyword: keyword ?? this.keyword,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BlogFeedController extends StateNotifier<BlogFeedState> {
  BlogFeedController({
    required this.repository,
    bool autoLoad = true,
  }) : super(const BlogFeedState()) {
    if (autoLoad) {
      Future<void>.microtask(loadPosts);
      _realtimeTimer = startRealtimePeriodicSync(
        interval: const Duration(seconds: 4),
        onTick: () => loadPosts(silent: true),
      );
    }
  }

  final BlogRepository repository;
  Timer? _realtimeTimer;

  Future<void> loadPosts({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    final result = await repository.getBlogPosts(
      category: state.selectedCategory,
      keyword: state.keyword.isNotEmpty ? state.keyword : null,
    );
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

  void setCategory(BlogCategory? category) {
    if (category == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
    loadPosts();
  }

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword.trim());
    loadPosts();
  }

  Future<void> toggleLike(String postId) async {
    final currentItems = state.items;
    final idx = currentItems.indexWhere((p) => p.id == postId);
    if (idx >= 0) {
      final target = currentItems[idx];
      final nextLiked = !target.isLiked;
      final nextCount =
          nextLiked ? target.likesCount + 1 : (target.likesCount > 0 ? target.likesCount - 1 : 0);
      final updated = List<BlogPostModel>.from(currentItems);
      updated[idx] = target.copyWith(isLiked: nextLiked, likesCount: nextCount);
      state = state.copyWith(items: updated);
    }

    final result = await repository.toggleLike(postId);
    if (!mounted) return;
    result.when(
      success: (data, _, _) {
        final isLiked = data['isLiked'] == true;
        final likesCount = (data['likesCount'] as num?)?.toInt();
        final list = state.items.map((p) {
          if (p.id == postId) {
            return p.copyWith(
              isLiked: isLiked,
              likesCount: likesCount ?? p.likesCount,
            );
          }
          return p;
        }).toList();
        state = state.copyWith(items: list);
      },
      failure: (_) {},
    );
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }
}

final blogFeedControllerProvider =
    StateNotifierProvider<BlogFeedController, BlogFeedState>((ref) {
  final authState = ref.watch(authControllerProvider);
  return BlogFeedController(
    repository: ref.watch(blogRepositoryProvider),
    autoLoad: authState.isAuthenticated,
  );
});
