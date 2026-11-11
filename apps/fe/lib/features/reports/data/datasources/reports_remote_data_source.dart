import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../models/report_model.dart';

/// Remote data source for Listing Reports (`/api/v1/reports`).
class ReportsRemoteDataSource {
  const ReportsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /api/v1/reports`
  Future<NetworkResult<ReportModel>> createReport({
    required String productId,
    required String reason,
    String? description,
    List<String> evidenceUrls = const <String>[],
  }) {
    final payload = <String, dynamic>{
      'productId': productId.trim(),
      'reason': reason.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (evidenceUrls.isNotEmpty) 'evidenceUrls': evidenceUrls,
    };

    return _apiClient.post<ReportModel>(
      ApiEndpoints.reports,
      data: payload,
      parser: (rawData) =>
          ReportModel.fromJson(rawData as Map<String, dynamic>),
    );
  }

  /// `GET /api/v1/reports/me`
  Future<NetworkResult<List<ReportModel>>> getMyReports({
    int page = 1,
    int limit = 20,
  }) {
    return _apiClient.get<List<ReportModel>>(
      ApiEndpoints.myReports,
      queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      parser: (rawData) {
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(ReportModel.fromJson)
              .toList(growable: false);
        }
        return const <ReportModel>[];
      },
    );
  }
}
