/// Form validation utilities aligned 1:1 with the NestJS Backend DTO constraints
/// documented in `docs/api/API_CONTRACT.md` & `docs/api/AUTHENTICATION.md`.
abstract final class AppValidators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  /// Matches NestJS `RegisterDto` password rule:
  /// 8..72 characters, at least 1 letter and 1 number.
  static final RegExp _registerPasswordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d).{8,72}$',
  );

  /// Matches NestJS `RegisterDto` / `UpdateUserDto` phone rule:
  /// `/^[0-9+\-\s()]{8,20}$/`
  static final RegExp _phoneRegex = RegExp(r'^[0-9+\-\s()]{8,20}$');

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập địa chỉ email.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Địa chỉ email không hợp lệ.';
    }
    return null;
  }

  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    return null;
  }

  static String? validateRegisterPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    if (value.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự.';
    }
    if (value.length > 72) {
      return 'Mật khẩu không được vượt quá 72 ký tự.';
    }
    if (!_registerPasswordRegex.hasMatch(value)) {
      return 'Mật khẩu phải bao gồm ít nhất 1 chữ cái và 1 chữ số.';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng xác nhận lại mật khẩu.';
    }
    if (value != password) {
      return 'Mật khẩu xác nhận không khớp.';
    }
    return null;
  }

  static String? validateDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập họ và tên hiển thị.';
    }
    if (trimmed.length < 2) {
      return 'Tên hiển thị phải có ít nhất 2 ký tự.';
    }
    if (trimmed.length > 60) {
      return 'Tên hiển thị không được vượt quá 60 ký tự.';
    }
    return null;
  }

  static String? validateOptionalPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (!_phoneRegex.hasMatch(trimmed)) {
      return 'Số điện thoại không hợp lệ (8–20 ký tự số).';
    }
    return null;
  }

  static String? validateOptionalLocation(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > 120) {
      return 'Khu vực/Trường học không được vượt quá 120 ký tự.';
    }
    return null;
  }
}
