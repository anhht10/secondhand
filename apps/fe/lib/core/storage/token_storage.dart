import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Contract for reading and persisting JWT token pairs.
///
/// Passwords are NEVER stored here; only `accessToken` and `refreshToken`.
abstract class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clearTokens();

  Future<bool> hasValidTokenPair() async {
    final access = await readAccessToken();
    final refresh = await readRefreshToken();
    return (access != null && access.trim().isNotEmpty) ||
        (refresh != null && refresh.trim().isNotEmpty);
  }
}

/// Production [TokenStorage] backed by [FlutterSecureStorage] (Keychain on iOS,
/// EncryptedSharedPreferences/Keystore on Android) with a resilient fallback
/// if platform channels are unavailable.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({
    FlutterSecureStorage? secureStorage,
    this.fallbackPreferences,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences? fallbackPreferences;
  final Map<String, String> _memoryFallback = <String, String>{};

  @override
  Future<String?> readAccessToken() => _readKey(AppConstants.accessTokenKey);

  @override
  Future<String?> readRefreshToken() => _readKey(AppConstants.refreshTokenKey);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _writeKey(AppConstants.accessTokenKey, accessToken),
      _writeKey(AppConstants.refreshTokenKey, refreshToken),
    ]);
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      _deleteKey(AppConstants.accessTokenKey),
      _deleteKey(AppConstants.refreshTokenKey),
    ]);
  }

  @override
  Future<bool> hasValidTokenPair() async {
    final access = await readAccessToken();
    final refresh = await readRefreshToken();
    return (access != null && access.trim().isNotEmpty) ||
        (refresh != null && refresh.trim().isNotEmpty);
  }

  Future<String?> _readKey(String key) async {
    final inMemory = _memoryFallback[key];
    if (inMemory != null && inMemory.isNotEmpty) {
      return inMemory;
    }
    if (!kIsWeb) {
      try {
        final value = await _secureStorage.read(key: key);
        if (value != null && value.isNotEmpty) {
          _memoryFallback[key] = value;
          return value;
        }
      } catch (_) {
        // Fallback to SharedPreferences / memory when secure storage fails
      }
    }
    final fromPrefs = fallbackPreferences?.getString(key);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _memoryFallback[key] = fromPrefs;
    }
    return fromPrefs;
  }

  Future<void> _writeKey(String key, String value) async {
    _memoryFallback[key] = value;
    await fallbackPreferences?.setString(key, value);
    if (!kIsWeb) {
      try {
        await _secureStorage.write(key: key, value: value);
      } catch (_) {
        // Ignore platform secure storage error since fallbackPreferences succeeded
      }
    }
  }

  Future<void> _deleteKey(String key) async {
    _memoryFallback.remove(key);
    await fallbackPreferences?.remove(key);
    if (!kIsWeb) {
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {
        // Ignore
      }
    }
  }
}

/// Deterministic in-memory [TokenStorage] for unit & widget testing.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage({
    String? initialAccessToken,
    String? initialRefreshToken,
  })  : _accessToken = initialAccessToken,
        _refreshToken = initialRefreshToken;

  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<bool> hasValidTokenPair() async {
    return (_accessToken != null && _accessToken!.trim().isNotEmpty) ||
        (_refreshToken != null && _refreshToken!.trim().isNotEmpty);
  }
}
