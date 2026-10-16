import 'package:dio/dio.dart';

/// Standardized error codes returned by the ReMarket NestJS Gateway (`GlobalExceptionFilter`).
///
/// Mirrors `docs/api/ERROR_HANDLING.md` from Phase 7.
abstract final class ApiErrorCodes {
  static const String validationError = 'VALIDATION_ERROR';
  static const String badRequest = 'BAD_REQUEST';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String forbidden = 'FORBIDDEN';
  static const String notFound = 'NOT_FOUND';
  static const String productNotFound = 'PRODUCT_NOT_FOUND';
  static const String conflict = 'CONFLICT';
  static const String payloadTooLarge = 'PAYLOAD_TOO_LARGE';
  static const String tooManyRequests = 'TOO_MANY_REQUESTS';
  static const String aiRateLimited = 'AI_RATE_LIMITED';
  static const String aiInvalidResponse = 'AI_INVALID_RESPONSE';
  static const String aiServiceUnavailable = 'AI_SERVICE_UNAVAILABLE';
  static const String aiRequestTimeout = 'AI_REQUEST_TIMEOUT';
  static const String internalServerError = 'INTERNAL_SERVER_ERROR';
  static const String networkError = 'NETWORK_ERROR';
  static const String timeoutError = 'TIMEOUT_ERROR';
}

/// Structured exception representing any API or network failure in ReMarket.
///
/// Parses the exact NestJS error envelope:
/// ```json
/// {
///   "success": false,
///   "statusCode": 400,
///   "message": "price must not be less than 0",
///   "error": {
///     "code": "VALIDATION_ERROR",
///     "details": ["price must not be less than 0"],
///     "requestId": "optional-req-id"
///   }
/// }
/// ```
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.code,
    this.statusCode,
    this.details = const <String>[],
    this.requestId,
    this.isNetworkError = false,
  });

  final String message;
  final String code;
  final int? statusCode;
  final List<String> details;
  final String? requestId;
  final bool isNetworkError;

  bool get isUnauthorized =>
      statusCode == 401 || code == ApiErrorCodes.unauthorized;

  bool get isForbidden =>
      statusCode == 403 || code == ApiErrorCodes.forbidden;

  bool get isValidationError =>
      code == ApiErrorCodes.validationError || statusCode == 400;

  bool get isConflict =>
      statusCode == 409 || code == ApiErrorCodes.conflict;

  /// Parses an [ApiException] from a [DioException] or raw error response.
  factory ApiException.fromDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;

    if (response?.data is Map<String, dynamic>) {
      return ApiException.fromErrorEnvelope(
        response!.data as Map<String, dynamic>,
        fallbackStatusCode: statusCode,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          message: 'Kết nối tới máy chủ quá thời gian chờ. Vui lòng thử lại.',
          code: ApiErrorCodes.timeoutError,
          statusCode: statusCode ?? 504,
          details: const ['Yêu cầu vượt quá thời gian chờ (Timeout).'],
          isNetworkError: true,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'Không thể kết nối tới máy chủ ReMarket. Vui lòng kiểm tra kết nối mạng.',
          code: ApiErrorCodes.networkError,
          statusCode: statusCode,
          details: const ['Lỗi kết nối mạng hoặc máy chủ chưa khởi động.'],
          isNetworkError: true,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'Yêu cầu đã bị hủy.',
          code: ApiErrorCodes.networkError,
          statusCode: statusCode,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return ApiException(
          message: _defaultMessageForStatus(statusCode),
          code: _defaultCodeForStatus(statusCode),
          statusCode: statusCode,
          details: [error.message ?? 'Đã xảy ra lỗi không xác định.'],
          isNetworkError: statusCode == null,
        );
    }
  }

  /// Parses the standard NestJS error envelope (`GlobalExceptionFilter`).
  factory ApiException.fromErrorEnvelope(
    Map<String, dynamic> json, {
    int? fallbackStatusCode,
  }) {
    final statusCode = (json['statusCode'] as num?)?.toInt() ?? fallbackStatusCode;
    final errorObj = json['error'];

    String code = _defaultCodeForStatus(statusCode);
    List<String> details = const <String>[];
    String? requestId;

    if (errorObj is Map<String, dynamic>) {
      if (errorObj['code'] is String && (errorObj['code'] as String).trim().isNotEmpty) {
        code = (errorObj['code'] as String).trim();
      }
      if (errorObj['details'] is List) {
        details = (errorObj['details'] as List)
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false);
      }
      if (errorObj['requestId'] is String) {
        requestId = errorObj['requestId'] as String;
      }
    }

    final rawMessage = json['message'];
    String message;
    if (rawMessage is String && rawMessage.trim().isNotEmpty) {
      message = rawMessage.trim();
    } else if (rawMessage is List && rawMessage.isNotEmpty) {
      message = rawMessage.first.toString();
      if (details.isEmpty) {
        details = rawMessage.map((e) => e.toString()).toList(growable: false);
      }
    } else if (details.isNotEmpty) {
      message = details.first;
    } else {
      message = _defaultMessageForStatus(statusCode);
    }

    return ApiException(
      message: message,
      code: code,
      statusCode: statusCode,
      details: details.isEmpty ? [message] : details,
      requestId: requestId,
    );
  }

  static String _defaultCodeForStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return ApiErrorCodes.badRequest;
      case 401:
        return ApiErrorCodes.unauthorized;
      case 403:
        return ApiErrorCodes.forbidden;
      case 404:
        return ApiErrorCodes.notFound;
      case 409:
        return ApiErrorCodes.conflict;
      case 413:
        return ApiErrorCodes.payloadTooLarge;
      case 429:
        return ApiErrorCodes.tooManyRequests;
      case 502:
        return ApiErrorCodes.aiInvalidResponse;
      case 503:
        return ApiErrorCodes.aiServiceUnavailable;
      case 504:
        return ApiErrorCodes.aiRequestTimeout;
      default:
        return ApiErrorCodes.internalServerError;
    }
  }

  static String _defaultMessageForStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Dữ liệu gửi lên không hợp lệ.';
      case 401:
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu yêu cầu.';
      case 409:
        return 'Dữ liệu bị trùng lặp trên hệ thống.';
      case 429:
        return 'Bạn đang thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
      case 503:
        return 'Dịch vụ AI hiện đang tạm ngưng hoặc bảo trì.';
      case 504:
        return 'Dịch vụ AI phản hồi quá thời gian chờ.';
      default:
        return 'Đã xảy ra lỗi hệ thống. Vui lòng thử lại sau.';
    }
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, code: $code, message: $message)';
}
