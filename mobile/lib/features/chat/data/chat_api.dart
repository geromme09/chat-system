import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'chat_constants.dart';

class ChatParticipant {
  const ChatParticipant({
    required this.userID,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
    required this.isOnline,
  });

  final String userID;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;
  final bool isOnline;

  String get primaryLabel =>
      displayName.trim().isEmpty ? username : displayName;

  String get secondaryLabel => city.trim().isEmpty ? '@$username' : city;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      userID: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      city: json['city'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
    );
  }
}

class ChatConversationSummary {
  const ChatConversationSummary({
    required this.id,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessageBody,
    required this.lastMessageSenderID,
    required this.unreadCount,
    required this.otherParticipant,
  });

  final String id;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final String lastMessageBody;
  final String lastMessageSenderID;
  final int unreadCount;
  final ChatParticipant otherParticipant;

  factory ChatConversationSummary.fromJson(Map<String, dynamic> json) {
    return ChatConversationSummary(
      id: json['id'] as String? ?? '',
      createdAt: parseChatDateTime(json['created_at']),
      lastMessageAt: parseChatDateTime(json['last_message_at']),
      lastMessageBody: json['last_message_body'] as String? ?? '',
      lastMessageSenderID: json['last_message_sender_id'] as String? ?? '',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      otherParticipant: ChatParticipant.fromJson(
        json['other_participant'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationID,
    required this.senderUserID,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationID;
  final String senderUserID;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationID: json['conversation_id'] as String? ?? '',
      senderUserID: json['sender_user_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: parseChatDateTime(json['created_at']),
      readAt: parseChatDateTime(json['read_at']),
    );
  }
}

class ConversationReadResult {
  const ConversationReadResult({
    required this.conversationID,
    required this.markedCount,
  });

  final String conversationID;
  final int markedCount;

  factory ConversationReadResult.fromJson(Map<String, dynamic> json) {
    return ConversationReadResult(
      conversationID: json['conversation_id'] as String? ?? '',
      markedCount: (json['marked_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatUnreadCount {
  const ChatUnreadCount({
    required this.total,
  });

  final int total;

  factory ChatUnreadCount.fromJson(Map<String, dynamic> json) {
    return ChatUnreadCount(
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreateConversationRequest {
  const CreateConversationRequest({
    required this.participantIDs,
  });

  final List<String> participantIDs;

  Map<String, dynamic> toJson() {
    return {
      'participant_ids': participantIDs,
    };
  }
}

class SendMessageRequest {
  const SendMessageRequest({
    required this.body,
  });

  final String body;

  Map<String, dynamic> toJson() {
    return {
      'body': body,
    };
  }
}

class ChatApi {
  ChatApi({
    ApiClient? client,
  }) : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  Future<List<ChatConversationSummary>> listConversations({
    required String token,
  }) async {
    final response = await _client.get(
      ChatApiPaths.conversations,
      authToken: token,
    );

    final data = response['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Missing conversations payload');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatConversationSummary.fromJson)
        .toList();
  }

  Future<ChatConversationSummary> createConversation({
    required String token,
    required CreateConversationRequest request,
  }) async {
    final response = await _client.post(
      ChatApiPaths.conversations,
      authToken: token,
      body: request.toJson(),
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing conversation payload');
    }

    return ChatConversationSummary.fromJson(data);
  }

  Future<List<ChatMessage>> listMessages({
    required String token,
    required String conversationID,
  }) async {
    final response = await _client.get(
      ChatApiPaths.conversationMessages(conversationID),
      authToken: token,
    );

    final data = response['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Missing messages payload');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String token,
    required String conversationID,
    required SendMessageRequest request,
  }) async {
    final response = await _client.post(
      ChatApiPaths.conversationMessages(conversationID),
      authToken: token,
      body: request.toJson(),
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing message payload');
    }

    return ChatMessage.fromJson(data);
  }

  Future<ConversationReadResult> markConversationRead({
    required String token,
    required String conversationID,
  }) async {
    final response = await _client.post(
      ChatApiPaths.conversationRead(conversationID),
      authToken: token,
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing read payload');
    }

    return ConversationReadResult.fromJson(data);
  }

  Future<ChatUnreadCount> getUnreadCount({
    required String token,
  }) async {
    final response = await _client.get(
      ChatApiPaths.unreadCount,
      authToken: token,
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing unread count payload');
    }

    return ChatUnreadCount.fromJson(data);
  }
}

DateTime? parseChatDateTime(Object? rawValue) {
  final value = rawValue as String? ?? '';
  if (value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toLocal();
}
