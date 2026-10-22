import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_text_field.dart';
import '../controllers/auth_controller.dart';

/// Login Screen (`02 - Login` in `PROJECT_PLAN.md`) connected to the real
/// NestJS `POST /api/v1/auth/login` endpoint.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).clearError();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _fillSeededAccount({
    required String email,
    required String password,
  }) {
    _emailController.text = email;
    _passwordController.text = password;
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxAuthCardWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  // Brand Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              AppConstants.appName,
                              style: AppTypography.headlineLarge,
                            ),
                            Text(
                              AppConstants.appTagline,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  RmCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Đăng nhập tài khoản',
                            style: AppTypography.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Chào mừng bạn quay lại sàn giao dịch đồ cũ minh bạch ReMarket.',
                            style: AppTypography.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          if (authState.error != null) ...[
                            RmErrorBanner(
                              key: const Key('login_error_banner'),
                              message: authState.error!.message,
                              details: authState.error!.details,
                              onDismiss: () => ref
                                  .read(authControllerProvider.notifier)
                                  .clearError(),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          RmTextField(
                            key: const Key('login_email_field'),
                            label: 'Email',
                            hintText: 'nguyen.an@student.edu.vn',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.mail_outline_rounded,
                            enabled: !authState.isSubmitting,
                            validator: AppValidators.validateEmail,
                            autofillHints: const [AutofillHints.email],
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          RmTextField(
                            key: const Key('login_password_field'),
                            label: 'Mật khẩu',
                            hintText: 'Nhập mật khẩu của bạn',
                            controller: _passwordController,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.lock_outline_rounded,
                            enabled: !authState.isSubmitting,
                            validator: AppValidators.validateLoginPassword,
                            onFieldSubmitted: (_) => _submitLogin(),
                            autofillHints: const [AutofillHints.password],
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          RmButton(
                            key: const Key('login_submit_button'),
                            label: 'Đăng nhập',
                            icon: Icons.login_rounded,
                            isLoading: authState.isSubmitting,
                            onPressed: _submitLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Seeded Demo Accounts Helper Card (calls real Backend API)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: AppSpacing.aiTintBoxDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Điền nhanh tài khoản Seed (Backend thật)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.person_outline, size: 16),
                              label: const Text('Người bán (Nguyễn Minh Khoa)'),
                              onPressed: authState.isSubmitting
                                  ? null
                                  : () => _fillSeededAccount(
                                        email: 'khoa.nguyen@remarket.vn',
                                        password: 'ReMarket123!',
                                      ),
                            ),
                            ActionChip(
                              avatar: const Icon(
                                Icons.shopping_bag_outlined,
                                size: 16,
                              ),
                              label: const Text('Người mua (Trần Hoàng Minh)'),
                              onPressed: authState.isSubmitting
                                  ? null
                                  : () => _fillSeededAccount(
                                        email: 'minh.tran@student.edu.vn',
                                        password: 'ReMarket123!',
                                      ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Chưa có tài khoản?',
                        style: AppTypography.bodyMedium,
                      ),
                      TextButton(
                        key: const Key('go_to_register_button'),
                        onPressed: authState.isSubmitting
                            ? null
                            : () {
                                ref
                                    .read(authControllerProvider.notifier)
                                    .clearError();
                                context.go(RouteNames.registerPath);
                              },
                        child: Text(
                          'Đăng ký ngay',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
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
