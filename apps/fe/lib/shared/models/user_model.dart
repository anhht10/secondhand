/// Seller statistics returned inside `GET /api/v1/auth/me`, `GET /api/v1/users/me`,
/// and `GET /api/v1/users/:id`.
class SellerStatsModel {
  const SellerStatsModel({
    this.activeListingsCount = 0,
    this.soldListingsCount = 0,
    this.completedOrdersCount = 0,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.reputationScore = 66,
    this.transparencyRate = 100,
  });

  final int activeListingsCount;
  final int soldListingsCount;
  final int completedOrdersCount;
  final double rating;
  final int totalReviews;
  final int reputationScore;
  final int transparencyRate;

  factory SellerStatsModel.fromJson(Map<String, dynamic> json) {
    return SellerStatsModel(
      activeListingsCount: (json['activeListingsCount'] as num?)?.toInt() ?? 0,
      soldListingsCount: (json['soldListingsCount'] as num?)?.toInt() ?? 0,
      completedOrdersCount: (json['completedOrdersCount'] as num?)?.toInt() ??
          ((json['soldListingsCount'] as num?)?.toInt() ?? 0),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      reputationScore: (json['reputationScore'] as num?)?.toInt() ?? 66,
      transparencyRate: (json['transparencyRate'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'activeListingsCount': activeListingsCount,
      'soldListingsCount': soldListingsCount,
      'completedOrdersCount': completedOrdersCount,
      'rating': rating,
      'totalReviews': totalReviews,
      'reputationScore': reputationScore,
      'transparencyRate': transparencyRate,
    };
  }
}

/// Optional bank account info configured by a seller on their own profile
/// (`GET / PATCH /api/v1/users/me`). Never exposed on public profile endpoints.
class UserBankInfoModel {
  const UserBankInfoModel({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.branch,
  });

  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String? branch;

  bool get isConfigured =>
      bankName.trim().isNotEmpty &&
      accountNumber.trim().isNotEmpty &&
      accountHolder.trim().isNotEmpty;

  factory UserBankInfoModel.fromJson(Map<String, dynamic> json) {
    return UserBankInfoModel(
      bankName: (json['bankName'] as String?) ?? '',
      accountNumber: (json['accountNumber'] as String?) ?? '',
      accountHolder: (json['accountHolder'] as String?) ?? '',
      branch: json['branch'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bankName': bankName.trim(),
      'accountNumber': accountNumber.trim(),
      'accountHolder': accountHolder.trim(),
      if (branch != null && branch!.trim().isNotEmpty) 'branch': branch!.trim(),
    };
  }
}

/// Domain & serialization model for an authenticated ReMarket user.
///
/// Mirrors `UserResponseDto` in `docs/api/API_CONTRACT.md` & `AUTHENTICATION.md`.
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.location,
    this.role = 'user',
    this.isEmailVerified = false,
    this.status = 'ACTIVE',
    this.wishlist = const <String>[],
    this.stats,
    this.bankInfo,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final String role;
  final bool isEmailVerified;
  final String status;
  final List<String> wishlist;
  final SellerStatsModel? stats;
  final UserBankInfoModel? bankInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['_id'] ?? '').toString();
    final rawWishlist = json['wishlist'];
    final wishlistIds = rawWishlist is List
        ? rawWishlist
            .map((e) {
              if (e is Map<String, dynamic>) {
                return (e['id'] ?? e['_id'] ?? '').toString();
              }
              return e.toString();
            })
            .where((id) => id.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final rawStats = json['stats'];
    final rawBankInfo = json['bankInfo'];
    return UserModel(
      id: rawId,
      email: (json['email'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      phone: (json['phoneNumber'] ?? json['phone']) as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      role: (json['role'] as String?) ?? 'user',
      isEmailVerified: (json['isEmailVerified'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'ACTIVE',
      wishlist: wishlistIds,
      stats: rawStats is Map<String, dynamic>
          ? SellerStatsModel.fromJson(rawStats)
          : null,
      bankInfo: rawBankInfo is Map<String, dynamic>
          ? UserBankInfoModel.fromJson(rawBankInfo)
          : null,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] is String
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      '_id': id,
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'phoneNumber': phone,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'location': location,
      'role': role,
      'isEmailVerified': isEmailVerified,
      'status': status,
      'wishlist': wishlist,
      if (stats != null) 'stats': stats!.toJson(),
      if (bankInfo != null) 'bankInfo': bankInfo!.toJson(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
