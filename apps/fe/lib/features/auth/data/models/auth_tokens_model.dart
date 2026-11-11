/// JWT Token Pair returned by `/auth/register`, `/auth/login`, and `/auth/refresh`.
class AuthTokensModel {
  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    final access = (json['accessToken'] as String?)?.trim() ?? '';
    final refresh = (json['refreshToken'] as String?)?.trim() ?? '';
    if (access.isEmpty || refresh.isEmpty) {
      throw const FormatException(
        'Invalid AuthTokensModel: accessToken and refreshToken are required.',
      );
    }
    return AuthTokensModel(
      accessToken: access,
      refreshToken: refresh,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}
