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
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../providers/profile_providers.dart';

/// Edit Profile Screen (`PATCH /api/v1/users/me`).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountHolderController;
  late final TextEditingController _bankBranchController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _displayNameController =
        TextEditingController(text: user?.displayName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _locationController = TextEditingController(text: user?.location ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _bankNameController =
        TextEditingController(text: user?.bankInfo?.bankName ?? '');
    _accountNumberController =
        TextEditingController(text: user?.bankInfo?.accountNumber ?? '');
    _accountHolderController =
        TextEditingController(text: user?.bankInfo?.accountHolder ?? '');
    _bankBranchController =
        TextEditingController(text: user?.bankInfo?.branch ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _bankBranchController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final bankInfo = UserBankInfoModel(
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      accountHolder: _accountHolderController.text.trim(),
      branch: _bankBranchController.text.trim().isNotEmpty
          ? _bankBranchController.text.trim()
          : null,
    );

    final result = await ref.read(profileRepositoryProvider).updateMyProfile(
          displayName: _displayNameController.text.trim(),
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : null,
          bankInfo: bankInfo.isConfigured ? bankInfo : null,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.when(
      success: (updatedUser, _, _) {
        ref
            .read(authControllerProvider.notifier)
            .updateCurrentUser(updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật hồ sơ cá nhân thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
        if (context.canPop()) {
          context.pop();
        }
      },
      failure: (error) {
        setState(() => _errorMessage = error.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ cá nhân'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null) ...[
                RmErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              RmCard(
                child: Column(
                  children: [
                    RmTextField(
                      label: 'Tên hiển thị *',
                      hintText: 'Nhập họ tên hoặc tên cửa hàng',
                      controller: _displayNameController,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (val) {
                        if (val == null || val.trim().length < 2) {
                          return 'Tên hiển thị phải từ 2 ký tự trở lên';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RmTextField(
                      label: 'Số điện thoại liên hệ',
                      hintText: 'VD: 0901234567',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RmTextField(
                      label: 'Khu vực giao dịch mặc định',
                      hintText: 'VD: Quận Cầu Giấy, Hà Nội',
                      controller: _locationController,
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RmTextField(
                      label: 'Giới thiệu ngắn (Bio)',
                      hintText:
                          'Chia sẻ cam kết bán hàng minh bạch hoặc khung giờ giao dịch...',
                      controller: _bioController,
                      maxLines: 3,
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
                      'Tài khoản nhận chuyển khoản (Dành cho Người bán)',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thông tin này được bảo mật và chỉ hiển thị cho người mua có đơn hàng hợp lệ.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RmTextField(
                      label: 'Tên ngân hàng',
                      hintText: 'VD: Vietcombank, MB Bank, Techcombank...',
                      controller: _bankNameController,
                      prefixIcon: Icons.account_balance_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RmTextField(
                      label: 'Số tài khoản nhận tiền',
                      hintText: 'VD: 1029384756',
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.credit_card_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RmTextField(
                      label: 'Tên chủ tài khoản (Viết hoa không dấu)',
                      hintText: 'VD: NGUYEN MINH KHOA',
                      controller: _accountHolderController,
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RmTextField(
                      label: 'Chi nhánh (Tùy chọn)',
                      hintText: 'VD: CN TP.HCM',
                      controller: _bankBranchController,
                      prefixIcon: Icons.business_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              RmButton(
                label: 'Lưu thay đổi',
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
