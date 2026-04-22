import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/chat_unread_controller.dart';
import '../../chat/presentation/chat_conversation_screen.dart';
import '../data/friends_api.dart';
import 'friend_request_profile_screen.dart';
import 'friend_username_search_screen.dart';
import 'notifications_screen.dart';

class FriendsHomeScreen extends StatefulWidget {
  const FriendsHomeScreen({
    super.key,
    this.isEmbedded = false,
  });

  final bool isEmbedded;

  @override
  State<FriendsHomeScreen> createState() => _FriendsHomeScreenState();
}

class _FriendsHomeScreenState extends State<FriendsHomeScreen> {
  static const int _pageSize = 15;

  final FriendsApi _friendsApi = FriendsApi();
  final ChatApi _chatApi = ChatApi();
  final ScrollController _scrollController = ScrollController();

  final List<FriendNotificationRecord> _notifications =
      <FriendNotificationRecord>[];
  final List<FriendSummary> _friends = <FriendSummary>[];

  bool _isLoadingNotifications = true;
  bool _isLoadingFriends = true;
  bool _isLoadingMoreNotifications = false;
  bool _isLoadingMoreFriends = false;
  String? _notificationsMessage;
  String? _friendsMessage;
  int? _nextNotificationsPage;
  int? _nextFriendsPage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadScreenData();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadScreenData() async {
    await Future.wait<void>([
      _loadNotifications(),
      _loadFriends(),
    ]);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      _loadFriends(loadMore: true);
    }
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingNotifications = false;
        _notificationsMessage = 'Please sign in again to load notifications.';
      });
      return;
    }

    if (loadMore &&
        (_isLoadingMoreNotifications || _nextNotificationsPage == null)) {
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMoreNotifications = true;
      } else {
        _isLoadingNotifications = true;
        _notificationsMessage = null;
      }
    });

    try {
      final page = await _friendsApi.listNotifications(
        token: token,
        page: loadMore ? _nextNotificationsPage! : 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _notifications.addAll(page.items);
        } else {
          _notifications
            ..clear()
            ..addAll(page.items);
        }
        _nextNotificationsPage = page.nextPage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationsMessage = 'Unable to load notifications right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNotifications = false;
          _isLoadingMoreNotifications = false;
        });
      }
    }
  }

  Future<void> _loadFriends({bool loadMore = false}) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingFriends = false;
        _friendsMessage = 'Please sign in again to load your friends.';
      });
      return;
    }

    if (loadMore && (_isLoadingMoreFriends || _nextFriendsPage == null)) {
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMoreFriends = true;
      } else {
        _isLoadingFriends = true;
        _friendsMessage = null;
      }
    });

    try {
      final page = await _friendsApi.listFriends(
        token: token,
        page: loadMore ? _nextFriendsPage! : 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _friends.addAll(page.items);
        } else {
          _friends
            ..clear()
            ..addAll(page.items);
        }
        _nextFriendsPage = page.nextPage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendsMessage = 'Unable to load your friends right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
          _isLoadingMoreFriends = false;
        });
      }
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FriendUsernameSearchScreen(),
      ),
    );
    await _loadFriends();
  }

  Future<void> _openScanner() async {
    await _openSearch();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          notifications: _notifications,
          isLoading: _isLoadingNotifications,
          isLoadingMore: _isLoadingMoreNotifications,
          hasMore: _nextNotificationsPage != null,
          message: _notificationsMessage,
          onOpenNotification: _openNotification,
          onLoadMore: () => _loadNotifications(loadMore: true),
        ),
      ),
    );
    await _loadNotifications();
  }

  Future<void> _openNotification(FriendNotificationRecord notification) async {
    final request = notification.friendRequest;
    if (request == null || !notification.isPendingIncomingRequest) {
      return;
    }
    final navigator = Navigator.of(context);

    final token = appSession.token;
    if (token != null && token.isNotEmpty) {
      await _friendsApi.markNotificationRead(
        token: token,
        notificationID: notification.id,
      );
    }

    final isIncomingRequest = notification.type == 'friend_request_received';
    final peer = isIncomingRequest ? request.requester : request.addressee;
    final isAlreadyFriend =
        _friends.any((friend) => friend.userID == peer.userID);
    final showChatButton = isAlreadyFriend ||
        notification.isAcceptedRequest ||
        request.status == 'accepted';

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendRequestProfileScreen(
          request: request,
          title: peer.displayName.trim().isEmpty
              ? peer.username
              : peer.displayName.trim(),
          isIncomingRequest: isIncomingRequest,
          showChatButton: showChatButton,
          onAcceptRequest: () => _respondToRequest(request, 'accept'),
          onDeclineRequest: () => _respondToRequest(request, 'decline'),
          onOpenChat: () => _openChatWithFriend(
            _friends.firstWhere(
              (friend) => friend.userID == peer.userID,
              orElse: () => FriendSummary(
                userID: peer.userID,
                username: peer.username,
                displayName: peer.displayName,
                avatarUrl: peer.avatarUrl,
                city: peer.city,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _respondToRequest(
    FriendRequestRecord request,
    String action,
  ) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      await _friendsApi.respondToRequest(
        token: token,
        requestID: request.id,
        action: action,
      );
      await _loadScreenData();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'accept'
                ? 'You are now connected with @${request.requester.username}.'
                : 'Friend request declined.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('HttpException: ', '')),
        ),
      );
      return false;
    }
  }

  Future<void> _openChatWithFriend(FriendSummary friend) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final conversation = await _chatApi.createConversation(
        token: token,
        request: CreateConversationRequest(
          participantIDs: [friend.userID],
        ),
      );
      await chatUnreadController.refresh();
      if (!mounted) return;

      await Navigator.of(context).pushNamed(
        AppRoute.chatConversation.path,
        arguments: ChatConversationArgs(
          conversationID: conversation.id,
          title:
              friend.displayName.isEmpty ? friend.username : friend.displayName,
          participantUserID: friend.userID,
          subtitle: friend.city.isEmpty ? '@${friend.username}' : friend.city,
        ),
      );

      await _loadFriends();
      await chatUnreadController.refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('HttpException: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((item) => item.readAt == null).length;
    final topPadding = widget.isEmbedded ? AppSpacing.md : AppSpacing.sm;

    final body = Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadScreenData,
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              topPadding,
              AppSpacing.lg,
              widget.isEmbedded ? 148 : 112,
            ),
            children: [
              _FriendsHeader(
                unreadCount: unreadCount,
                isLoadingNotifications: _isLoadingNotifications,
                onOpenNotifications: _openNotifications,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SearchBar(onTap: _openSearch),
              const SizedBox(height: AppSpacing.xl),
              _FriendsSection(
                count: _friends.length,
                isLoading: _isLoadingFriends,
                isLoadingMore: _isLoadingMoreFriends,
                hasMore: _nextFriendsPage != null,
                message: _friendsMessage,
                friends: _friends,
                onOpenChat: _openChatWithFriend,
              ),
            ],
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          bottom: widget.isEmbedded ? 100 : AppSpacing.xl,
          child: FloatingActionButton(
            onPressed: _openScanner,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 10,
            child: const Icon(Icons.add_rounded, size: 32),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: body),
    );
  }
}

class _FriendsHeader extends StatelessWidget {
  const _FriendsHeader({
    required this.unreadCount,
    required this.isLoadingNotifications,
    required this.onOpenNotifications,
  });

  final int unreadCount;
  final bool isLoadingNotifications;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Friends',
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 30,
              letterSpacing: -0.8,
            ),
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: IconButton(
            onPressed: isLoadingNotifications ? null : onOpenNotifications,
            icon: isLoadingNotifications
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 17,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Search by username',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsSection extends StatelessWidget {
  const _FriendsSection({
    required this.count,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.message,
    required this.friends,
    required this.onOpenChat,
  });

  final int count;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? message;
  final List<FriendSummary> friends;
  final ValueChanged<FriendSummary> onOpenChat;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your friends ($count)',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'See all',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100F172A),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Builder(
              builder: (context) {
                if (isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (message != null) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      message!,
                      style: textTheme.bodyMedium,
                    ),
                  );
                }

                if (friends.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No friends yet. Use the + button to add someone.',
                      style: textTheme.bodyMedium,
                    ),
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < friends.length; index++) ...[
                      _FriendRow(
                        friend: friends[index],
                        onTap: () => onOpenChat(friends[index]),
                      ),
                      if (index != friends.length - 1)
                        const Divider(height: 1, indent: 58),
                    ],
                    if (isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.only(
                          top: AppSpacing.md,
                          bottom: AppSpacing.sm,
                        ),
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    else if (hasMore)
                      const SizedBox(height: AppSpacing.md),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.onTap,
  });

  final FriendSummary friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = friend.displayName.trim().isEmpty
        ? friend.username
        : friend.displayName;
    final subtitle =
        friend.city.trim().isEmpty ? 'Offline' : friend.city.trim();
    final isOnline = friend.city.trim().isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              title.characters.first.toUpperCase(),
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF36C275)
                    : const Color(0xFFC8CDD8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
    );
  }
}
