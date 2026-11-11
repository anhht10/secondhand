import '../../../messages/data/models/message_models.dart';

/// Standard report reasons aligned with `11 - Report Listing Modal` in `PROJECT_PLAN.md`
/// and NestJS `CreateReportDto` (`reason`: 3..150 characters).
abstract final class ReportReasons {
  static const List<String> predefinedReasons = <String>[
    'Thông tin tình trạng / khuyết điểm không đúng thực tế',
    'Nghi ngờ hàng giả / hàng nhái thương hiệu',
    'Yêu cầu chuyển khoản đặt cọc bất thường',
    'Hình ảnh lấy từ mạng, không phải ảnh chụp thật',
    'Sản phẩm thuộc danh mục cấm hoặc vi phạm quy định',
  ];
}

/// Report model matching `Report` schema (`POST /api/v1/reports`, `GET /api/v1/reports/me`).
class ReportModel {
  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.product,
    required this.reason,
    this.description,
    this.evidenceUrls = const <String>[],
    this.status = 'PENDING',
    this.createdAt,
  });

  final String id;
  final String reporterId;
  final ConversationProductSummary product;
  final String reason;
  final String? description;
  final List<String> evidenceUrls;
  final String status;
  final DateTime? createdAt;

  String get statusLabel => switch (status.toUpperCase()) {
        'REVIEWED' => 'Đã xem xét',
        'RESOLVED' => 'Đã xử lý',
        'REJECTED' => 'Đã từ chối',
        'PENDING' || _ => 'Đang chờ xử lý',
      };

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      reporterId: (json['reporterId'] ?? '').toString(),
      product: ConversationProductSummary.fromDynamic(json['productId']),
      reason: (json['reason'] as String?) ?? '',
      description: json['description'] as String?,
      evidenceUrls: (json['evidenceUrls'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      status: (json['status'] as String?) ?? 'PENDING',
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
