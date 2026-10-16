import 'package:flutter_test/flutter_test.dart';
import 'package:remarket_fe/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenStorage', () {
    test('InMemoryTokenStorage saves, reads, and clears tokens accurately', () async {
      final storage = InMemoryTokenStorage();
      expect(await storage.hasValidTokenPair(), isFalse);

      await storage.saveTokens(
        accessToken: 'jwt-access-001',
        refreshToken: 'jwt-refresh-001',
      );

      expect(await storage.hasValidTokenPair(), isTrue);
      expect(await storage.readAccessToken(), equals('jwt-access-001'));
      expect(await storage.readRefreshToken(), equals('jwt-refresh-001'));

      await storage.clearTokens();
      expect(await storage.hasValidTokenPair(), isFalse);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    });

    test('SecureTokenStorage persists and clears tokens with fallback support', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final storage = SecureTokenStorage(fallbackPreferences: prefs);

      await storage.saveTokens(
        accessToken: 'secure-access-token',
        refreshToken: 'secure-refresh-token',
      );

      expect(await storage.hasValidTokenPair(), isTrue);
      expect(await storage.readAccessToken(), equals('secure-access-token'));
      expect(await storage.readRefreshToken(), equals('secure-refresh-token'));

      await storage.clearTokens();
      expect(await storage.hasValidTokenPair(), isFalse);
    });
  });
}
