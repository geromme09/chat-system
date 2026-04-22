import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../data/chat_api.dart';
import '../data/chat_constants.dart';
import '../data/chat_realtime_client.dart';
import '../data/chat_unread_controller.dart';

class ChatConversationArgs {
  const ChatConversationArgs({
    required this.conversationID,
    required this.title,
    required this.participantUserID,
    required this.subtitle,
  });

  final String conversationID;
  final String title;
  final String participantUserID;
  final String subtitle;
}

class _LoadedConversationData {
  const _LoadedConversationData({
    required this.messages,
    required this.firstUnreadMessageID,
  });

  final List<ChatMessage> messages;
  final String? firstUnreadMessageID;
}

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.args,
  });

  final ChatConversationArgs args;

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  static const Duration _typingStopDelay = Duration(milliseconds: 900);
  static const double _bottomScrollThreshold = 120;

  final ChatApi _chatApi = ChatApi();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[];
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<ChatRealtimeStatus>? _statusSubscription;
  Timer? _typingStopTimer;

  bool _isLoading = true;
  bool _isSending = false;
  bool _isOtherUserTyping = false;
  bool _didInitialPosition = false;
  bool _didSendTypingStarted = false;
  String? _errorMessage;
  String? _pendingScrollTargetMessageID;
  late String _presenceLabel;
  late final WidgetsBindingObserver _lifecycleObserver =
      _ChatLifecycleObserver(onResumed: _handleAppResumed);

  @override
  void initState() {
    super.initState();
    _presenceLabel = _currentPresenceLabel();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _loadConversation();
    _connectRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _typingStopTimer?.cancel();
    _statusSubscription?.cancel();
    _realtimeSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _fetchConversationData(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _replaceMessages(data.messages);
        _pendingScrollTargetMessageID = data.firstUnreadMessageID;
      });

      _scheduleInitialPositioning();
      await _markConversationRead(token);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load this conversation right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectRealtime() async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    await _statusSubscription?.cancel();
    _statusSubscription = ChatRealtimeClient.instance.statuses.listen((status) {
      if (status == ChatRealtimeStatus.connected) {
        _refreshConversationSilently();
      }
    });

    try {
      await ChatRealtimeClient.instance.connect(token);
      await _realtimeSubscription?.cancel();
      _realtimeSubscription = ChatRealtimeClient.instance.events.listen((
        event,
      ) async {
        if (!mounted) {
          return;
        }

        switch (event.event) {
          case ChatRealtimeEvents.presenceUpdated:
            if (event.userID == widget.args.participantUserID) {
              setState(() {
                _presenceLabel = event.isOnline ? 'Online' : 'Offline';
              });
            }
            return;
          case ChatRealtimeEvents.messageCreated:
            if (event.conversationID != widget.args.conversationID) {
              return;
            }
            final message = event.message;
            if (message == null) {
              return;
            }

            final shouldAutoScroll = _shouldAutoScrollToBottom() ||
                message.senderUserID == appSession.userID;

            setState(() {
              _isOtherUserTyping = false;
              _upsertMessage(message);
            });

            if (message.senderUserID != appSession.userID) {
              await _markConversationRead(token);
            }

            if (shouldAutoScroll) {
              _scrollToBottom(animated: true);
            }
            return;
          case ChatRealtimeEvents.typingStarted:
            if (event.conversationID != widget.args.conversationID) {
              return;
            }
            if (event.userID.isNotEmpty && event.userID != appSession.userID) {
              setState(() {
                _isOtherUserTyping = true;
              });
              if (_shouldAutoScrollToBottom()) {
                _scrollToBottom(animated: true);
              }
            }
            return;
          case ChatRealtimeEvents.typingStopped:
            if (event.conversationID != widget.args.conversationID) {
              return;
            }
            if (event.userID.isNotEmpty && event.userID != appSession.userID) {
              setState(() {
                _isOtherUserTyping = false;
              });
            }
            return;
        }
      });
    } catch (_) {
      // Realtime is optional; history and send still work over HTTP.
    }
  }

  Future<void> _sendMessage() async {
    final token = appSession.token;
    final message = _messageController.text;
    if (token == null ||
        token.isEmpty ||
        message.trim().isEmpty ||
        _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final sentMessage = await _chatApi.sendMessage(
        token: token,
        conversationID: widget.args.conversationID,
        request: SendMessageRequest(body: message),
      );

      if (!mounted) return;
      setState(() {
        _upsertMessage(sentMessage);
        _messageController.clear();
      });
      _stopTypingSignal();
      _scrollToBottom(animated: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _refreshConversationSilently() async {
    final token = appSession.token;
    if (token == null || token.isEmpty || !mounted || _isSending) {
      return;
    }

    try {
      if (!ChatRealtimeClient.instance.isConnected) {
        await ChatRealtimeClient.instance.connect(token);
      }

      final data = await _fetchConversationData(token);
      if (!mounted) {
        return;
      }

      final shouldAutoScroll = _shouldAutoScrollToBottom();
      setState(() {
        _replaceMessages(data.messages);
      });

      if (_containsUnreadIncoming(data.messages)) {
        await _markConversationRead(token);
      }
      if (shouldAutoScroll) {
        _scrollToBottom(animated: false);
      }
    } catch (_) {
      // Quiet resync should stay silent.
    }
  }

  Future<_LoadedConversationData> _fetchConversationData(String token) async {
    final messages = await _chatApi.listMessages(
      token: token,
      conversationID: widget.args.conversationID,
    );

    return _LoadedConversationData(
      messages: messages,
      firstUnreadMessageID: _findFirstUnreadIncomingMessageID(messages),
    );
  }

  Future<void> _markConversationRead(String token) async {
    await _chatApi.markConversationRead(
      token: token,
      conversationID: widget.args.conversationID,
    );
    await chatUnreadController.refresh();
  }

  Future<void> _handleAppResumed() async {
    await _refreshConversationSilently();
    if (!mounted) return;
    setState(() {
      _presenceLabel = _currentPresenceLabel();
    });
  }

  void _replaceMessages(List<ChatMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    _syncMessageKeys();
  }

  void _upsertMessage(ChatMessage message) {
    final existingIndex = _messages.indexWhere(
      (item) => item.id == message.id,
    );
    if (existingIndex >= 0) {
      _messages[existingIndex] = message;
    } else {
      _messages.add(message);
    }
    _syncMessageKeys();
  }

  void _syncMessageKeys() {
    final activeMessageIDs = _messages.map((message) => message.id).toSet();
    _messageKeys
        .removeWhere((messageID, _) => !activeMessageIDs.contains(messageID));
    for (final message in _messages) {
      _messageKeys.putIfAbsent(message.id, GlobalKey.new);
    }
  }

  void _scheduleInitialPositioning() {
    if (_didInitialPosition) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didInitialPosition) {
        return;
      }

      final targetMessageID = _pendingScrollTargetMessageID;
      if (targetMessageID != null) {
        final key = _messageKeys[targetMessageID];
        final context = key?.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 220),
            alignment: 0.1,
          );
        } else {
          _scrollToBottom(animated: false);
        }
      } else {
        _scrollToBottom(animated: false);
      }

      _didInitialPosition = true;
    });
  }

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final targetOffset = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(targetOffset);
      }
    });
  }

  bool _shouldAutoScrollToBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= _bottomScrollThreshold;
  }

  bool _containsUnreadIncoming(List<ChatMessage> messages) {
    for (final message in messages) {
      if (message.senderUserID != appSession.userID && message.readAt == null) {
        return true;
      }
    }
    return false;
  }

  String? _findFirstUnreadIncomingMessageID(List<ChatMessage> messages) {
    for (final message in messages) {
      if (message.senderUserID != appSession.userID && message.readAt == null) {
        return message.id;
      }
    }
    return null;
  }

  void _handleComposerChanged(String rawValue) {
    final hasText = rawValue.isNotEmpty;
    if (!hasText) {
      _stopTypingSignal();
      return;
    }

    if (!_didSendTypingStarted) {
      _didSendTypingStarted = true;
      ChatRealtimeClient.instance.sendTypingStarted(widget.args.conversationID);
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(_typingStopDelay, _stopTypingSignal);
  }

  void _stopTypingSignal() {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;

    if (!_didSendTypingStarted) {
      return;
    }

    _didSendTypingStarted = false;
    ChatRealtimeClient.instance.sendTypingStopped(widget.args.conversationID);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.args.title,
                    style: textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _presenceLabel,
                    style: textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (_errorMessage != null && _messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (_messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No messages yet. Say hi and start the conversation.',
                        style: textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      if (!_isOtherUserTyping) {
                        return const SizedBox.shrink();
                      }

                      return const _TypingIndicator();
                    }

                    final message = _messages[index];
                    return KeyedSubtree(
                      key: _messageKeys[message.id],
                      child: _ChatBubble(
                        message: message,
                        isMine: message.senderUserID == appSession.userID,
                        conversationTitle: widget.args.title,
                      ),
                    );
                  },
                  separatorBuilder: (_, index) {
                    if (index == _messages.length - 1 && !_isOtherUserTyping) {
                      return const SizedBox.shrink();
                    }
                    return const SizedBox(height: AppSpacing.sm);
                  },
                  itemCount: _messages.length + (_isOtherUserTyping ? 1 : 0),
                );
              },
            ),
          ),
          if (_errorMessage != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                _errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onChanged: _handleComposerChanged,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Type your message',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _currentPresenceLabel() {
    final participantUserID = widget.args.participantUserID.trim();
    if (participantUserID.isEmpty) {
      return widget.args.subtitle;
    }

    return ChatRealtimeClient.instance.isUserOnline(participantUserID)
        ? 'Online'
        : 'Offline';
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.conversationTitle,
  });

  final ChatMessage message;
  final bool isMine;
  final String conversationTitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (message.body == ChatSystemMessageBodies.connection) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'You are now connected with ${_titleCase(conversationTitle)}.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isMine ? AppColors.textPrimary : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(
                isMine ? AppRadius.lg : AppRadius.sm,
              ),
              topRight: Radius.circular(
                isMine ? AppRadius.sm : AppRadius.lg,
              ),
              bottomLeft: const Radius.circular(AppRadius.lg),
              bottomRight: const Radius.circular(AppRadius.lg),
            ),
            border: isMine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: textTheme.bodyLarge?.copyWith(
                  color: isMine ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatTimestamp(message.createdAt),
                style: textTheme.bodyMedium?.copyWith(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return '';
    }

    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'your friend' : trimmed;
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'typing ....',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _ChatLifecycleObserver with WidgetsBindingObserver {
  _ChatLifecycleObserver({
    required this.onResumed,
  });

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
