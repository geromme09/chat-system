import 'package:flutter/material.dart';

import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
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

  late String _connectionStatus = widget.result.connectionStatus;
  bool _isSendingRequest = false;

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
          content: Text('Friend request sent to @${widget.result.username}.'),
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = widget.result.displayName.trim().isEmpty
        ? widget.result.username
        : widget.result.displayName.trim();
    final location = widget.result.city.trim().isEmpty
        ? 'Location not shared yet'
        : widget.result.city.trim();

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
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
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
                          title.characters.first.toUpperCase(),
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text(
                      title,
                      style: textTheme.headlineMedium?.copyWith(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '@${widget.result.username}',
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
                            location,
                            style: textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ProfileBadge(status: _connectionStatus),
                    const SizedBox(height: AppSpacing.xl),
                    _ProfileSection(
                      title: 'About',
                      child: Text(
                        _aboutCopy(title),
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProfileSection(
                      title: 'Sports',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: const [
                          _SportChip(label: 'Basketball'),
                          _SportChip(label: 'Soccer'),
                          _SportChip(label: 'Running'),
                        ],
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
        return 'Open profiles first, then add people you want to connect with. This keeps the flow focused and intentional.';
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
        return Icons.add_rounded;
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
          const Color(0xFFF2F3FF),
          AppColors.primary,
          'Looking to connect',
        ),
    };

    return Container(
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
          const SizedBox(width: AppSpacing.sm),
          Text(
            palette.$3,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.$2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
