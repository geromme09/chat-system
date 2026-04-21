import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session.dart';

class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.displayName,
    required this.bio,
    required this.city,
    required this.country,
    required this.sports,
    required this.skillLevel,
    required this.visible,
    this.avatarFileName = '',
  });

  final String displayName;
  final String bio;
  final String city;
  final String country;
  final List<String> sports;
  final String skillLevel;
  final bool visible;
  final String avatarFileName;

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'bio': bio,
      'avatar_file_name': avatarFileName,
      'city': city,
      'country': country,
      'sports': sports,
      'skill_level': skillLevel,
      'visible': visible,
    };
  }
}

class ProfileApi {
  ProfileApi({
    ApiClient? client,
  }) : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  Future<SessionProfile> updateMe({
    required String token,
    required UpdateProfileRequest request,
  }) async {
    final response = await _client.put(
      '/api/v1/profile/me',
      body: request.toJson(),
      authToken: token,
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing profile payload');
    }

    return SessionProfile.fromJson(data);
  }
}
