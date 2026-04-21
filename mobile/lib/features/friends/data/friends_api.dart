import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class FriendSummary {
  const FriendSummary({
    required this.userID,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
  });

  final String userID;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;

  factory FriendSummary.fromJson(Map<String, dynamic> json) {
    return FriendSummary(
      userID: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      city: json['city'] as String? ?? '',
    );
  }
}

class FriendRequestRecord {
  const FriendRequestRecord({
    required this.id,
    required this.status,
    required this.requester,
    required this.addressee,
  });

  final String id;
  final String status;
  final FriendSummary requester;
  final FriendSummary addressee;

  factory FriendRequestRecord.fromJson(Map<String, dynamic> json) {
    return FriendRequestRecord(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      requester: FriendSummary.fromJson(
        json['requester'] as Map<String, dynamic>? ?? const {},
      ),
      addressee: FriendSummary.fromJson(
        json['addressee'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class FriendsApi {
  FriendsApi({
    ApiClient? client,
  }) : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  Future<void> sendFriendRequest({
    required String token,
    required String targetUserID,
  }) async {
    await _client.post(
      '/api/v1/friends/requests',
      authToken: token,
      body: {
        'target_user_id': targetUserID,
      },
    );
  }

  Future<List<FriendRequestRecord>> listIncomingRequests({
    required String token,
  }) async {
    final response = await _client.get(
      '/api/v1/friends/requests/incoming',
      authToken: token,
    );

    final data = response['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Missing incoming requests payload');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(FriendRequestRecord.fromJson)
        .toList();
  }

  Future<void> respondToRequest({
    required String token,
    required String requestID,
    required String action,
  }) async {
    await _client.post(
      '/api/v1/friends/requests/$requestID/$action',
      authToken: token,
    );
  }

  Future<List<FriendSummary>> listFriends({
    required String token,
  }) async {
    final response = await _client.get(
      '/api/v1/friends',
      authToken: token,
    );

    final data = response['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Missing friends payload');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(FriendSummary.fromJson)
        .toList();
  }
}
