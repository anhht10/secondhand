import '../errors/api_exception.dart';

/// Pagination metadata returned inside the NestJS `TransformInterceptor` envelope.
class PaginationMeta {
  const PaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    final page = (json['page'] as num?)?.toInt() ?? 1;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;
    return PaginationMeta(
      total: total,
      page: page,
      limit: limit,
      totalPages: totalPages,
      hasNextPage: json['hasNextPage'] as bool? ?? (page < totalPages),
      hasPrevPage: json['hasPrevPage'] as bool? ?? (page > 1),
    );
  }
}

/// Type-safe wrapper for network operations.
sealed class NetworkResult<T> {
  const NetworkResult();

  bool get isSuccess => this is NetworkSuccess<T>;
  bool get isFailure => this is NetworkFailure<T>;

  T? get dataOrNull => switch (this) {
        NetworkSuccess<T>(:final data) => data,
        NetworkFailure<T>() => null,
      };

  ApiException? get errorOrNull => switch (this) {
        NetworkSuccess<T>() => null,
        NetworkFailure<T>(:final error) => error,
      };

  R when<R>({
    required R Function(T data, String message, PaginationMeta? meta) success,
    required R Function(ApiException error) failure,
  }) {
    final self = this;
    if (self is NetworkSuccess<T>) {
      return success(self.data, self.message, self.meta);
    }
    return failure((self as NetworkFailure<T>).error);
  }
}

final class NetworkSuccess<T> extends NetworkResult<T> {
  const NetworkSuccess({
    required this.data,
    this.message = 'Success',
    this.meta,
  });

  final T data;
  final String message;
  final PaginationMeta? meta;
}

final class NetworkFailure<T> extends NetworkResult<T> {
  const NetworkFailure(this.error);

  final ApiException error;
}
