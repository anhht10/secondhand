import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Phase 8 foundation Profile Screen displaying authenticated user details,
/// seller transparency statistics from `/api/v1/auth/me`, and Logout action.
class ProfilePlaceholderScreen extends ConsumerWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Làm mới thông tin (/auth/me)',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: authState.isSubmitting
                ? null
                : () =>
                    ref.read(authControllerProvider.notifier).refreshProfile(),
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
                  RmCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primaryTintBg,
                          child: Text(
                            user?.initials ?? 'U',
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Người dùng ReMarket',
                                style: AppTypography.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                user?.email ?? '',
                                style: AppTypography.bodyMedium,
                              ),
                              if (user?.location != null &&
                                  user!.location!.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 15,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        user.location!,
                                        style: AppTypography.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (user?.stats != null) ...[
                    RmCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            label: 'Đang bán',
                            value: '${user!.stats!.activeListingsCount}',
                          ),
                          _StatItem(
                            label: 'Đã bán',
                            value: '${user.stats!.soldListingsCount}',
                          ),
                          _StatItem(
                            label: 'Đánh giá',
                            value: '${user.stats!.rating} ★',
                          ),
                          _StatItem(
                            label: 'Minh bạch',
                            value: '${user.stats!.transparencyRate}%',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  RmButton(
                    key: const Key('logout_button'),
                    label: 'Đăng xuất tài khoản',
                    icon: Icons.logout_rounded,
                    variant: RmButtonVariant.danger,
                    isLoading: authState.isSubmitting,
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
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

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}
