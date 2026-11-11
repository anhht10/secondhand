import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/user_model.dart';
import '../constants/app_constants.dart';

/// Manages non-sensitive local preferences, offline feed cache, and listing drafts.
///
/// Security rule: Tokens and passwords are NEVER stored in [SharedPreferences].
class LocalPreferences {
  const LocalPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _cachedProductsKey = 'remarket_cached_products_v1';
  static const String _cachedCategoriesKey = 'remarket_cached_categories_v1';

  // ---------------------------------------------------------------------------
  // 1. User Profile Snapshot
  // ---------------------------------------------------------------------------

  Future<void> saveUserSnapshot(UserModel user) async {
    final encoded = jsonEncode(user.toJson());
    await _prefs.setString(AppConstants.cachedUserJsonKey, encoded);
  }

  UserModel? readUserSnapshot() {
    final raw = _prefs.getString(AppConstants.cachedUserJsonKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UserModel.fromJson(decoded);
      }
    } catch (_) {
      // Ignore corrupted snapshot
    }
    return null;
  }

  Future<void> clearUserSnapshot() async {
    await _prefs.remove(AppConstants.cachedUserJsonKey);
  }

  // ---------------------------------------------------------------------------
  // 2. Offline Product Feed Cache (`F10`)
  // ---------------------------------------------------------------------------

  Future<void> saveCachedProductsJson(List<Map<String, dynamic>> items) async {
    final payload = <String, dynamic>{
      'cachedAt': DateTime.now().toIso8601String(),
      'items': items.take(24).toList(growable: false),
    };
    await _prefs.setString(_cachedProductsKey, jsonEncode(payload));
  }

  List<Map<String, dynamic>> readCachedProductsJson() {
    final raw = _prefs.getString(_cachedProductsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        return (decoded['items'] as List)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
    } catch (_) {
      // Ignore corrupted cache
    }
    return const <Map<String, dynamic>>[];
  }

  DateTime? readCachedProductsTimestamp() {
    final raw = _prefs.getString(_cachedProductsKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['cachedAt'] is String) {
        return DateTime.tryParse(decoded['cachedAt'] as String);
      }
    } catch (_) {
      // Ignore
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 3. Offline Categories Cache
  // ---------------------------------------------------------------------------

  Future<void> saveCachedCategoriesJson(List<Map<String, dynamic>> items) async {
    await _prefs.setString(_cachedCategoriesKey, jsonEncode(items));
  }

  List<Map<String, dynamic>> readCachedCategoriesJson() {
    final raw = _prefs.getString(_cachedCategoriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    } catch (_) {
      // Ignore
    }
    return const <Map<String, dynamic>>[];
  }

  // ---------------------------------------------------------------------------
  // 4. Local Listing Draft Persistence (`F09`)
  // ---------------------------------------------------------------------------

  Future<void> saveListingDraftJson(Map<String, dynamic> draftJson) async {
    await _prefs.setString(
      AppConstants.lastListingDraftJsonKey,
      jsonEncode(draftJson),
    );
  }

  Map<String, dynamic>? readListingDraftJson() {
    final raw = _prefs.getString(AppConstants.lastListingDraftJsonKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore
    }
    return null;
  }

  Future<void> clearListingDraftJson() async {
    await _prefs.remove(AppConstants.lastListingDraftJsonKey);
  }

  // ---------------------------------------------------------------------------
  // 5. Buyer Inspection Checklist Checkmarks
  // ---------------------------------------------------------------------------

  Future<void> saveCheckedChecklistIndices(
    String productId,
    Set<int> indices,
  ) async {
    await _prefs.setStringList(
      'remarket_checklist_checked_$productId',
      indices.map((i) => i.toString()).toList(growable: false),
    );
  }

  Set<int> readCheckedChecklistIndices(String productId) {
    final list = _prefs.getStringList('remarket_checklist_checked_$productId');
    if (list == null) {
      return <int>{};
    }
    return list.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> clearAllCaches() async {
    await _prefs.remove(_cachedProductsKey);
    await _prefs.remove(_cachedCategoriesKey);
    await _prefs.remove(AppConstants.lastListingDraftJsonKey);
  }
}
