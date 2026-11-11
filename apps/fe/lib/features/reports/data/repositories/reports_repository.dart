import '../../../../core/network/network_result.dart';
import '../datasources/reports_remote_data_source.dart';
import '../models/report_model.dart';

/// Repository for Listing Reports (`/api/v1/reports`).
class ReportsRepository {
  const ReportsRepository(this.remoteDataSource);

  final ReportsRemoteDataSource remoteDataSource;

  Future<NetworkResult<ReportModel>> createReport({
    required String productId,
    required String reason,
    String? description,
    List<String> evidenceUrls = const <String>[],
  }) {
    return remoteDataSource.createReport(
      productId: productId,
      reason: reason,
      description: description,
      evidenceUrls: evidenceUrls,
    );
  }

  Future<NetworkResult<List<ReportModel>>> getMyReports({
    int page = 1,
    int limit = 20,
  }) {
    return remoteDataSource.getMyReports(page: page, limit: limit);
  }
}
