import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session.dart';

class SignUpRequest {
  const SignUpRequest({
    required this.email,
    required this.username,
    required this.password,
    required this.displayName,
    required this.city,
    this.bio = '',
    this.avatarFileName = '',
    this.country = '',
  });

  final String email;
  final String username;
  final String password;
  final String displayName;
  final String city;
  final String bio;
  final String avatarFileName;
  final String country;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'username': username,
      'password': password,
      'display_name': displayName,
      'bio': bio,
      'avatar_file_name': avatarFileName,
      'city': city,
      'country': country,
    };
  }
}

class AuthResult {
  const AuthResult({
    required this.token,
    required this.userID,
    required this.profile,
  });

  final String token;
  final String userID;
  final SessionProfile profile;

  factory AuthResult.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing auth payload');
    }

    final user = data['user'];
    final profile = data['profile'];
    if (user is! Map<String, dynamic> || profile is! Map<String, dynamic>) {
      throw const FormatException('Missing auth user or profile');
    }

    return AuthResult(
      token: data['token'] as String? ?? '',
      userID: user['id'] as String? ?? '',
      profile: SessionProfile.fromJson(profile),
    );
  }
}

class LoginRequest {
  const LoginRequest({
    required this.identifier,
    required this.password,
  });

  final String identifier;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'password': password,
    };
  }
}

class AuthApi {
  AuthApi({
    ApiClient? client,
  }) : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  Future<AuthResult> signUp(SignUpRequest request) async {
    final response = await _client.post(
      '/api/v1/auth/signup',
      body: request.toJson(),
    );

    return AuthResult.fromEnvelope(response);
  }

  Future<AuthResult> login(LoginRequest request) async {
    final response = await _client.post(
      '/api/v1/auth/login',
      body: request.toJson(),
    );

    return AuthResult.fromEnvelope(response);
  }
}
