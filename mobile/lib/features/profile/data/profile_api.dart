import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session.dart';

class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.displayName,
    required this.bio,
    required this.city,
    required this.country,
    required this.gender,
    required this.hobbiesText,
    required this.visible,
    this.avatarFileName = '',
  });

  final String displayName;
  final String bio;
  final String city;
  final String country;
  final String gender;
  final String hobbiesText;
  final bool visible;
  final String avatarFileName;

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'bio': bio,
      'avatar_file_name': avatarFileName,
      'city': city,
      'country': country,
      'gender': gender,
      'hobbies_text': hobbiesText,
      'visible': visible,
    };
  }
}

class PublicProfile {
  const PublicProfile({
    required this.userID,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
    required this.country,
    required this.bio,
    required this.gender,
    required this.hobbiesText,
    required this.visible,
    required this.connectionStatus,
  });

  final String userID;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;
  final String country;
  final String bio;
  final String gender;
  final String hobbiesText;
  final bool visible;
  final String connectionStatus;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      userID: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      hobbiesText: json['hobbies_text'] as String? ?? '',
      visible: json['visible'] as bool? ?? true,
      connectionStatus: json['connection_status'] as String? ?? '',
    );
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

  Future<PublicProfile> getProfile({
    required String token,
    required String userID,
  }) async {
    final response = await _client.get(
      '/api/v1/profile/$userID',
      authToken: token,
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing profile payload');
    }

    return PublicProfile.fromJson(data);
  }
}
