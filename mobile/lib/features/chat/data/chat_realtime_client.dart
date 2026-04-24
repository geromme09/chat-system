import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/config/app_config.dart';
import 'chat_api.dart';
import 'chat_constants.dart';

enum ChatRealtimeStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class ChatRealtimeEvent {
  const ChatRealtimeEvent({
    required this.event,
    required this.conversationID,
    required this.userID,
    required this.isOnline,
    required this.notification,
    required this.lastReadMessageID,
    required this.readAt,
    this.message,
  });

  final String event;
  final String conversationID;
  final String userID;
  final bool isOnline;
  final Map<String, dynamic>? notification;
  final String lastReadMessageID;
  final DateTime? readAt;
  final ChatMessage? message;

  factory ChatRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return ChatRealtimeEvent(
      event: json[ChatRealtimeFields.event] as String? ?? '',
      conversationID: json[ChatRealtimeFields.conversationID] as String? ?? '',
      userID: (json[ChatRealtimeFields.userID] as String? ?? '').isNotEmpty
          ? json[ChatRealtimeFields.userID] as String? ?? ''
          : json[ChatRealtimeFields.readerUserID] as String? ?? '',
      isOnline: json[ChatRealtimeFields.isOnline] as bool? ?? false,
      notification:
          json[ChatRealtimeFields.notification] as Map<String, dynamic>?,
      lastReadMessageID:
          json[ChatRealtimeFields.lastReadMessageID] as String? ?? '',
      readAt: parseChatDateTime(json[ChatRealtimeFields.readAt]),
      message: (json[ChatRealtimeFields.message] as Map<String, dynamic>?)
          ?.let(ChatMessage.fromJson),
    );
  }
}

class ChatRealtimeClient {
  ChatRealtimeClient._();

  static const Duration _pingInterval = Duration(seconds: 20);
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 8);

  static final ChatRealtimeClient instance = ChatRealtimeClient._();

  final StreamController<ChatRealtimeEvent> _eventsController =
      StreamController<ChatRealtimeEvent>.broadcast();
  final StreamController<ChatRealtimeStatus> _statusController =
      StreamController<ChatRealtimeStatus>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  String? _activeToken;
  bool _isManualDisconnect = false;
  bool _isConnecting = false;
  Duration _nextReconnectDelay = _initialReconnectDelay;
  ChatRealtimeStatus _status = ChatRealtimeStatus.disconnected;
  final Set<String> _onlineUserIDs = <String>{};

  Stream<ChatRealtimeEvent> get events => _eventsController.stream;
  Stream<ChatRealtimeStatus> get statuses => _statusController.stream;

  bool get isConnected => _status == ChatRealtimeStatus.connected;
  ChatRealtimeStatus get status => _status;

  bool isUserOnline(String userID) {
    if (userID.trim().isEmpty) {
      return false;
    }
    return _onlineUserIDs.contains(userID);
  }

  Future<void> connect(String token) async {
    _activeToken = token;
    _isManualDisconnect = false;

    if (isConnected || _isConnecting) {
      return;
    }

    await _connectInternal(
      isReconnect: _status == ChatRealtimeStatus.reconnecting,
    );
  }

  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _cancelReconnect();
    await _disposeSocket();
    _onlineUserIDs.clear();
    _setStatus(ChatRealtimeStatus.disconnected);
  }

  Future<void> sendTypingStarted(String conversationID) async {
    await _sendEvent(
      event: ChatRealtimeEvents.typingStarted,
      conversationID: conversationID,
    );
  }

  Future<void> sendTypingStopped(String conversationID) async {
    await _sendEvent(
      event: ChatRealtimeEvents.typingStopped,
      conversationID: conversationID,
    );
  }

  Future<void> _sendEvent({
    required String event,
    required String conversationID,
  }) async {
    if (!isConnected || conversationID.isEmpty) {
      return;
    }

    final socket = _socket;
    if (socket == null) {
      return;
    }

    socket.add(
      jsonEncode({
        ChatRealtimeFields.event: event,
        ChatRealtimeFields.conversationID: conversationID,
      }),
    );
  }

  Future<void> _connectInternal({required bool isReconnect}) async {
    final token = _activeToken;
    if (token == null || token.isEmpty || _isConnecting) {
      return;
    }

    _isConnecting = true;
    _setStatus(
      isReconnect
          ? ChatRealtimeStatus.reconnecting
          : ChatRealtimeStatus.connecting,
    );

    try {
      await _disposeSocket();

      final uri = Uri.parse(
        AppConfig.chatWebSocketUrl,
      ).replace(queryParameters: {ChatRealtimeFields.token: token});
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: <String, dynamic>{
          HttpHeaders.authorizationHeader: 'Bearer $token',
        },
      );
      socket.pingInterval = _pingInterval;

      _socket = socket;
      _nextReconnectDelay = _initialReconnectDelay;
      _socketSubscription = socket.listen(
        _handleSocketEvent,
        onDone: _handleSocketClosed,
        onError: (_, __) => _handleSocketClosed(),
        cancelOnError: true,
      );
      _setStatus(ChatRealtimeStatus.connected);
    } finally {
      _isConnecting = false;
    }
  }

  void _handleSocketEvent(dynamic event) {
    if (event is! String) {
      return;
    }

    final decoded = jsonDecode(event);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    final realtimeEvent = ChatRealtimeEvent.fromJson(decoded);
    if (realtimeEvent.event == ChatRealtimeEvents.presenceUpdated &&
        realtimeEvent.userID.trim().isNotEmpty) {
      if (realtimeEvent.isOnline) {
        _onlineUserIDs.add(realtimeEvent.userID);
      } else {
        _onlineUserIDs.remove(realtimeEvent.userID);
      }
    }

    _eventsController.add(realtimeEvent);
  }

  void _handleSocketClosed() {
    _socket = null;
    _socketSubscription = null;
    _onlineUserIDs.clear();

    if (_isManualDisconnect) {
      _setStatus(ChatRealtimeStatus.disconnected);
      return;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_activeToken == null || _isConnecting) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) {
      return;
    }

    _setStatus(ChatRealtimeStatus.reconnecting);
    _reconnectTimer = Timer(_nextReconnectDelay, () async {
      _reconnectTimer = null;
      await _connectInternal(isReconnect: true);
    });
    if (_nextReconnectDelay < _maxReconnectDelay) {
      _nextReconnectDelay *= 2;
      if (_nextReconnectDelay > _maxReconnectDelay) {
        _nextReconnectDelay = _maxReconnectDelay;
      }
    }
  }

  Future<void> _disposeSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
    }
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _setStatus(ChatRealtimeStatus value) {
    if (_status == value) {
      return;
    }
    _status = value;
    _statusController.add(value);
  }
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}
