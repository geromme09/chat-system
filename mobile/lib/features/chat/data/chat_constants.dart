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

class ChatSystemMessageBodies {
  static const connection = '__system_connected__';
}

class ChatRealtimeFields {
  static const event = 'event';
  static const conversationID = 'conversation_id';
  static const message = 'message';
  static const userID = 'user_id';
  static const readerUserID = 'reader_user_id';
  static const lastReadMessageID = 'last_read_message_id';
  static const readAt = 'read_at';
  static const isOnline = 'is_online';
  static const notification = 'notification';
  static const token = 'token';
}

class ChatRealtimeEvents {
  static const messageCreated = 'chat.message.created';
  static const conversationRead = 'chat.conversation.read';
  static const typingStarted = 'chat.typing.started';
  static const typingStopped = 'chat.typing.stopped';
  static const presenceUpdated = 'chat.presence.updated';
  static const notificationCreated = 'notification.created';
}
