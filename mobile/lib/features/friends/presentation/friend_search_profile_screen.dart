import 'package:flutter/material.dart';

import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../feed/data/feed_api.dart';
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
  final ProfileApi _profileApi = ProfileApi();
  final ScrollController _scrollController = ScrollController();

  late String _connectionStatus = widget.result.connectionStatus;
  PublicProfile? _profile;
  List<FeedPost> _posts = const <FeedPost>[];
  String _nextCursor = '';
  bool _isSendingRequest = false;
  bool _isLoadingProfile = true;
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
        _isLoadingProfile = false;
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            height: 320,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFA099FF),
                  Color(0xFF5A57F4),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(42, 42),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: 64,
                      backgroundColor: Colors.white.withValues(alpha: 0.28),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFFE7E2FF),
                        child: Text(
                          _title.characters.first.toUpperCase(),
                          style: textTheme.displaySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text(
                      _title,
                      style: textTheme.headlineMedium?.copyWith(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '@$_username',
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
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            _location,
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ProfileBadge(status: _connectionStatus),
                    if (_message != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _message!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _ProfileSection(
                      title: 'About',
                      child: Text(
                        _profile?.bio.trim().isNotEmpty == true
                            ? _profile!.bio.trim()
                            : _aboutCopy(_title),
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProfileSection(
                      title: 'Identity',
                      child: Text(
                        _profile?.gender.trim().isNotEmpty == true
                            ? _profile!.gender.trim()
                            : 'Gender not shared',
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProfileSection(
                      title: 'Interests',
                      child: Text(
                        _profile?.hobbiesText.trim().isNotEmpty == true
                            ? _profile!.hobbiesText.trim()
                            : 'No interests shared yet.',
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: _isSendingRequest ||
                              _connectionStatus != FriendConnectionStatus.add
                          ? null
                          : _sendFriendRequest,
                      icon: _isSendingRequest
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_buttonIcon(_connectionStatus)),
                      label: Text(_buttonLabel(_connectionStatus)),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Posts',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _isLoadingProfile
                          ? 'Loading profile...'
                          : 'Recent updates from $_title.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_isLoadingPosts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_posts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'No posts yet.',
                          style: textTheme.bodyLarge,
                        ),
                      )
                    else
                      for (final post in _posts) ...[
                        _ProfilePostCard(post: post),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    if (_isLoadingMorePosts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  static String _buttonLabel(String status) {
    switch (status) {
      case FriendConnectionStatus.friends:
        return 'Already friends';
      case FriendConnectionStatus.requested:
        return 'Request sent';
      case FriendConnectionStatus.incomingRequest:
        return 'Respond in notifications';
      default:
        return 'Add friend';
    }
  }

  static IconData _buttonIcon(String status) {
    switch (status) {
      case FriendConnectionStatus.friends:
        return Icons.check_rounded;
      case FriendConnectionStatus.requested:
        return Icons.schedule_rounded;
      case FriendConnectionStatus.incomingRequest:
        return Icons.mark_email_unread_outlined;
      default:
        return Icons.person_add_alt_1_rounded;
    }
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

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
  });

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const ColoredBox(color: AppColors.surfaceSoft);
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            _relativeTime(post.createdAt),
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Just now';
    final difference = DateTime.now().difference(createdAt.toLocal());
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
