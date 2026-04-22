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

  FriendRequestRecord copyWith({
    String? status,
  }) {
    return FriendRequestRecord(
      id: id,
      status: status ?? this.status,
      requester: requester,
      addressee: addressee,
    );
  }

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

class FriendNotificationRecord {
  const FriendNotificationRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.friendRequest,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final FriendRequestRecord? friendRequest;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isPendingIncomingRequest =>
      type == 'friend_request_received' &&
      friendRequest != null &&
      friendRequest!.status == 'pending';

  bool get isAcceptedRequest =>
      type == 'friend_request_accepted' &&
      friendRequest != null &&
      friendRequest!.status == 'accepted';

  FriendNotificationRecord copyWith({
    FriendRequestRecord? friendRequest,
    DateTime? readAt,
  }) {
    return FriendNotificationRecord(
      id: id,
      type: type,
      title: title,
      body: body,
      friendRequest: friendRequest ?? this.friendRequest,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory FriendNotificationRecord.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    final friendRequestJson = data['friend_request'] as Map<String, dynamic>?;

    return FriendNotificationRecord(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      friendRequest: friendRequestJson == null
          ? null
          : FriendRequestRecord.fromJson(friendRequestJson),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
    );
  }
}

class FriendsPage {
  const FriendsPage({
    required this.items,
    required this.page,
    required this.limit,
    this.nextPage,
  });

  final List<FriendSummary> items;
  final int page;
  final int limit;
  final int? nextPage;

  factory FriendsPage.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing friends payload');
    }

    final items = data['items'];
    if (items is! List<dynamic>) {
      throw const FormatException('Missing friends items payload');
    }

    return FriendsPage(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(FriendSummary.fromJson)
          .toList(),
      page: (data['page'] as num?)?.toInt() ?? 1,
      limit: (data['limit'] as num?)?.toInt() ?? 15,
      nextPage: (data['next_page'] as num?)?.toInt(),
    );
  }
}

class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.page,
    required this.limit,
    this.nextPage,
  });

  final List<FriendNotificationRecord> items;
  final int page;
  final int limit;
  final int? nextPage;

  factory NotificationsPage.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing notifications payload');
    }

    final items = data['items'];
    if (items is! List<dynamic>) {
      throw const FormatException('Missing notifications items payload');
    }

    return NotificationsPage(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(FriendNotificationRecord.fromJson)
          .toList(),
      page: (data['page'] as num?)?.toInt() ?? 1,
      limit: (data['limit'] as num?)?.toInt() ?? 15,
      nextPage: (data['next_page'] as num?)?.toInt(),
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

  Future<NotificationsPage> listNotifications({
    required String token,
    int page = 1,
    int limit = 15,
  }) async {
    final response = await _client.get(
      '/api/v1/notifications',
      authToken: token,
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
    );

    return NotificationsPage.fromEnvelope(response);
  }

  Future<void> markNotificationsRead({
    required String token,
  }) async {
    await _client.post(
      '/api/v1/notifications/read-all',
      authToken: token,
    );
  }

  Future<void> markNotificationRead({
    required String token,
    required String notificationID,
  }) async {
    await _client.post(
      '/api/v1/notifications/$notificationID/read',
      authToken: token,
    );
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

  Future<FriendsPage> listFriends({
    required String token,
    int page = 1,
    int limit = 15,
  }) async {
    final response = await _client.get(
      '/api/v1/friends',
      authToken: token,
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
      },
    );

    return FriendsPage.fromEnvelope(response);
  }
}
