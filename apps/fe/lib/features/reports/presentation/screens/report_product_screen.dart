import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_text_field.dart';
import '../../data/models/report_model.dart';
import '../providers/reports_providers.dart';

/// Report Listing Screen (`11 - Report Listing Modal` — `POST /api/v1/reports`).
class ReportProductScreen extends ConsumerStatefulWidget {
  const ReportProductScreen({
    super.key,
    required this.productId,
    this.productTitle,
  });

  final String productId;
  final String? productTitle;

  @override
  ConsumerState<ReportProductScreen> createState() =>
      _ReportProductScreenState();
}

class _ReportProductScreenState extends ConsumerState<ReportProductScreen> {
  String _selectedReason = ReportReasons.predefinedReasons.first;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref.read(reportsRepositoryProvider).createReport(
          productId: widget.productId,
          reason: _selectedReason,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (_, _, _) {
        ref.invalidate(myReportsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã gửi báo cáo vi phạm thành công. Đội ngũ ReMarket sẽ kiểm duyệt sớm nhất!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        if (context.canPop()) {
          context.pop();
        }
      },
      failure: (error) {
        setState(() {
          if (error.statusCode == 409) {
            _errorMessage =
                'Bạn đã gửi một báo cáo đang chờ xử lý cho sản phẩm này rồi.';
          } else {
            _errorMessage = error.message;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Báo cáo tin đăng vi phạm'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              RmErrorBanner(
                message: _errorMessage!,
                onDismiss: () => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            RmCard(
              backgroundColor: AppColors.errorBg,
              borderColor: AppColors.errorBorder,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColors.error,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productTitle?.trim().isNotEmpty == true
                              ? 'Báo cáo: ${widget.productTitle}'
                              : 'Bảo vệ cộng đồng mua bán minh bạch ReMarket',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.errorText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mọi báo cáo đều được ẩn danh với người bán. Vui lòng chọn đúng lý do vi phạm.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.errorText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            RmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn lý do báo cáo *',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final reason in ReportReasons.predefinedReasons)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          _selectedReason == reason
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: _selectedReason == reason
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        title: Text(
                          reason,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: _selectedReason == reason
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: () {
                          setState(() => _selectedReason = reason);
                        },
                      ),
                    ),
                  const Divider(height: AppSpacing.lg),
                  RmTextField(
                    label: 'Mô tả chi tiết bằng chứng (Tùy chọn)',
                    hintText:
                        'Cung cấp thêm thông tin về dấu hiệu gian lận hoặc sai lệch tình trạng sản phẩm...',
                    controller: _descriptionController,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            RmButton(
              label: 'Gửi báo cáo vi phạm',
              icon: Icons.send_rounded,
              variant: RmButtonVariant.danger,
              isLoading: _isSubmitting,
              onPressed: _submitReport,
            ),
          ],
        ),
      ),
    );
  }
}
