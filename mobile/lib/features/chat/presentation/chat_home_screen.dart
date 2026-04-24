import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../friends/data/friend_search_api.dart';
import '../../friends/data/friends_api.dart';
import '../../friends/presentation/friend_search_profile_screen.dart';
import '../data/chat_api.dart';
import '../data/chat_constants.dart';
import '../data/chat_realtime_client.dart';
import '../data/chat_unread_controller.dart';
import 'chat_conversation_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({
    super.key,
    this.isEmbedded = false,
  });

  final bool isEmbedded;

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  static const int _friendsPageSize = 50;

  final ChatApi _chatApi = ChatApi();
  final FriendsApi _friendsApi = FriendsApi();
  final FriendSearchApi _friendSearchApi = FriendSearchApi();
  final TextEditingController _searchController = TextEditingController();

  final List<ChatConversationSummary> _conversations =
      <ChatConversationSummary>[];
  final List<FriendSummary> _friends = <FriendSummary>[];
  final List<FriendSearchResult> _searchResults = <FriendSearchResult>[];

  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<ChatRealtimeStatus>? _statusSubscription;
  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  String? _searchMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _connectRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _statusSubscription?.cancel();
    _realtimeSubscription?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
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
      final results = await Future.wait<dynamic>([
        _chatApi.listConversations(token: token),
        _friendsApi.listFriends(token: token, page: 1, limit: _friendsPageSize),
        chatUnreadController.refresh(),
      ]);

      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(results[0] as List<ChatConversationSummary>);
        _friends
          ..clear()
          ..addAll((results[1] as FriendsPage).items);
      });

      if (_searchQuery.trim().length >= 2) {
        await _runSearch(_searchQuery);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load your chats right now.';
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
      final results = await Future.wait<dynamic>([
        _chatApi.listConversations(token: token),
        _friendsApi.listFriends(token: token, page: 1, limit: _friendsPageSize),
        chatUnreadController.refresh(),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(results[0] as List<ChatConversationSummary>);
        _friends
          ..clear()
          ..addAll((results[1] as FriendsPage).items);
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

        if (event.event == ChatRealtimeEvents.presenceUpdated) {
          setState(() {});
          return;
        }

        if (event.event == ChatRealtimeEvents.messageCreated ||
            event.event == ChatRealtimeEvents.notificationCreated) {
          _refreshConversationsSilently();
        }
      });
    } catch (_) {
      // Realtime is optional; list data still works over HTTP.
    }
  }

  Future<void> _runSearch(String rawQuery) async {
    final token = appSession.token;
    final query = rawQuery.trim().toLowerCase();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchResults.clear();
        _isSearching = false;
        _searchMessage = query.isEmpty
            ? null
            : 'Type at least 2 characters to search usernames.';
      });
      return;
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults.clear();
        _isSearching = false;
        _searchMessage = 'Please sign in again to search.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchMessage = null;
    });

    try {
      final results = await _friendSearchApi.searchUsers(
        token: token,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _searchResults
          ..clear()
          ..addAll(results);
        _searchMessage =
            results.isEmpty ? 'No people found for "$query".' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults.clear();
        _searchMessage = 'Unable to search right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _scheduleSearch(String value) {
    setState(() {
      _searchQuery = value;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(value),
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    setState(() {
      _searchQuery = '';
      _searchResults.clear();
      _searchMessage = null;
      _isSearching = false;
    });
  }

  Future<void> _submitSearch(String value) async {
    await _runSearch(value);
    _clearSearch();
  }

  Future<void> _openConversation(ChatConversationSummary conversation) async {
    final activity = _participantActivity(conversation.otherParticipant);

    await Navigator.of(context).pushNamed(
      AppRoute.chatConversation.path,
      arguments: ChatConversationArgs(
        conversationID: conversation.id,
        title: conversation.otherParticipant.primaryLabel,
        participantUserID: conversation.otherParticipant.userID,
        subtitle: activity.label,
      ),
    );

    await _loadHomeData();
  }

  Future<void> _openOrCreateConversation({
    required String userID,
    required String title,
    required String subtitle,
  }) async {
    final existing = _conversationByUserID[userID];
    if (existing != null) {
      await _openConversation(existing);
      return;
    }

    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final conversation = await _chatApi.createConversation(
        token: token,
        request: CreateConversationRequest(
          participantIDs: [userID],
        ),
      );
      await chatUnreadController.refresh();
      if (!mounted) return;

      await Navigator.of(context).pushNamed(
        AppRoute.chatConversation.path,
        arguments: ChatConversationArgs(
          conversationID: conversation.id,
          title: title,
          participantUserID: userID,
          subtitle: subtitle,
        ),
      );

      await _loadHomeData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('HttpException: ', '')),
        ),
      );
    }
  }


  Future<void> _openSearchResult(FriendSearchResult result) async {
    if (result.connectionStatus == FriendConnectionStatus.friends) {
      await _openOrCreateConversation(
        userID: result.userID,
        title: result.displayName.trim().isEmpty
            ? result.username
            : result.displayName.trim(),
        subtitle:
            result.city.trim().isEmpty ? '@${result.username}' : result.city,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendSearchProfileScreen(result: result),
      ),
    );
    await _loadHomeData();
  }

  Map<String, ChatConversationSummary> get _conversationByUserID {
    return {
      for (final conversation in _conversations)
        conversation.otherParticipant.userID: conversation,
    };
  }

  List<_FriendListItem> get _friendItems {
    final conversationByUserID = _conversationByUserID;
    final items = _friends
        .map(
          (friend) => _FriendListItem(
            friend: friend,
            conversation: conversationByUserID[friend.userID],
          ),
        )
        .toList();

    items.sort((a, b) {
      final aTime = a.conversation?.lastMessageAt ?? a.conversation?.createdAt;
      final bTime = b.conversation?.lastMessageAt ?? b.conversation?.createdAt;
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final searchActive = _searchQuery.trim().isNotEmpty;
    final body = _UnifiedInboxContent(
      isEmbedded: widget.isEmbedded,
      isLoading: _isLoading,
      isSearching: _isSearching,
      errorMessage: _errorMessage,
      searchMessage: _searchMessage,
      searchController: _searchController,
      searchQuery: _searchQuery,
      searchResults: _searchResults,
      friendItems: _friendItems,
      onRefresh: _loadHomeData,
      onSearchChanged: _scheduleSearch,
      onSearchSubmitted: _submitSearch,
      onOpenConversation: (item) => _openOrCreateConversation(
        userID: item.friend.userID,
        title: item.title,
        subtitle: item.subtitle,
      ),
      onOpenSearchResult: (result) async {
        await _openSearchResult(result);
        _clearSearch();
      },
      searchActive: searchActive,
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: body,
    );
  }
}

class _UnifiedInboxContent extends StatelessWidget {
  const _UnifiedInboxContent({
    required this.isLoading,
    required this.isSearching,
    required this.errorMessage,
    required this.searchMessage,
    required this.searchController,
    required this.searchQuery,
    required this.searchResults,
    required this.friendItems,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onOpenConversation,
    required this.onOpenSearchResult,
    required this.searchActive,
    this.isEmbedded = false,
  });

  final bool isEmbedded;
  final bool isLoading;
  final bool isSearching;
  final bool searchActive;
  final String? errorMessage;
  final String? searchMessage;
  final TextEditingController searchController;
  final String searchQuery;
  final List<FriendSearchResult> searchResults;
  final List<_FriendListItem> friendItems;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<_FriendListItem> onOpenConversation;
  final ValueChanged<FriendSearchResult> onOpenSearchResult;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chats',
                  style: textTheme.headlineMedium?.copyWith(
                    fontSize: 34,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search friends or usernames',
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              fillColor: AppColors.surfaceSoft,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppColors.borderFocus,
                  width: 1.2,
                ),
              ),
            ),
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (searchActive) ...[
            Row(
              children: [
                const Spacer(),
                Text(
                  isSearching
                      ? 'Searching...'
                      : '${searchResults.length} results',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage != null && !searchActive)
            _InboxMessageCard(
              title: 'Unable to load chats',
              message: errorMessage!,
            )
          else if (searchActive)
            _buildSearchState(context)
          else if (friendItems.isEmpty)
            const _InboxMessageCard(
              title: 'No friends yet',
              message:
                  'Search by username to add someone, then your connected friends will appear here.',
            )
          else
            Column(
              children: [
                for (var index = 0; index < friendItems.length; index++) ...[
                  _FriendConversationTile(
                    item: friendItems[index],
                    onTap: () => onOpenConversation(friendItems[index]),
                  ),
                  if (index != friendItems.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );

    if (isEmbedded) {
      return SafeArea(child: content);
    }

    return SafeArea(child: content);
  }

  Widget _buildSearchState(BuildContext context) {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (searchMessage != null) {
      return _InboxMessageCard(
        title: 'Search',
        message: searchMessage!,
      );
    }

    if (searchResults.isEmpty) {
      return _InboxMessageCard(
        title: 'Search',
        message: searchQuery.trim().length < 2
            ? 'Type at least 2 characters to search usernames.'
            : 'No results yet.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < searchResults.length; index++) ...[
          _SearchResultTile(
            result: searchResults[index],
            onTap: () => onOpenSearchResult(searchResults[index]),
          ),
          if (index != searchResults.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _InboxMessageCard extends StatelessWidget {
  const _InboxMessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FriendConversationTile extends StatelessWidget {
  const _FriendConversationTile({
    required this.item,
    required this.onTap,
  });

  final _FriendListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final conversation = item.conversation;
    final unreadCount = conversation?.unreadCount ?? 0;
    final hasUnread = unreadCount > 0;
    final trailingTime = _formatTimestamp(
        conversation?.lastMessageAt ?? conversation?.createdAt);
    final preview = conversation == null
        ? item.subtitle
        : _messagePreview(conversation.lastMessageBody);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 12,
        ),
        child: Row(
          children: [
            _AvatarBadge(seed: item.title),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trailingTime.isNotEmpty)
                        Text(
                          trailingTime,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            color: hasUnread
                                ? AppColors.textSecondary
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.96,
                                  ),
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: AppSpacing.sm),
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.primaryGlow,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: textTheme.bodySmall?.copyWith(
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
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.onTap,
  });

  final FriendSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = result.displayName.trim().isEmpty
        ? result.username
        : result.displayName.trim();
    final subtitle =
        result.city.trim().isEmpty ? '@${result.username}' : result.city.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _AvatarBadge(seed: title),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _searchActionLabel(result.connectionStatus),
                style: textTheme.bodyMedium?.copyWith(
                  color:
                      result.connectionStatus == FriendConnectionStatus.friends
                          ? AppColors.primary
                          : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({
    required this.seed,
  });

  final String seed;

  @override
  Widget build(BuildContext context) {
    final palette = <Color>[
      const Color(0xFFE8EAFE),
      const Color(0xFFFFE8DF),
      const Color(0xFFE5F2FF),
      const Color(0xFFE8F5EC),
    ];
    final accents = <Color>[
      AppColors.primary,
      AppColors.accentStrong,
      const Color(0xFF2383E2),
      const Color(0xFF2CA56D),
    ];
    final index = seed.hashCode.abs() % palette.length;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: palette[index],
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        seed.trim().isEmpty ? '?' : seed.trim().characters.first.toUpperCase(),
        style: textTheme.titleLarge?.copyWith(
          color: accents[index],
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FriendListItem {
  const _FriendListItem({
    required this.friend,
    required this.conversation,
  });

  final FriendSummary friend;
  final ChatConversationSummary? conversation;

  String get title =>
      friend.displayName.trim().isEmpty ? friend.username : friend.displayName;

  String get subtitle =>
      friend.city.trim().isEmpty ? '@${friend.username}' : friend.city.trim();
}

class _ConversationActivity {
  const _ConversationActivity({
    required this.label,
  });

  final String label;
}

_ConversationActivity _participantActivity(ChatParticipant participant) {
  if (ChatRealtimeClient.instance.isUserOnline(participant.userID) ||
      participant.isOnline) {
    return const _ConversationActivity(
      label: 'Online',
    );
  }

  return const _ConversationActivity(
    label: 'Offline',
  );
}

String _searchActionLabel(String status) {
  switch (status) {
    case FriendConnectionStatus.friends:
      return 'Chat';
    case FriendConnectionStatus.requested:
      return 'Requested';
    case FriendConnectionStatus.incomingRequest:
      return 'Respond';
    default:
      return 'Add';
  }
}

String _messagePreview(String body) {
  if (body == ChatSystemMessageBodies.connection) {
    return 'You are now connected.';
  }

  return body.trim().isEmpty ? 'Start chatting' : body;
}

String _formatTimestamp(DateTime? value) {
  if (value == null) {
    return '';
  }

  final now = DateTime.now();
  final date = value.toLocal();
  if (now.year == date.year && now.month == date.month && now.day == date.day) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  if (now.difference(date).inDays == 1) {
    return 'Yesterday';
  }

  if (now.difference(date).inDays < 7) {
    const weekdays = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return weekdays[date.weekday - 1];
  }

  return '${date.month}/${date.day}';
}
