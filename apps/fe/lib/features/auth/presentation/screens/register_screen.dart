import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/rm_button.dart';
import '../../../../core/widgets/rm_card.dart';
import '../../../../core/widgets/rm_error_state.dart';
import '../../../../core/widgets/rm_text_field.dart';
import '../controllers/auth_controller.dart';

/// Register Screen (`03 - Register` in `PROJECT_PLAN.md`) connected to the real
/// NestJS `POST /api/v1/auth/register` endpoint.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _acceptedTransparencyPledge = true;
  String? _pledgeError;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).clearError();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!_acceptedTransparencyPledge) {
      setState(() {
        _pledgeError =
            'Vui lòng đồng ý cam kết khai báo minh bạch tình trạng sản phẩm.';
      });
      return;
    }
    setState(() {
      _pledgeError = null;
    });

    if (!isValid) {
      return;
    }

    await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          phone: _phoneController.text.trim(),
          location: _locationController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: authState.isSubmitting
              ? null
              : () {
                  ref.read(authControllerProvider.notifier).clearError();
                  context.go(RouteNames.loginPath);
                },
        ),
        title: const Text('Tạo tài khoản ReMarket'),
      ),
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
                  RmCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Đăng ký thành viên mới',
                            style: AppTypography.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Tham gia cộng đồng mua bán đồ cũ minh bạch hỗ trợ bởi AI.',
                            style: AppTypography.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          if (authState.error != null) ...[
                            RmErrorBanner(
                              key: const Key('register_error_banner'),
                              message: authState.error!.message,
                              details: authState.error!.details,
                              onDismiss: () => ref
                                  .read(authControllerProvider.notifier)
                                  .clearError(),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],

                          RmTextField(
                            key: const Key('register_display_name_field'),
                            label: 'Họ và tên hiển thị *',
                            hintText: 'Nguyễn Văn An',
                            controller: _displayNameController,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.person_outline_rounded,
                            enabled: !authState.isSubmitting,
                            validator: AppValidators.validateDisplayName,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          RmTextField(
                            key: const Key('register_email_field'),
                            label: 'Email *',
                            hintText: 'nguyen.an@student.edu.vn',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.mail_outline_rounded,
                            enabled: !authState.isSubmitting,
                            validator: AppValidators.validateEmail,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          RmTextField(
                            key: const Key('register_phone_field'),
                            label: 'Số điện thoại / Zalo (Tùy chọn)',
                            hintText: '0901234567',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.phone_outlined,
                            enabled: !authState.isSubmitting,
                            validator: AppValidators.validateOptionalPhone,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          RmTextField(
                            key: const Key('register_location_field'),
                            label: 'Khu vực / Trường đại học (Tùy chọn)',
                            hintText: 'Khu đô thị ĐHQG TP.HCM, Thủ Đức',
                            controller: _locationController,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.location_on_outlined,
                            enabled: !authState.isSubmitting,
                            validator: AppValidators.validateOptionalLocation,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          RmTextField(
                            key: const Key('register_password_field'),
                            label: 'Mật khẩu *',
                            hintText: 'Ít nhất 8 ký tự, gồm chữ và số',
                            controller: _passwordController,
                            isPassword: true,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.lock_outline_rounded,
                            enabled: !authState.isSubmitting,
                            validator: AppValidators.validateRegisterPassword,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          RmTextField(
                            key: const Key('register_confirm_password_field'),
                            label: 'Xác nhận mật khẩu *',
                            hintText: 'Nhập lại mật khẩu',
                            controller: _confirmPasswordController,
                            isPassword: true,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.verified_user_outlined,
                            enabled: !authState.isSubmitting,
                            validator: (val) =>
                                AppValidators.validateConfirmPassword(
                              val,
                              _passwordController.text,
                            ),
                            onFieldSubmitted: (_) => _submitRegister(),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Transparency pledge checkbox
                          Material(
                            color: AppColors.primaryTintBg,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppSpacing.borderRadiusMd,
                              side: BorderSide(
                                color: AppColors.primaryTintBorder,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CheckboxListTile(
                              key: const Key('register_pledge_checkbox'),
                              value: _acceptedTransparencyPledge,
                              activeColor: AppColors.primary,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              title: Text(
                                'Tôi cam kết khai báo trung thực tình trạng và khuyết điểm sản phẩm khi đăng bán trên ReMarket.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              onChanged: authState.isSubmitting
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        _acceptedTransparencyPledge =
                                            checked ?? false;
                                        if (_acceptedTransparencyPledge) {
                                          _pledgeError = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                          if (_pledgeError != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _pledgeError!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),

                          RmButton(
                            key: const Key('register_submit_button'),
                            label: 'Tạo tài khoản',
                            icon: Icons.person_add_alt_1_rounded,
                            isLoading: authState.isSubmitting,
                            onPressed: _submitRegister,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản?',
                        style: AppTypography.bodyMedium,
                      ),
                      TextButton(
                        key: const Key('go_to_login_button'),
                        onPressed: authState.isSubmitting
                            ? null
                            : () {
                                ref
                                    .read(authControllerProvider.notifier)
                                    .clearError();
                                context.go(RouteNames.loginPath);
                              },
                        child: Text(
                          'Đăng nhập',
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
