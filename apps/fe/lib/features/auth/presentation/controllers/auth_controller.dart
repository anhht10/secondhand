import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_result.dart';
import '../../../../core/storage/local_preferences.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/auth_remote_data_source.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_state.dart';

/// Provides the active [AppConfig] (Development / Production & API Base URL).
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Optional [SharedPreferences] instance injected at bootstrap time.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

/// Provides [LocalPreferences] when [SharedPreferences] is available.
final localPreferencesProvider = Provider<LocalPreferences?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (prefs == null) {
    return null;
  }
  return LocalPreferences(prefs);
});

/// Provides secure JWT [TokenStorage].
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SecureTokenStorage(fallbackPreferences: prefs);
});

/// Provides the single shared [ApiClient] instance across the entire app.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    config: config,
    tokenStorage: tokenStorage,
  );
});

/// Provides [AuthRemoteDataSource].
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRemoteDataSource(apiClient);
});

/// Provides [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final localPreferences = ref.watch(localPreferencesProvider);
  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    tokenStorage: tokenStorage,
    localPreferences: localPreferences,
  );
});

/// Minimum duration to keep the welcome SplashScreen visible on startup.
/// Defaults to [Duration.zero] for fast unit/widget tests; overridden in
/// `bootstrap()` for real application launches.
final splashMinDurationProvider = Provider<Duration>((ref) {
  return Duration.zero;
});

/// Provides the global [AuthController] & reactive [AuthState].
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final apiClient = ref.watch(apiClientProvider);
  final minSplashDuration = ref.watch(splashMinDurationProvider);
  final controller = AuthController(
    repository: repository,
    minSplashDuration: minSplashDuration,
  );

  // Wire automatic session expiration callback from AuthInterceptor
  apiClient.onSessionExpired = controller.handleSessionExpired;
  ref.onDispose(() {
    apiClient.onSessionExpired = null;
  });

  return controller;
});

/// Manages authentication lifecycle: session restoration, login, registration,
/// profile refresh, and logout.
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required this.repository,
    bool autoRestore = true,
    this.minSplashDuration = Duration.zero,
  }) : super(const AuthState.initial()) {
    if (autoRestore) {
      Future<void>.microtask(restoreSession);
    }
  }

  final AuthRepository repository;
  final Duration minSplashDuration;

  /// Restores user session on app launch if valid tokens exist in [TokenStorage].
  Future<void> restoreSession() async {
    if (state.status == AuthStatus.restoring) {
      return;
    }
    state = state.copyWith(
      status: AuthStatus.restoring,
      clearError: true,
    );

    final restoreFuture = repository.restoreSession();
    if (minSplashDuration > Duration.zero) {
      await Future.wait<void>(<Future<void>>[
        restoreFuture,
        Future<void>.delayed(minSplashDuration),
      ]);
    }
    final result = await restoreFuture;
    if (!mounted) return;

    if (result is NetworkSuccess<UserModel?> && result.data != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.data,
      );
    } else {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
      );
    }
  }

  /// Authenticates with `email` and `password` (`POST /api/v1/auth/login`).
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await repository.login(
      email: email,
      password: password,
    );
    if (!mounted) return false;

    return result.when(
      success: (user, _, _) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
        return true;
      },
      failure: (error) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isSubmitting: false,
          error: error,
        );
        return false;
      },
    );
  }

  /// Registers a new account (`POST /api/v1/auth/register`) and signs the user in.
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String? location,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await repository.register(
      email: email,
      password: password,
      displayName: displayName,
      phone: phone,
      location: location,
    );
    if (!mounted) return false;

    return result.when(
      success: (user, _, _) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
        return true;
      },
      failure: (error) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isSubmitting: false,
          error: error,
        );
        return false;
      },
    );
  }

  /// Reloads the authenticated user's profile from `/api/v1/auth/me`.
  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;
    final result = await repository.refreshProfile();
    if (!mounted) return;
    if (result is NetworkSuccess<UserModel>) {
      state = state.copyWith(user: result.data, clearError: true);
    }
  }

  /// Updates the in-memory authenticated user snapshot (e.g. after `PATCH /users/me`).
  void updateCurrentUser(UserModel updatedUser) {
    if (!mounted || !state.isAuthenticated) return;
    state = state.copyWith(user: updatedUser, clearError: true);
  }

  /// Logs out the current user and clears all stored tokens.
  Future<void> logout() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    await repository.logout();
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Invoked when `AuthInterceptor` detects an expired access token AND
  /// `/api/v1/auth/refresh` fails.
  void handleSessionExpired() {
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clears any displayed authentication error banner.
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}
