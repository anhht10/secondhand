import '../../../../shared/models/user_model.dart';
import 'auth_tokens_model.dart';

/// Combined payload returned in `data` by:
/// - `POST /api/v1/auth/register`
/// - `POST /api/v1/auth/login`
/// - `POST /api/v1/auth/refresh`
class AuthResponseModel {
  const AuthResponseModel({
    required this.user,
    required this.tokens,
  });

  final UserModel user;
  final AuthTokensModel tokens;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final rawTokens = json['tokens'];
    if (rawUser is! Map<String, dynamic> ||
        rawTokens is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid AuthResponseModel: expected user and tokens objects.',
      );
    }
    return AuthResponseModel(
      user: UserModel.fromJson(rawUser),
      tokens: AuthTokensModel.fromJson(rawTokens),
    );
  }
}
