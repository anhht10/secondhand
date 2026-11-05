import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/reports_remote_data_source.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/reports_repository.dart';

final reportsRemoteDataSourceProvider =
    Provider<ReportsRemoteDataSource>((ref) {
  return ReportsRemoteDataSource(ref.watch(apiClientProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(reportsRemoteDataSourceProvider));
});

final myReportsProvider = FutureProvider<List<ReportModel>>((ref) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final result = await repo.getMyReports();
  return result.when(
    success: (reports, _, _) => reports,
    failure: (error) => throw error,
  );
});
