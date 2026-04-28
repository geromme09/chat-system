import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/chat_unread_controller.dart';
import '../../chat/presentation/chat_conversation_screen.dart';
import '../../feed/data/feed_api.dart';
import '../../feed/presentation/comment_widgets.dart';
import '../../profile/data/profile_api.dart';
import '../data/friend_search_api.dart';
import '../data/friends_api.dart';

class FriendSearchProfileScreen extends StatefulWidget {
  const FriendSearchProfileScreen({
    super.key,
    required this.result,
  });

  final FriendSearchResult result;

  @override
  State<FriendSearchProfileScreen> createState() =>
      _FriendSearchProfileScreenState();
}

class _FriendSearchProfileScreenState extends State<FriendSearchProfileScreen> {
  final FriendsApi _friendsApi = FriendsApi();
  final FeedApi _feedApi = FeedApi();
  final ChatApi _chatApi = ChatApi();
  final ProfileApi _profileApi = ProfileApi();
  final ScrollController _scrollController = ScrollController();

  late String _connectionStatus = widget.result.connectionStatus;
  PublicProfile? _profile;
  List<FeedPost> _posts = const <FeedPost>[];
  final Map<String, List<FeedComment>> _commentsByPostID =
      <String, List<FeedComment>>{};
  final Set<String> _expandedCommentPostIDs = <String>{};
  final Set<String> _loadingCommentPostIDs = <String>{};
  final Set<String> _submittingCommentPostIDs = <String>{};
  final Set<String> _reactingPostIDs = <String>{};
  String _nextCursor = '';
  bool _isSendingRequest = false;
  bool _isOpeningChat = false;
  bool _isLoadingPosts = true;
  bool _isLoadingMorePosts = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadProfile();
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _message = 'Please sign in again to view profiles.';
      });
      return;
    }

    try {
      final profile = await _profileApi.getProfile(
        token: token,
        userID: widget.result.userID,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _connectionStatus = profile.connectionStatus;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
      });
    }
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingPosts = false;
        _message = 'Please sign in again to load posts.';
      });
      return;
    }
    if (loadMore && (_isLoadingMorePosts || _nextCursor.isEmpty)) {
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMorePosts = true;
      } else {
        _isLoadingPosts = true;
      }
    });

    try {
      final page = await _feedApi.listPosts(
        token: token,
        authorUserID: widget.result.userID,
        cursor: loadMore ? _nextCursor : '',
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _posts = loadMore ? <FeedPost>[..._posts, ...page.items] : page.items;
        _nextCursor = page.nextCursor;
        if (!loadMore) {
          _commentsByPostID.clear();
          _expandedCommentPostIDs.clear();
          _loadingCommentPostIDs.clear();
          _submittingCommentPostIDs.clear();
          _reactingPostIDs.clear();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _isLoadingMorePosts = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMorePosts) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadPosts(loadMore: true);
    }
  }

  Future<void> _sendFriendRequest() async {
    final token = appSession.token;
    if (token == null ||
        token.isEmpty ||
        _connectionStatus != FriendConnectionStatus.add) {
      return;
    }

    setState(() {
      _isSendingRequest = true;
    });

    try {
      await _friendsApi.sendFriendRequest(
        token: token,
        targetUserID: widget.result.userID,
      );
      if (!mounted) return;

      setState(() {
        _connectionStatus = FriendConnectionStatus.requested;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to @$_username.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('HttpException: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
        });
      }
    }
  }

  Future<void> _openChat() async {
    final token = appSession.token;
    if (token == null ||
        token.isEmpty ||
        _connectionStatus != FriendConnectionStatus.friends ||
        _isOpeningChat) {
      return;
    }

    setState(() {
      _isOpeningChat = true;
    });

    try {
      final conversation = await _chatApi.createConversation(
        token: token,
        request: CreateConversationRequest(
          participantIDs: [widget.result.userID],
        ),
      );
      await chatUnreadController.refresh();
      if (!mounted) return;

      await Navigator.of(context).pushNamed(
        AppRoute.chatConversation.path,
        arguments: ChatConversationArgs(
          conversationID: conversation.id,
          title: _title,
          participantUserID: widget.result.userID,
          subtitle: _location,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('HttpException: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningChat = false;
        });
      }
    }
  }

  Future<void> _toggleReaction(FeedPost post) async {
    final token = appSession.token;
    if (token == null || token.isEmpty || _reactingPostIDs.contains(post.id)) {
      return;
    }

    final previous = post;
    setState(() {
      _reactingPostIDs.add(post.id);
      _replacePost(
        post.copyWith(
          reactedByMe: !post.reactedByMe,
          reactionCount: post.reactionCount + (post.reactedByMe ? -1 : 1),
        ),
      );
    });

    try {
      final updated = post.reactedByMe
          ? await _feedApi.unlikePost(token: token, postID: post.id)
          : await _feedApi.likePost(token: token, postID: post.id);
      if (!mounted) return;
      setState(() {
        _replacePost(updated);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
        _replacePost(previous);
      });
    } finally {
      if (mounted) {
        setState(() {
          _reactingPostIDs.remove(post.id);
        });
      }
    }
  }

  Future<void> _toggleComments(FeedPost post) async {
    if (_expandedCommentPostIDs.contains(post.id)) {
      setState(() {
        _expandedCommentPostIDs.remove(post.id);
      });
      return;
    }

    setState(() {
      _expandedCommentPostIDs.add(post.id);
    });

    if (_commentsByPostID.containsKey(post.id)) return;
    await _loadComments(post.id);
  }

  Future<void> _loadComments(String postID) async {
    final token = appSession.token;
    if (token == null ||
        token.isEmpty ||
        _loadingCommentPostIDs.contains(postID)) {
      return;
    }

    setState(() {
      _loadingCommentPostIDs.add(postID);
    });

    try {
      final comments = await _feedApi.listComments(
        token: token,
        postID: postID,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _commentsByPostID[postID] = comments;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCommentPostIDs.remove(postID);
        });
      }
    }
  }

  Future<void> _submitComment(
    FeedPost post,
    String body,
    String parentCommentID,
  ) async {
    final token = appSession.token;
    if (token == null ||
        token.isEmpty ||
        body.trim().isEmpty ||
        _submittingCommentPostIDs.contains(post.id)) {
      return;
    }

    setState(() {
      _submittingCommentPostIDs.add(post.id);
    });

    try {
      final comment = await _feedApi.createComment(
        token: token,
        postID: post.id,
        request: CreateFeedCommentRequest(
          body: body.trim(),
          parentCommentID: parentCommentID,
        ),
      );
      if (!mounted) return;
      setState(() {
        final comments = _commentsByPostID[post.id] ?? const <FeedComment>[];
        _commentsByPostID[post.id] = <FeedComment>[...comments, comment];
        _expandedCommentPostIDs.add(post.id);
        _replacePost(post.copyWith(commentCount: post.commentCount + 1));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _submittingCommentPostIDs.remove(post.id);
        });
      }
    }
  }

  void _replacePost(FeedPost updatedPost) {
    _posts = _posts
        .map((post) => post.id == updatedPost.id ? updatedPost : post)
        .toList();
  }

  String get _title {
    final displayName = _profile?.displayName.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    final fallback = widget.result.displayName.trim();
    return fallback.isEmpty ? widget.result.username : fallback;
  }

  String get _username {
    final username = _profile?.username.trim() ?? '';
    if (username.isNotEmpty) return username;
    return widget.result.username;
  }

  String get _location {
    final parts = <String>[
      if ((_profile?.city.trim() ?? '').isNotEmpty) _profile!.city.trim(),
      if ((_profile?.country.trim() ?? '').isNotEmpty) _profile!.country.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    final fallback = widget.result.city.trim();
    return fallback.isEmpty ? 'Location not shared yet' : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final bio = _profile?.bio.trim().isNotEmpty == true
        ? _profile!.bio.trim()
        : _aboutCopy(_title);
    final gender = _profile?.gender.trim().isNotEmpty == true
        ? _profile!.gender.trim()
        : 'Not shared';
    final interests = _profile?.hobbiesText.trim().isNotEmpty == true
        ? _profile!.hobbiesText.trim()
        : 'No interests shared yet';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 104),
          children: [
            ProfileHeader(
              displayName: _title,
              avatarUrl: _profile?.avatarUrl.trim().isNotEmpty == true
                  ? _profile!.avatarUrl
                  : widget.result.avatarUrl,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileIdentity(
                    displayName: _title,
                    username: _username,
                    location: _location,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ProfileBadge(status: _connectionStatus),
                  if (_message != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _message!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ProfileActionRow(
                    connectionStatus: _connectionStatus,
                    isSendingRequest: _isSendingRequest,
                    isOpeningChat: _isOpeningChat,
                    onPrimaryPressed:
                        _connectionStatus == FriendConnectionStatus.friends
                            ? _openChat
                            : _sendFriendRequest,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ProfileInfoCard(
                    rows: [
                      ProfileInfoRowData(
                        icon: Icons.person_outline_rounded,
                        iconBackground: AppColors.primarySoft,
                        iconColor: AppColors.primary,
                        title: 'About',
                        value: bio,
                      ),
                      ProfileInfoRowData(
                        icon: Icons.badge_outlined,
                        iconBackground: const Color(0xFFE0F2FE),
                        iconColor: const Color(0xFF0284C7),
                        title: 'Identity',
                        value: gender,
                      ),
                      ProfileInfoRowData(
                        icon: Icons.auto_awesome_rounded,
                        iconBackground: const Color(0xFFFFF7ED),
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Interests',
                        value: interests,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ProfilePostsSection(
              displayName: _title,
              username: _username,
              posts: _posts,
              commentsByPostID: _commentsByPostID,
              expandedCommentPostIDs: _expandedCommentPostIDs,
              loadingCommentPostIDs: _loadingCommentPostIDs,
              submittingCommentPostIDs: _submittingCommentPostIDs,
              reactingPostIDs: _reactingPostIDs,
              isLoading: _isLoadingPosts,
              isLoadingMore: _isLoadingMorePosts,
              onReact: _toggleReaction,
              onToggleComments: _toggleComments,
              onSubmitComment: _submitComment,
            ),
          ],
        ),
      ),
    );
  }

  String _aboutCopy(String title) {
    switch (_connectionStatus) {
      case FriendConnectionStatus.friends:
        return '$title is already in your circle and ready to chat.';
      case FriendConnectionStatus.requested:
        return 'Your request is pending. Once they accept, you can start chatting right away.';
      case FriendConnectionStatus.incomingRequest:
        return 'This player already sent you a request. Review it from notifications to respond.';
      default:
        return '$title is visible in the feed, but you are not friends yet.';
    }
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.onBack,
    this.onMenu,
  });

  final String displayName;
  final String avatarUrl;
  final VoidCallback onBack;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 278,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFA099FF),
                    Color(0xFF6366F1),
                    Color(0xFF4F46E5),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(120),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 190,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(140),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 220,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Row(
              children: [
                _HeaderIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                const Spacer(),
                _HeaderIconButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: onMenu ?? () {},
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ProfileAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    required this.avatarUrl,
  });

  final String displayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft.withValues(alpha: 0.8),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AppAvatar(
          size: 112,
          imageUrl: avatarUrl,
          iconSize: 42,
          backgroundColor: AppColors.primarySoft,
        ),
      ),
    );
  }
}

class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({
    super.key,
    required this.displayName,
    required this.username,
    required this.location,
  });

  final String displayName;
  final String username;
  final String location;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          displayName,
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '@$username',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                location,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({
    super.key,
    required this.connectionStatus,
    required this.isSendingRequest,
    required this.isOpeningChat,
    required this.onPrimaryPressed,
  });

  final String connectionStatus;
  final bool isSendingRequest;
  final bool isOpeningChat;
  final VoidCallback onPrimaryPressed;

  bool get _canMessage => connectionStatus == FriendConnectionStatus.friends;

  @override
  Widget build(BuildContext context) {
    final busy = isSendingRequest || isOpeningChat;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: busy ? null : onPrimaryPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_canMessage
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.person_add_alt_1_rounded),
              label: Text(_canMessage ? 'Message' : _primaryLabel),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: SizedBox(
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _secondaryBackground,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(
                  color: _canMessage ? Colors.transparent : AppColors.border,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _secondaryIcon,
                      size: 20,
                      color: _secondaryColor,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _secondaryLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _secondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _primaryLabel {
    switch (connectionStatus) {
      case FriendConnectionStatus.requested:
        return 'Request sent';
      case FriendConnectionStatus.incomingRequest:
        return 'Respond';
      default:
        return 'Add friend';
    }
  }

  String get _secondaryLabel {
    switch (connectionStatus) {
      case FriendConnectionStatus.friends:
        return 'Already friends';
      case FriendConnectionStatus.requested:
        return 'Pending';
      case FriendConnectionStatus.incomingRequest:
        return 'Incoming';
      default:
        return 'Not friends';
    }
  }

  IconData get _secondaryIcon {
    switch (connectionStatus) {
      case FriendConnectionStatus.friends:
        return Icons.person_add_alt_1_rounded;
      case FriendConnectionStatus.requested:
        return Icons.schedule_rounded;
      case FriendConnectionStatus.incomingRequest:
        return Icons.mark_email_unread_outlined;
      default:
        return Icons.person_add_alt_1_rounded;
    }
  }

  Color get _secondaryBackground {
    return _canMessage ? const Color(0xFFE8F8ED) : AppColors.surface;
  }

  Color get _secondaryColor {
    return _canMessage ? const Color(0xFF168A4B) : AppColors.textSecondary;
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = switch (status) {
      FriendConnectionStatus.friends => (
          const Color(0xFFE8F8ED),
          const Color(0xFF168A4B),
          'Already friends',
        ),
      FriendConnectionStatus.requested => (
          const Color(0xFFFFF4E6),
          const Color(0xFFD97706),
          'Request pending',
        ),
      FriendConnectionStatus.incomingRequest => (
          const Color(0xFFEEF2FF),
          const Color(0xFF4F46E5),
          'Incoming request',
        ),
      _ => (
          const Color(0xFFFFF1F0),
          const Color(0xFFE15241),
          'Not friends yet',
        ),
    };

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: palette.$1,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: palette.$2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              palette.$3,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.$2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoRowData {
  const ProfileInfoRowData({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String value;
}

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.rows,
  });

  final List<ProfileInfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ProfileInfoTile(row: rows[index]),
            if (index != rows.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.row,
  });

  final ProfileInfoRowData row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: row.iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(row.icon, color: row.iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title, style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  row.value,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class ProfilePostsSection extends StatelessWidget {
  const ProfilePostsSection({
    super.key,
    required this.displayName,
    required this.username,
    required this.posts,
    required this.commentsByPostID,
    required this.expandedCommentPostIDs,
    required this.loadingCommentPostIDs,
    required this.submittingCommentPostIDs,
    required this.reactingPostIDs,
    required this.isLoading,
    required this.isLoadingMore,
    required this.onReact,
    required this.onToggleComments,
    required this.onSubmitComment,
  });

  final String displayName;
  final String username;
  final List<FeedPost> posts;
  final Map<String, List<FeedComment>> commentsByPostID;
  final Set<String> expandedCommentPostIDs;
  final Set<String> loadingCommentPostIDs;
  final Set<String> submittingCommentPostIDs;
  final Set<String> reactingPostIDs;
  final bool isLoading;
  final bool isLoadingMore;
  final ValueChanged<FeedPost> onReact;
  final ValueChanged<FeedPost> onToggleComments;
  final Future<void> Function(
    FeedPost post,
    String body,
    String parentCommentID,
  ) onSubmitComment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Posts', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Recent updates from $username',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (posts.isEmpty)
            _ProfilePostsEmptyState(displayName: displayName)
          else
            for (final post in posts) ...[
              ProfilePostCard(
                post: post,
                comments: commentsByPostID[post.id] ?? const <FeedComment>[],
                commentsExpanded: expandedCommentPostIDs.contains(post.id),
                commentsLoading: loadingCommentPostIDs.contains(post.id),
                commentSubmitting: submittingCommentPostIDs.contains(post.id),
                reactionBusy: reactingPostIDs.contains(post.id),
                onReact: () => onReact(post),
                onToggleComments: () => onToggleComments(post),
                onSubmitComment: (body, parentCommentID) =>
                    onSubmitComment(post, body, parentCommentID),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class ProfilePostCard extends StatefulWidget {
  const ProfilePostCard({
    super.key,
    required this.post,
    required this.comments,
    required this.commentsExpanded,
    required this.commentsLoading,
    required this.commentSubmitting,
    required this.reactionBusy,
    required this.onReact,
    required this.onToggleComments,
    required this.onSubmitComment,
  });

  final FeedPost post;
  final List<FeedComment> comments;
  final bool commentsExpanded;
  final bool commentsLoading;
  final bool commentSubmitting;
  final bool reactionBusy;
  final VoidCallback onReact;
  final VoidCallback onToggleComments;
  final Future<void> Function(String body, String parentCommentID)
      onSubmitComment;

  @override
  State<ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<ProfilePostCard> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String _replyingToCommentID = '';
  String _replyingToAuthorName = '';
  bool _isReplyingToReply = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final rawBody = _commentController.text.trim();
    final body = _bodyWithMention(rawBody);
    if (rawBody.isEmpty) return;

    await widget.onSubmitComment(body, _replyingToCommentID);
    if (!mounted) return;
    _commentController.clear();
    setState(() {
      _replyingToCommentID = '';
      _replyingToAuthorName = '';
      _isReplyingToReply = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final post = widget.post;
    final authorName = post.author.displayName.trim().isNotEmpty
        ? post.author.displayName.trim()
        : post.author.username;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                size: 40,
                imageUrl: post.author.avatarUrl,
                iconSize: 18,
                backgroundColor: AppColors.primarySoft,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTime(post.createdAt),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz_rounded),
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            post.caption,
            style: textTheme.bodyLarge,
          ),
          if (post.hasImage) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: AppPostImage(imageUrl: post.imageUrl),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _ProfilePostAction(
                icon: post.reactedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: post.reactionCount == 0
                    ? 'React'
                    : post.reactionCount.toString(),
                selected: post.reactedByMe,
                busy: widget.reactionBusy,
                onTap: widget.onReact,
              ),
              _ProfilePostAction(
                icon: Icons.mode_comment_outlined,
                label:
                    post.commentCount == 0 ? 'Comment' : '${post.commentCount}',
                selected: widget.commentsExpanded,
                onTap: widget.onToggleComments,
              ),
              const _ProfilePostAction(
                icon: Icons.ios_share_rounded,
                label: 'Share',
              ),
            ],
          ),
          if (widget.commentsExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            if (widget.commentsLoading)
              const Center(child: CircularProgressIndicator())
            else if (widget.comments.isEmpty)
              Text(
                'No comments yet. Start the conversation.',
                style: textTheme.bodyMedium,
              )
            else
              CommentList(
                comments: widget.comments,
                onReply: _replyToComment,
              ),
            const SizedBox(height: AppSpacing.sm),
            if (_replyingToAuthorName.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to $_replyingToAuthorName',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _replyingToCommentID = '';
                          _replyingToAuthorName = '';
                          _isReplyingToReply = false;
                        });
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                    decoration: const InputDecoration(
                      hintText: 'Write a comment',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: widget.commentSubmitting ? null : _submitComment,
                  icon: widget.commentSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _replyToComment(CommentReplyTarget target) {
    setState(() {
      _replyingToCommentID = target.parentCommentID;
      _replyingToAuthorName = target.targetUsername;
      _isReplyingToReply = target.shouldPrefixMention;
    });
    _commentFocusNode.requestFocus();
  }

  String _bodyWithMention(String body) {
    if (!_isReplyingToReply) return body;
    final username = _replyingToAuthorName.replaceFirst('@', '').trim();
    if (username.isEmpty || body.startsWith('@$username')) return body;
    return '@$username $body';
  }
}

class _ProfilePostAction extends StatelessWidget {
  const _ProfilePostAction({
    required this.icon,
    required this.label,
    this.selected = false,
    this.busy = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: color, size: 21),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePostsEmptyState extends StatelessWidget {
  const _ProfilePostsEmptyState({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textTertiary,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No posts yet', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'When $displayName shares something, it will appear here.',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime? createdAt) {
  if (createdAt == null) return 'Just now';
  final difference = DateTime.now().difference(createdAt.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}
