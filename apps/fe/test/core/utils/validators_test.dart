import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/core/utils/validators.dart';

void main() {
  group('AppValidators (Aligned with NestJS DTO rules)', () {
    test('validateEmail enforces valid email format', () {
      expect(AppValidators.validateEmail(''), isNotNull);
      expect(AppValidators.validateEmail('not-an-email'), isNotNull);
      expect(
        AppValidators.validateEmail('nguyen.an@student.edu.vn'),
        isNull,
      );
    });

    test('validateRegisterPassword enforces 8..72 chars and letter + number', () {
      expect(AppValidators.validateRegisterPassword(''), isNotNull);
      expect(AppValidators.validateRegisterPassword('short1'), isNotNull);
      expect(AppValidators.validateRegisterPassword('onlyletters'), isNotNull);
      expect(AppValidators.validateRegisterPassword('123456789'), isNotNull);
      expect(AppValidators.validateRegisterPassword('Password123'), isNull);
      expect(AppValidators.validateRegisterPassword('Password123!'), isNull);
    });

    test('validateConfirmPassword checks equality with password', () {
      expect(
        AppValidators.validateConfirmPassword('', 'Password123'),
        isNotNull,
      );
      expect(
        AppValidators.validateConfirmPassword('Mismatch123', 'Password123'),
        isNotNull,
      );
      expect(
        AppValidators.validateConfirmPassword('Password123', 'Password123'),
        isNull,
      );
    });

    test('validateDisplayName enforces 2..60 characters', () {
      expect(AppValidators.validateDisplayName(''), isNotNull);
      expect(AppValidators.validateDisplayName('A'), isNotNull);
      expect(AppValidators.validateDisplayName('Nguyễn Văn An'), isNull);
    });

    test('validateOptionalPhone allows empty or valid phone strings', () {
      expect(AppValidators.validateOptionalPhone(''), isNull);
      expect(AppValidators.validateOptionalPhone('abc'), isNotNull);
      expect(AppValidators.validateOptionalPhone('0901234567'), isNull);
      expect(AppValidators.validateOptionalPhone('+84 901 234 567'), isNull);
    });
  });
}
