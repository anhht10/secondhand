import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Settings & Local Storage Management Screen (`22 - Settings`).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isClearing = false;

  Future<void> _clearAllLocalCaches() async {
    setState(() => _isClearing = true);
    final prefs = ref.read(localPreferencesProvider);
    await prefs?.clearAllCaches();
    if (!mounted) return;
    setState(() => _isClearing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã xóa toàn bộ bộ nhớ đệm ngoại tuyến và bản nháp cục bộ!',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final prefs = ref.watch(localPreferencesProvider);
    final cachedFeedCount = prefs?.readCachedProductsJson().length ?? 0;
    final cachedTimestamp = prefs?.readCachedProductsTimestamp();
    final hasLocalDraft = prefs?.readListingDraftJson()?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cài đặt & Hệ thống'),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          RmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin ứng dụng & Kết nối API',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                _SettingInfoRow(
                  label: 'Phiên bản ứng dụng',
                  value: '${AppConstants.appName} v1.0.0 (Phase 9)',
                ),
                const Divider(),
                _SettingInfoRow(
                  label: 'Môi trường chạy',
                  value: config.environment.name.toUpperCase(),
                ),
                const Divider(),
                _SettingInfoRow(
                  label: 'NestJS API Base URL',
                  value: config.apiBaseUrl,
                ),
                const Divider(),
                const _SettingInfoRow(
                  label: 'Kiến trúc AI',
                  value: 'NestJS Proxy → FastAPI LangGraph + Gemini',
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
                  'Bộ nhớ đệm Ngoại tuyến & Bản nháp (SharedPreferences)',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                _SettingInfoRow(
                  label: 'Sản phẩm lưu ngoại tuyến',
                  value: '$cachedFeedCount sản phẩm',
                ),
                const Divider(),
                _SettingInfoRow(
                  label: 'Đồng bộ ngoại tuyến gần nhất',
                  value: cachedTimestamp != null
                      ? AppFormatters.formatRelativeDate(cachedTimestamp)
                      : 'Chưa có',
                ),
                const Divider(),
                _SettingInfoRow(
                  label: 'Bản nháp tin đăng cục bộ',
                  value: hasLocalDraft ? 'Đang lưu 1 bản nháp' : 'Trống',
                ),
                const SizedBox(height: AppSpacing.md),
                RmButton(
                  label: 'Xóa cache ngoại tuyến & bản nháp',
                  icon: Icons.cleaning_services_outlined,
                  variant: RmButtonVariant.secondary,
                  isLoading: _isClearing,
                  onPressed: _clearAllLocalCaches,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          RmButton(
            label: 'Đăng xuất tài khoản',
            icon: Icons.logout_rounded,
            variant: RmButtonVariant.danger,
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

class _SettingInfoRow extends StatelessWidget {
  const _SettingInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.bodySmall,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
