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
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../wishlist/presentation/providers/wishlist_providers.dart';

/// My Profile & Dashboard Screen (`21 - My Profile & Dashboard` — `GET /api/v1/users/me`).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final wishlistCount = ref.watch(wishlistControllerProvider).items.length;
    final unreadNotifsCount = ref
        .watch(notificationsProvider)
        .maybeWhen(
          data: (items) => items.where((n) => !n.isRead).length,
          orElse: () => 0,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ & Cửa hàng cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Làm mới hồ sơ',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).refreshProfile(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            onPressed: () => context.push(RouteNames.settingsPath),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(authControllerProvider.notifier).refreshProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // 1. User Header Card
            RmCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryTintBg,
                        child: Text(
                          user?.initials ?? 'U',
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user?.displayName ?? 'Người dùng ReMarket',
                                    style: AppTypography.titleLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: AppTypography.bodySmall,
                            ),
                            if (user?.location != null &&
                                user!.location!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 2),
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
                      IconButton(
                        tooltip: 'Chỉnh sửa hồ sơ',
                        onPressed: () =>
                            context.push(RouteNames.editProfilePath),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (user?.bio != null && user!.bio!.trim().isNotEmpty) ...[
                    const Divider(height: AppSpacing.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        user.bio!,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Seller Stats Summary
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Đang bán',
                    value: '${user?.stats?.activeListingsCount ?? 0}',
                    icon: Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Giao dịch xong',
                    value:
                        '${user?.stats?.completedOrdersCount ?? user?.stats?.soldListingsCount ?? 0}',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Điểm uy tín',
                    value: '${user?.stats?.reputationScore ?? 66}/100',
                    icon: Icons.verified_user_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 3. Marketplace Management Actions
            RmCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileMenuTile(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Đơn mua của tôi',
                    subtitle: 'Theo dõi trạng thái, chuyển khoản & nhận hàng',
                    onTap: () => context.push(RouteNames.myOrdersPath),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Quản lý đơn bán hàng (Người bán)',
                    subtitle: 'Xác nhận đơn mới, kiểm tra thanh toán & giao hàng',
                    onTap: () => context.push(RouteNames.sellerOrdersPath),
                  ),
                  if (user != null && user.id.isNotEmpty) ...[
                    const Divider(height: 1),
                    _ProfileMenuTile(
                      icon: Icons.star_outline_rounded,
                      title: 'Đánh giá & Điểm uy tín người bán',
                      subtitle: (user.stats?.totalReviews ?? 0) > 0
                          ? '${(user.stats?.rating ?? 0).toStringAsFixed(1)} ★ (${user.stats?.totalReviews} đánh giá) • Uy tín ${user.stats?.reputationScore ?? 66}/100'
                          : 'Xem chi tiết điểm uy tín & phản hồi đánh giá từ người mua',
                      onTap: () => context.push(
                        RouteNames.sellerReviews(user.id),
                        extra: user.displayName,
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  _ProfileMenuTile(
                    icon: Icons.notifications_active_outlined,
                    title: unreadNotifsCount > 0
                        ? 'Thông báo đơn hàng ($unreadNotifsCount mới)'
                        : 'Thông báo đơn hàng',
                    subtitle: 'Cập nhật mới nhất về đơn mua và đơn bán của bạn',
                    onTap: () => context.push(RouteNames.notificationsPath),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Quản lý tin đăng & Bản nháp',
                    subtitle: 'Đổi trạng thái, chỉnh sửa hoặc xóa tin đăng',
                    onTap: () => context.push(RouteNames.myListingsPath),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuTile(
                    icon: Icons.favorite_border_rounded,
                    title: 'Sản phẩm yêu thích ($wishlistCount)',
                    subtitle: 'Danh sách các món đồ cũ bạn đã lưu',
                    onTap: () => context.push(RouteNames.wishlistPath),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuTile(
                    icon: Icons.flag_outlined,
                    title: 'Lịch sử báo cáo vi phạm',
                    subtitle: 'Theo dõi trạng thái xử lý các báo cáo của bạn',
                    onTap: () => context.push(RouteNames.myReportsPath),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Chỉnh sửa thông tin cá nhân',
                    subtitle: 'Cập nhật tên hiển thị, số điện thoại, khu vực',
                    onTap: () => context.push(RouteNames.editProfilePath),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuTile(
                    icon: Icons.settings_outlined,
                    title: 'Cài đặt & Bộ nhớ đệm ngoại tuyến',
                    subtitle: 'Kiểm tra môi trường kết nối & xóa cache',
                    onTap: () => context.push(RouteNames.settingsPath),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Logout Action
            RmButton(
              key: const Key('logout_button'),
              label: 'Đăng xuất tài khoản',
              icon: Icons.logout_rounded,
              variant: RmButtonVariant.danger,
              isLoading: authState.isSubmitting,
              onPressed: () {
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RmCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
          Text(
            label,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryTintBg,
            borderRadius: AppSpacing.borderRadiusSm,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: AppTypography.titleMedium),
        subtitle: Text(subtitle, style: AppTypography.bodySmall),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}
