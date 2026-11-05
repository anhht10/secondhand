import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_empty_state.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_loading_indicator.dart';
import '../providers/reports_providers.dart';

/// My Submitted Reports Screen (`GET /api/v1/reports/me`).
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử báo cáo vi phạm'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => ref.invalidate(myReportsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: reportsAsync.when(
        loading: () => const RmLoadingIndicator(
          message: 'Đang tải lịch sử báo cáo...',
        ),
        error: (err, _) => RmErrorState(
          message: err.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(myReportsProvider),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const RmEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Bạn chưa gửi báo cáo nào',
              subtitle:
                  'Các báo cáo về tin đăng sai sự thật hoặc gian lận của bạn sẽ hiển thị trạng thái xử lý tại đây.',
            );
          }

          return ListView.separated(
            padding: AppSpacing.screenPadding,
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final report = reports[index];
              return RmCard(
                onTap: report.product.id.isNotEmpty
                    ? () => context.push(
                          RouteNames.productDetail(report.product.id),
                        )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                          ),
                          child: Text(
                            report.statusLabel,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.warningText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.formatRelativeDate(report.createdAt),
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      report.product.title,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lý do: ${report.reason}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (report.description != null &&
                        report.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Chi tiết: ${report.description}',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
