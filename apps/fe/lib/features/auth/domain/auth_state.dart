import '../../../../core/errors/api_exception.dart';
import '../../../../shared/models/user_model.dart';

/// High-level lifecycle status of the user's authentication session.
enum AuthStatus {
  /// App just launched; session restoration has not finished yet.
  initial,

  /// Actively checking stored tokens & `/api/v1/auth/me`.
  restoring,

  /// Authenticated with a valid user & token pair.
  authenticated,

  /// No active session (guest / logged out).
  unauthenticated,
}

/// Immutable state managed by `AuthController` (Riverpod).
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isSubmitting = false,
    this.error,
  });

  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        isSubmitting = false,
        error = null;

  final AuthStatus status;
  final UserModel? user;
  final bool isSubmitting;
  final ApiException? error;

  bool get isRestoring =>
      status == AuthStatus.initial || status == AuthStatus.restoring;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  bool get isUnauthenticated => status == AuthStatus.unauthenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool clearUser = false,
    bool? isSubmitting,
    ApiException? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
