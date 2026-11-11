import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Phase 8 foundation Home Screen verifying authenticated routing,
/// active user session, and API configuration before Phase 9 Marketplace UI.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReMarket — Khám phá'),
        actions: [
          IconButton(
            tooltip: 'Hồ sơ cá nhân',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go(RouteNames.profilePath),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome & AI Banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppSpacing.borderRadiusLg,
                      boxShadow: AppSpacing.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, ${user?.displayName ?? 'Thành viên'}!',
                          style: AppTypography.headlineMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          user?.location ??
                              'Sàn giao dịch đồ cũ sinh viên minh bạch hỗ trợ bởi Gemini AI.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
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
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Phase 8 Foundation — Sẵn sàng',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.successText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Hệ thống xác thực JWT, Refresh Token Rotation, Dio API Client, Riverpod 2 và GoRouter đã được kết nối thành công với NestJS Backend.',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: AppSpacing.aiTintBoxDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cấu hình kết nối hiện tại:',
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '• API Base URL: ${config.apiBaseUrl}\n'
                                '• Môi trường: ${config.environment.name}\n'
                                '• Email đang đăng nhập: ${user?.email ?? '-'}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        RmButton(
                          label: 'Xem Hồ sơ & Quản lý Phiên đăng nhập',
                          variant: RmButtonVariant.secondary,
                          icon: Icons.person_outline_rounded,
                          onPressed: () => context.go(RouteNames.profilePath),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
