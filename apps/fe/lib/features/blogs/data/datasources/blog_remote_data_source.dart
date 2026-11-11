import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../models/blog_models.dart';

class BlogRemoteDataSource {
  const BlogRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /api/v1/blogs`
  Future<NetworkResult<List<BlogPostModel>>> getBlogPosts({
    BlogCategory? category,
    String? keyword,
    String? authorId,
    int page = 1,
    int limit = 20,
  }) {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (category != null) 'category': category.apiValue,
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (authorId != null && authorId.trim().isNotEmpty)
        'authorId': authorId.trim(),
    };

    return _apiClient.get<List<BlogPostModel>>(
      '/blogs',
      queryParameters: queryParams,
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(BlogPostModel.fromJson)
              .toList();
        }
        if (rawData is Map<String, dynamic> && rawData['items'] is List) {
          return (rawData['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(BlogPostModel.fromJson)
              .toList();
        }
        return const <BlogPostModel>[];
      },
    );
  }

  /// `GET /api/v1/blogs/:id`
  Future<NetworkResult<BlogPostModel>> getBlogPostById(String postId) {
    return _apiClient.get<BlogPostModel>(
      '/blogs/$postId',
      parser: (rawData) =>
          BlogPostModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `POST /api/v1/blogs`
  Future<NetworkResult<BlogPostModel>> createBlogPost({
    required String title,
    required String content,
    required BlogCategory category,
    List<String> tags = const <String>[],
    List<String> images = const <String>[],
    String? attachedProductId,
  }) {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'category': category.apiValue,
      if (tags.isNotEmpty) 'tags': tags,
      if (images.isNotEmpty) 'images': images,
      if (attachedProductId != null && attachedProductId.trim().isNotEmpty)
        'attachedProductId': attachedProductId.trim(),
    };

    return _apiClient.post<BlogPostModel>(
      '/blogs',
      data: payload,
      parser: (rawData) =>
          BlogPostModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `DELETE /api/v1/blogs/:id`
  Future<NetworkResult<bool>> deleteBlogPost(String postId) {
    return _apiClient.delete<bool>(
      '/blogs/$postId',
      parser: (_) => true,
    );
  }

  /// `POST /api/v1/blogs/:id/like`
  Future<NetworkResult<Map<String, dynamic>>> toggleLike(String postId) {
    return _apiClient.post<Map<String, dynamic>>(
      '/blogs/$postId/like',
      parser: (rawData) => rawData is Map<String, dynamic>
          ? rawData
          : <String, dynamic>{},
    );
  }

  /// `POST /api/v1/blogs/:id/comments`
  Future<NetworkResult<BlogCommentModel>> addComment({
    required String postId,
    String content = '',
    List<String> images = const <String>[],
  }) {
    return _apiClient.post<BlogCommentModel>(
      '/blogs/$postId/comments',
      data: <String, dynamic>{
        'content': content.trim(),
        if (images.isNotEmpty) 'images': images,
      },
      parser: (rawData) =>
          BlogCommentModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `DELETE /api/v1/blogs/:id/comments/:commentId`
  Future<NetworkResult<bool>> deleteComment({
    required String postId,
    required String commentId,
  }) {
    return _apiClient.delete<bool>(
      '/blogs/$postId/comments/$commentId',
      parser: (_) => true,
    );
  }

  /// `POST /api/v1/blogs/ai-draft`
  Future<NetworkResult<AiBlogDraftModel>> generateAiDraft({
    required String topic,
    required BlogCategory category,
    String? keyPoints,
    String? attachedProductTitle,
  }) {
    return _apiClient.post<AiBlogDraftModel>(
      '/blogs/ai-draft',
      data: <String, dynamic>{
        'topic': topic.trim(),
        'category': category.apiValue,
        if (keyPoints != null && keyPoints.trim().isNotEmpty)
          'keyPoints': keyPoints.trim(),
        if (attachedProductTitle != null &&
            attachedProductTitle.trim().isNotEmpty)
          'attachedProductTitle': attachedProductTitle.trim(),
      },
      parser: (rawData) =>
          AiBlogDraftModel.fromJson(rawData as Map<String, dynamic>),
    );
  }
}
