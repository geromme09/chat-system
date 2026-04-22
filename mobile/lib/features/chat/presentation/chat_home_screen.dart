import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../data/chat_api.dart';
import '../data/chat_constants.dart';
import '../data/chat_realtime_client.dart';
import '../data/chat_unread_controller.dart';
import 'chat_conversation_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({
    super.key,
    this.isEmbedded = false,
    this.onOpenFriendsTab,
  });

  final bool isEmbedded;
  final VoidCallback? onOpenFriendsTab;

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final ChatApi _chatApi = ChatApi();
  final List<ChatConversationSummary> _conversations =
      <ChatConversationSummary>[];

  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<ChatRealtimeStatus>? _statusSubscription;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _connectRealtime();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
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
      final conversations = await _chatApi.listConversations(token: token);
      await chatUnreadController.refresh();

      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(conversations);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load your conversations right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshConversationsSilently() async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final conversations = await _chatApi.listConversations(token: token);
      await chatUnreadController.refresh();
      if (!mounted) {
        return;
      }

      setState(() {
        _conversations
          ..clear()
          ..addAll(conversations);
      });
    } catch (_) {
      // Keep the current list if background refresh fails.
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
        _refreshConversationsSilently();
      }
    });

    try {
      await ChatRealtimeClient.instance.connect(token);
      await _realtimeSubscription?.cancel();
      _realtimeSubscription =
          ChatRealtimeClient.instance.events.listen((event) {
        if (!mounted) {
          return;
        }

        if (event.event == ChatRealtimeEvents.messageCreated) {
          _refreshConversationsSilently();
        }
      });
    } catch (_) {
      // Conversation list still works over HTTP refresh.
    }
  }

  Future<void> _openConversation(ChatConversationSummary conversation) async {
    await Navigator.of(context).pushNamed(
      AppRoute.chatConversation.path,
      arguments: ChatConversationArgs(
        conversationID: conversation.id,
        title: conversation.otherParticipant.primaryLabel,
        subtitle: conversation.otherParticipant.secondaryLabel,
      ),
    );

    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return ChatHomeContent(
        isEmbedded: true,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        conversations: _conversations,
        onOpenFriends: widget.onOpenFriendsTab,
        onOpenConversation: _openConversation,
        onRefresh: _loadConversations,
      );
    }

    return ChatHomeContent(
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      conversations: _conversations,
      onOpenConversation: _openConversation,
      onRefresh: _loadConversations,
    );
  }
}

class ChatHomeContent extends StatelessWidget {
  const ChatHomeContent({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.conversations,
    required this.onOpenConversation,
    required this.onRefresh,
    this.isEmbedded = false,
    this.onOpenFriends,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<ChatConversationSummary> conversations;
  final bool isEmbedded;
  final VoidCallback? onOpenFriends;
  final ValueChanged<ChatConversationSummary> onOpenConversation;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your chats',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Recent conversations, unread messages, and live replies.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (isEmbedded) {
                    onOpenFriends?.call();
                    return;
                  }

                  Navigator.of(context).pushNamed(
                    AppRoute.friendScanner.path,
                  );
                },
                icon: const Icon(Icons.group_add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                    ),
                  )
                else if (conversations.isEmpty)
                  _EmptyChatsCard(
                    onOpenFriends: () {
                      if (isEmbedded) {
                        onOpenFriends?.call();
                        return;
                      }

                      Navigator.of(context).pushNamed(
                        AppRoute.friendScanner.path,
                      );
                    },
                  )
                else
                  ...conversations.expand((conversation) => [
                        _ChatTile(
                          conversation: conversation,
                          onTap: () => onOpenConversation(conversation),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ]),
              ],
            ),
          ),
        ),
      ],
    );

    if (isEmbedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: body),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onOpenFriends ??
            () {
              Navigator.of(context).pushNamed(AppRoute.friendScanner.path);
            },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_rounded),
        label: const Text('New chat'),
      ),
    );
  }
}

class _EmptyChatsCard extends StatelessWidget {
  const _EmptyChatsCard({
    required this.onOpenFriends,
  });

  final VoidCallback onOpenFriends;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No chats yet',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start a conversation from your accepted friends and it will show up here with unread tracking.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onOpenFriends,
            child: const Text('Find friends'),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.conversation,
    required this.onTap,
  });

  final ChatConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final participant = conversation.otherParticipant;
    final unreadCount = conversation.unreadCount;
    final hasUnread = unreadCount > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: hasUnread ? AppColors.primarySoft : AppColors.surface,
          border: Border.all(
            color: hasUnread ? AppColors.primary : AppColors.border,
            width: hasUnread ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: hasUnread
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: hasUnread
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.person_rounded,
                color: hasUnread ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          participant.primaryLabel,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _formatTimestamp(
                          conversation.lastMessageAt ?? conversation.createdAt,
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _buildPreviewText(conversation),
                    style: textTheme.bodyMedium?.copyWith(
                      color: hasUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: hasUnread ? 0.85 : 0.6,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: hasUnread
                                ? AppColors.primaryLight
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          '@${participant.username}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: hasUnread
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _buildPreviewText(ChatConversationSummary conversation) {
    final preview = conversation.lastMessageBody.trim();
    if (preview.isEmpty) {
      return conversation.otherParticipant.secondaryLabel;
    }

    if (conversation.lastMessageSenderID == appSession.userID) {
      return 'You: $preview';
    }

    return preview;
  }

  static String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return '';
    }

    final now = DateTime.now();
    final date = value.toLocal();
    if (now.year == date.year &&
        now.month == date.month &&
        now.day == date.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    return '${date.month}/${date.day}';
  }
}
