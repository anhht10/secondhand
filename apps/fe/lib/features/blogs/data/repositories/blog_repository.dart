import '../../../../core/network/network_result.dart';
import '../datasources/blog_remote_data_source.dart';
import '../models/blog_models.dart';

class BlogRepository {
  const BlogRepository(this._remote);

  final BlogRemoteDataSource _remote;

  Future<NetworkResult<List<BlogPostModel>>> getBlogPosts({
    BlogCategory? category,
    String? keyword,
    String? authorId,
    int page = 1,
    int limit = 20,
  }) {
    return _remote.getBlogPosts(
      category: category,
      keyword: keyword,
      authorId: authorId,
      page: page,
      limit: limit,
    );
  }

  Future<NetworkResult<BlogPostModel>> getBlogPostById(String postId) {
    return _remote.getBlogPostById(postId);
  }

  Future<NetworkResult<BlogPostModel>> createBlogPost({
    required String title,
    required String content,
    required BlogCategory category,
    List<String> tags = const <String>[],
    List<String> images = const <String>[],
    String? attachedProductId,
  }) {
    return _remote.createBlogPost(
      title: title,
      content: content,
      category: category,
      tags: tags,
      images: images,
      attachedProductId: attachedProductId,
    );
  }

  Future<NetworkResult<bool>> deleteBlogPost(String postId) {
    return _remote.deleteBlogPost(postId);
  }

  Future<NetworkResult<Map<String, dynamic>>> toggleLike(String postId) {
    return _remote.toggleLike(postId);
  }

  Future<NetworkResult<BlogCommentModel>> addComment({
    required String postId,
    String content = '',
    List<String> images = const <String>[],
  }) {
    return _remote.addComment(
      postId: postId,
      content: content,
      images: images,
    );
  }

  Future<NetworkResult<bool>> deleteComment({
    required String postId,
    required String commentId,
  }) {
    return _remote.deleteComment(postId: postId, commentId: commentId);
  }

  Future<NetworkResult<AiBlogDraftModel>> generateAiDraft({
    required String topic,
    required BlogCategory category,
    String? keyPoints,
    String? attachedProductTitle,
  }) {
    return _remote.generateAiDraft(
      topic: topic,
      category: category,
      keyPoints: keyPoints,
      attachedProductTitle: attachedProductTitle,
    );
  }
}
