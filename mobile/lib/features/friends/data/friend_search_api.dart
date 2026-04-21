import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class FriendConnectionStatus {
  static const add = 'add';
  static const requested = 'requested';
  static const incomingRequest = 'incoming_request';
  static const friends = 'friends';
}

class FriendSearchResult {
  const FriendSearchResult({
    required this.userID,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
    required this.connectionStatus,
  });

  final String userID;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;
  final String connectionStatus;

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    return FriendSearchResult(
      userID: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      city: json['city'] as String? ?? '',
      connectionStatus:
          json['connection_status'] as String? ?? FriendConnectionStatus.add,
    );
  }
}

class FriendSearchApi {
  FriendSearchApi({
    ApiClient? client,
  }) : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  Future<List<FriendSearchResult>> searchUsers({
    required String token,
    required String query,
    int limit = 10,
  }) async {
    final response = await _client.get(
      '/api/v1/users/search',
      queryParameters: {
        'q': query,
        'limit': '$limit',
      },
      authToken: token,
    );

    final data = response['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Missing search payload');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(FriendSearchResult.fromJson)
        .toList();
  }
}
