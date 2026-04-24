import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../data/friends_api.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.notifications,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.message,
    required this.onOpenNotification,
    required this.onLoadMore,
  });

  final List<FriendNotificationRecord> notifications;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? message;
  final ValueChanged<FriendNotificationRecord> onOpenNotification;
  final Future<void> Function() onLoadMore;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        widget.isLoading ||
        widget.isLoadingMore ||
        !widget.hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final todayNotifications = <FriendNotificationRecord>[];
    final earlierNotifications = <FriendNotificationRecord>[];
    final now = DateTime.now();

    for (final notification in widget.notifications) {
      final createdAt = notification.createdAt?.toLocal();
      final isToday = createdAt != null &&
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
      if (isToday) {
        todayNotifications.add(notification);
      } else {
        earlierNotifications.add(notification);
      }
    }

    return BrandShell(
      showBack: true,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Replies, requests, and updates in one cleaner place.',
                      style: textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.message != null)
            _NotificationEmptyState(
              title: 'Unable to load notifications',
              subtitle: widget.message!,
            )
          else if (widget.notifications.isEmpty)
            const _NotificationEmptyState(
              title: 'No notifications yet',
              subtitle: 'Friend requests and comment replies will appear here.',
            )
          else ...[
            if (todayNotifications.isNotEmpty) ...[
              _NotificationSectionLabel(
                label: 'Today',
                count: todayNotifications.length,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...todayNotifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _NotificationListTile(
                    notification: notification,
                    onOpenNotification: widget.onOpenNotification,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (earlierNotifications.isNotEmpty) ...[
              _NotificationSectionLabel(
                label: 'Earlier',
                count: earlierNotifications.length,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...earlierNotifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _NotificationListTile(
                    notification: notification,
                    onOpenNotification: widget.onOpenNotification,
                  ),
                ),
              ),
            ],
            if (widget.isLoadingMore)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NotificationSectionLabel extends StatelessWidget {
  const _NotificationSectionLabel({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  const _NotificationListTile({
    required this.notification,
    required this.onOpenNotification,
  });

  final FriendNotificationRecord notification;
  final ValueChanged<FriendNotificationRecord> onOpenNotification;

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final subtitle = _subtitle(title);
    final isUnread = notification.readAt == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpenNotification(notification),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isUnread ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isUnread ? AppColors.primary : AppColors.border,
              width: isUnread ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isUnread ? AppColors.primary : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  title.isEmpty ? 'N' : title.characters.first.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isUnread ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _metaLabel(notification.createdAt!.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  FriendSummary? get _senderCard {
    final request = notification.friendRequest;
    if (request != null) {
      return notification.isPendingIncomingRequest
          ? request.requester
          : request.addressee;
    }

    return notification.feedInteraction?.author;
  }

  String get _title {
    final explicitTitle = notification.title.trim();
    if (explicitTitle.isNotEmpty) {
      return explicitTitle;
    }

    final sender = _senderCard;
    if (sender == null) {
      return 'Notification';
    }

    final displayName = sender.displayName.trim();
    return displayName.isEmpty ? sender.username : displayName;
  }

  String _subtitle(String title) {
    if (notification.isFeedInteraction) {
      if (_senderCard == null) {
        return notification.isFeedPostComment
            ? 'Commented on your post'
            : 'Replied to your comment';
      }

      return notification.isFeedPostComment
          ? '$title commented on your post'
          : '$title replied to your comment';
    }

    final body = notification.body.trim();
    if (body.isNotEmpty) {
      return body;
    }

    return 'Friend Request';
  }

  String _metaLabel(DateTime createdAt) {
    final relativeTime = _timeAgo(createdAt);
    if (notification.isFeedInteraction) {
      return '$relativeTime · Tap to open the post';
    }
    if (notification.isPendingIncomingRequest) {
      return '$relativeTime · Tap to review';
    }
    return relativeTime;
  }

  static String _timeAgo(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays == 1) {
      return 'Yesterday';
    }
    return '${difference.inDays}d ago';
  }
}
