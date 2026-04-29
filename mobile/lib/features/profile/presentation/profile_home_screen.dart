import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../feed/data/feed_api.dart';
import '../../feed/presentation/post_detail_screen.dart';

enum ProfileTab { about, posts, photos }

class ProfileHomeScreen extends StatefulWidget {
  const ProfileHomeScreen({super.key});

  @override
  State<ProfileHomeScreen> createState() => _ProfileHomeScreenState();
}

class _ProfileHomeScreenState extends State<ProfileHomeScreen> {
  final FeedApi _feedApi = FeedApi();
  final ScrollController _scrollController = ScrollController();

  ProfileTab _selectedTab = ProfileTab.about;
  List<FeedPost> _posts = const <FeedPost>[];
  final Set<String> _reactingPostIDs = <String>{};
  String _nextCursor = '';
  bool _isLoadingPosts = true;
  bool _isLoadingMorePosts = false;
  String? _message;

  String get _status {
    final saved = appSession.customStatus?.trim() ?? '';
    return saved.isEmpty ? 'Looking for games this weekend!' : saved;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    final token = appSession.token;
    final userID = appSession.userID;
    if (token == null || token.isEmpty || userID == null || userID.isEmpty) {
      setState(() => _isLoadingPosts = false);
      return;
    }
    if (loadMore && (_isLoadingMorePosts || _nextCursor.isEmpty)) return;

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
        authorUserID: userID,
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

  Future<void> _toggleReaction(FeedPost post) async {
    final token = appSession.token;
    if (token == null || token.isEmpty || _reactingPostIDs.contains(post.id)) {
      return;
    }

    setState(() {
      _reactingPostIDs.add(post.id);
      final nextReacted = !post.reactedByMe;
      _posts = _posts
          .map(
            (item) => item.id == post.id
                ? item.copyWith(
                    reactedByMe: nextReacted,
                    reactionCount: item.reactionCount + (nextReacted ? 1 : -1),
                  )
                : item,
          )
          .toList();
    });

    try {
      final updated = post.reactedByMe
          ? await _feedApi.unlikePost(token: token, postID: post.id)
          : await _feedApi.likePost(token: token, postID: post.id);
      if (!mounted) return;
      setState(() {
        _posts = _posts
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
        _posts =
            _posts.map((item) => item.id == post.id ? post : item).toList();
      });
    } finally {
      if (mounted) {
        setState(() => _reactingPostIDs.remove(post.id));
      }
    }
  }

  Future<void> _openPost(FeedPost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(postID: post.id),
      ),
    );
    if (mounted) {
      _loadPosts();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMorePosts) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 280) {
      _loadPosts(loadMore: true);
    }
  }

  Future<void> _editStatus() async {
    final controller = TextEditingController(text: _status);
    final nextStatus = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update status', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  maxLength: 60,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    hintText: 'Looking for games this weekend!',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  child: const Text('Save status'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (nextStatus == null || nextStatus.trim().isEmpty) return;
    setState(() => appSession.updateCustomStatus(nextStatus));
  }

  @override
  Widget build(BuildContext context) {
    final profile = appSession.profile;
    final displayName = _valueOrFallback(profile?.displayName, 'Player');
    final username = _valueOrFallback(appSession.username, 'player');
    final location = _locationLabel(profile);
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 104),
          children: [
            ProfileHeader(
              displayName: displayName,
              avatarUrl: profile?.avatarUrl ?? '',
              onBack: canGoBack ? () => Navigator.of(context).maybePop() : null,
              onMenu: () => Navigator.of(context)
                  .pushNamed(AppRoute.accountSettings.path),
            ),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileIdentity(
                    displayName: displayName,
                    username: username,
                    location: location,
                    avatarUrl: profile?.avatarUrl ?? '',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _StatusPill(status: _status, onEdit: _editStatus),
                  const SizedBox(height: AppSpacing.lg),
                  ProfileActionRow(
                    onPrimary: () => Navigator.of(context)
                        .pushNamed(AppRoute.profileSetup.path),
                    onSecondary: () => Navigator.of(context)
                        .pushNamed(AppRoute.accountSettings.path),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ProfileTabs(
                    selected: _selectedTab,
                    onChanged: (tab) => setState(() => _selectedTab = tab),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: _buildTabContent(
                profile: profile,
                displayName: displayName,
                username: username,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required SessionProfile? profile,
    required String displayName,
    required String username,
  }) {
    switch (_selectedTab) {
      case ProfileTab.about:
        return ProfileInfoCard(
          rows: [
            ProfileInfoRowData(
              icon: Icons.person_outline_rounded,
              iconBackground: AppColors.primarySoft,
              iconColor: AppColors.primary,
              title: 'About',
              value: _valueOrFallback(
                profile?.bio,
                'Add a short intro so friends know a little about you.',
              ),
            ),
            ProfileInfoRowData(
              icon: Icons.badge_outlined,
              iconBackground: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
              title: 'Identity',
              value: _valueOrFallback(profile?.gender, 'Gender not shared'),
            ),
            ProfileInfoRowData(
              icon: Icons.auto_awesome_rounded,
              iconBackground: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFF59E0B),
              title: 'Interests',
              value: _valueOrFallback(
                profile?.hobbiesText,
                'No hobbies or interests added yet.',
              ),
            ),
          ],
        );
      case ProfileTab.posts:
        return ProfilePostsSection(
          displayName: displayName,
          username: username,
          posts: _posts,
          isLoading: _isLoadingPosts,
          isLoadingMore: _isLoadingMorePosts,
          message: _message,
          onReact: _toggleReaction,
          onComment: _openPost,
        );
      case ProfileTab.photos:
        final photos = _posts.where((post) => post.hasImage).toList();
        return _PhotosGrid(posts: photos);
    }
  }

  static String _valueOrFallback(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String _locationLabel(SessionProfile? profile) {
    final parts = <String>[
      if ((profile?.city.trim() ?? '').isNotEmpty) profile!.city.trim(),
      if ((profile?.country.trim() ?? '').isNotEmpty) profile!.country.trim(),
    ];
    return parts.isEmpty ? 'Location not set' : parts.join(', ');
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.onBack,
    required this.onMenu,
  });

  final String displayName;
  final String avatarUrl;
  final VoidCallback? onBack;
  final VoidCallback onMenu;

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
                    left: 0,
                    top: 0,
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
                SizedBox(
                  width: 44,
                  height: 44,
                  child: onBack == null
                      ? null
                      : _RoundIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: onBack!,
                        ),
                ),
                const Spacer(),
                _RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: onMenu,
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    this.avatarUrl = '',
  });

  final String displayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
            child: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: AppAvatar(
                size: 112,
                imageUrl: avatarUrl,
                iconSize: 42,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
          ),
        ],
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
    required this.avatarUrl,
  });

  final String displayName;
  final String username;
  final String location;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xs),
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
          style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.onEdit,
  });

  final String status;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: const Color(0xFFDCEFE2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sports_esports_rounded,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size(40, 40),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({
    super.key,
    required this.onPrimary,
    required this.onSecondary,
  });

  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onPrimary,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onSecondary,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Settings'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ProfileTab selected;
  final ValueChanged<ProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProfileTabButton(
          label: 'About',
          selected: selected == ProfileTab.about,
          onTap: () => onChanged(ProfileTab.about),
        ),
        _ProfileTabButton(
          label: 'Posts',
          selected: selected == ProfileTab.posts,
          onTap: () => onChanged(ProfileTab.posts),
        ),
        _ProfileTabButton(
          label: 'Photos',
          selected: selected == ProfileTab.photos,
          onTap: () => onChanged(ProfileTab.photos),
        ),
      ],
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            SizedBox(
              height: 3,
              width: double.infinity,
              child: AnimatedAlign(
                duration: AppMotion.quick,
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: selected ? 1 : 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            ProfileInfoRow(row: rows[index]),
            if (index != rows.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
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
    required this.isLoading,
    required this.isLoadingMore,
    required this.onReact,
    required this.onComment,
    this.message,
  });

  final String displayName;
  final String username;
  final List<FeedPost> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final ValueChanged<FeedPost> onReact;
  final ValueChanged<FeedPost> onComment;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Posts', style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text('Recent updates from $username', style: textTheme.bodyMedium),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message!,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ],
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
            _ProfilePostCard(
              post: post,
              onReact: () => onReact(post),
              onComment: () => onComment(post),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
    required this.onReact,
    required this.onComment,
  });

  final FeedPost post;
  final VoidCallback onReact;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                    Text(_relativeTime(post.createdAt),
                        style: textTheme.bodySmall),
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
          Text(post.caption, style: textTheme.bodyLarge),
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
              _PostAction(
                icon: post.reactedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: post.reactionCount == 0
                    ? 'React'
                    : post.reactionCount.toString(),
                selected: post.reactedByMe,
                onTap: onReact,
              ),
              _PostAction(
                icon: Icons.mode_comment_outlined,
                label:
                    post.commentCount == 0 ? 'Comment' : '${post.commentCount}',
                onTap: onComment,
              ),
              const _PostAction(
                icon: Icons.ios_share_rounded,
                label: 'Share',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
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
              Icons.article_outlined,
              color: AppColors.primary,
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

class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({
    required this.posts,
  });

  final List<FeedPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const _EmptyPanel(
        title: 'No photos yet',
        subtitle: 'Photos from your posts will appear here.',
        icon: Icons.photo_library_outlined,
      );
    }
    return GridView.builder(
      itemCount: posts.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AppPostImage(imageUrl: posts[index].imageUrl),
        );
      },
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
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
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
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
