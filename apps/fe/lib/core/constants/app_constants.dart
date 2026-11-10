/// Application-wide constants for ReMarket.
abstract final class AppConstants {
  static const String appName = 'ReMarket';
  static const String appTagline = 'Chợ đồ cũ thông minh & minh bạch';

  // Secure storage keys (Tokens)
  static const String accessTokenKey = 'remarket_access_token';
  static const String refreshTokenKey = 'remarket_refresh_token';

  // SharedPreferences keys (Non-sensitive preferences & cache)
  static const String cachedUserJsonKey = 'remarket_cached_user_json';
  static const String onboardingCompletedKey = 'remarket_onboarding_completed';
  static const String lastListingDraftJsonKey = 'remarket_listing_draft_json';

  // Default pagination
  static const int defaultPage = 1;
  static const int defaultPageSize = 20;
}
