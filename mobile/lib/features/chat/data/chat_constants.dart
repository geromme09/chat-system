class ChatApiPaths {
  static const conversations = '/api/v1/chat/conversations';
  static const unreadCount = '/api/v1/chat/unread-count';

  static String conversationMessages(String conversationID) {
    return '$conversations/$conversationID/messages';
  }

  static String conversationRead(String conversationID) {
    return '$conversations/$conversationID/read';
  }
}

class ChatRealtimeFields {
  static const event = 'event';
  static const conversationID = 'conversation_id';
  static const message = 'message';
  static const userID = 'user_id';
  static const token = 'token';
}

class ChatRealtimeEvents {
  static const messageCreated = 'chat.message.created';
  static const typingStarted = 'chat.typing.started';
  static const typingStopped = 'chat.typing.stopped';
}
