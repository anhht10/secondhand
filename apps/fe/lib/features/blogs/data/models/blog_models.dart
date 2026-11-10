import '../../../products/data/models/product_model.dart';

enum BlogCategory {
  experience('EXPERIENCE', 'Kinh nghiệm mua bán', '💡'),
  review('REVIEW', 'Review đồ cũ', '⭐'),
  studyCorner('STUDY_CORNER', 'Góc học tập', '💻'),
  wantToBuy('WANT_TO_BUY', 'Cần tìm mua', '🔍'),
  scamAlert('SCAM_ALERT', 'Cảnh báo lừa đảo', '🛡️'),
  general('GENERAL', 'Thảo luận chung', '💬');

  const BlogCategory(this.apiValue, this.labelVi, this.emoji);
  final String apiValue;
  final String labelVi;
  final String emoji;

  static BlogCategory fromString(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    for (final val in BlogCategory.values) {
      if (val.apiValue == normalized) return val;
    }
    return BlogCategory.experience;
  }
}

class BlogAuthorSummary {
  const BlogAuthorSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.location,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? location;

  factory BlogAuthorSummary.fromDynamic(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return BlogAuthorSummary(
        id: (raw['id'] ?? raw['_id'] ?? '').toString(),
        displayName: (raw['displayName'] as String?)?.trim().isNotEmpty == true
            ? (raw['displayName'] as String).trim()
            : 'Thành viên ReMarket',
        avatarUrl: raw['avatarUrl'] as String?,
        location: raw['location'] as String?,
      );
    }
    return BlogAuthorSummary(
      id: (raw ?? '').toString(),
      displayName: 'Thành viên ReMarket',
    );
  }
}

class BlogAttachedProductSummary {
  const BlogAttachedProductSummary({
    required this.id,
    required this.title,
    required this.price,
    this.condition = ProductCondition.good,
    this.status = ProductStatus.active,
    this.primaryImageUrl,
    this.location,
  });

  final String id;
  final String title;
  final double price;
  final ProductCondition condition;
  final ProductStatus status;
  final String? primaryImageUrl;
  final String? location;

  static BlogAttachedProductSummary? fromDynamic(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = (raw['id'] ?? raw['_id'] ?? '').toString().trim();
    final title = (raw['title'] as String?)?.trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;

    String? imageUrl;
    final rawImages = raw['images'];
    if (rawImages is List && rawImages.isNotEmpty) {
      final first = rawImages.first;
      if (first is Map<String, dynamic>) {
        imageUrl = first['url'] as String?;
      } else if (first is String) {
        imageUrl = first;
      }
    }

    return BlogAttachedProductSummary(
      id: id,
      title: title,
      price: (raw['price'] as num?)?.toDouble() ?? 0,
      condition: ProductCondition.fromApi(raw['condition'] as String?),
      status: ProductStatus.fromApi(raw['status'] as String?),
      primaryImageUrl: imageUrl,
      location: raw['location'] as String?,
    );
  }
}

class BlogCommentModel {
  const BlogCommentModel({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    this.images = const <String>[],
    this.createdAt,
  });

  final String id;
  final String postId;
  final BlogAuthorSummary author;
  final String content;
  final List<String> images;
  final DateTime? createdAt;

  factory BlogCommentModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    return BlogCommentModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      author: BlogAuthorSummary.fromDynamic(json['authorId']),
      content: (json['content'] as String?) ?? '',
      images: images,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

class BlogPostModel {
  const BlogPostModel({
    required this.id,
    required this.author,
    required this.title,
    required this.content,
    this.category = BlogCategory.experience,
    this.tags = const <String>[],
    this.images = const <String>[],
    this.attachedProduct,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.comments = const <BlogCommentModel>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final BlogAuthorSummary author;
  final String title;
  final String content;
  final BlogCategory category;
  final List<String> tags;
  final List<String> images;
  final BlogAttachedProductSummary? attachedProduct;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final bool isLiked;
  final List<BlogCommentModel> comments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BlogPostModel copyWith({
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    bool? isLiked,
    List<BlogCommentModel>? comments,
  }) {
    return BlogPostModel(
      id: id,
      author: author,
      title: title,
      content: content,
      category: category,
      tags: tags,
      images: images,
      attachedProduct: attachedProduct,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory BlogPostModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    final rawComments = json['comments'];
    final comments = rawComments is List
        ? rawComments
            .whereType<Map<String, dynamic>>()
            .map(BlogCommentModel.fromJson)
            .toList()
        : const <BlogCommentModel>[];

    return BlogPostModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      author: BlogAuthorSummary.fromDynamic(json['authorId']),
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      category: BlogCategory.fromString(json['category'] as String?),
      tags: tags,
      images: images,
      attachedProduct:
          BlogAttachedProductSummary.fromDynamic(json['attachedProductId']),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      viewsCount: (json['viewsCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] == true,
      comments: comments,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}

class AiBlogDraftModel {
  const AiBlogDraftModel({
    required this.suggestedTitle,
    required this.suggestedContent,
    this.suggestedTags = const <String>[],
    this.aiProvider = 'gemini-ai',
  });

  final String suggestedTitle;
  final String suggestedContent;
  final List<String> suggestedTags;
  final String aiProvider;

  factory AiBlogDraftModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['suggestedTags'];
    return AiBlogDraftModel(
      suggestedTitle: (json['suggestedTitle'] as String?) ?? '',
      suggestedContent: (json['suggestedContent'] as String?) ?? '',
      suggestedTags: rawTags is List
          ? rawTags.map((e) => e.toString()).toList()
          : const <String>[],
      aiProvider: (json['aiProvider'] as String?) ?? 'gemini-ai',
    );
  }
}
