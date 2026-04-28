import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_back_button.dart';
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
    final sections = _NotificationSections.from(widget.notifications);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            _NotificationsHeader(
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Notifications',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTypography.loginTitle,
                height: AppTypography.compactLineHeight,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Replies, requests, and updates in one cleaner place.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTypography.body,
                height: AppTypography.bodyLineHeight,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
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
                subtitle:
                    'Friend requests, replies, and updates will appear here.',
              )
            else ...[
              if (sections.newItems.isNotEmpty)
                NotificationSection(
                  title: 'New',
                  notifications: sections.newItems,
                  onOpenNotification: widget.onOpenNotification,
                ),
              if (sections.todayItems.isNotEmpty)
                NotificationSection(
                  title: 'Today',
                  notifications: sections.todayItems,
                  onOpenNotification: widget.onOpenNotification,
                ),
              if (sections.earlierItems.isNotEmpty)
                NotificationSection(
                  title: 'Earlier',
                  notifications: sections.earlierItems,
                  onOpenNotification: widget.onOpenNotification,
                ),
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
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppBackButton(onPressed: onBack),
        const Spacer(),
        Container(
          width: AppSizes.notificationIconButton,
          height: AppSizes.notificationIconButton,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class NotificationSection extends StatelessWidget {
  const NotificationSection({
    super.key,
    required this.title,
    required this.notifications,
    required this.onOpenNotification,
  });

  final String title;
  final List<NotificationCardModel> notifications;
  final ValueChanged<FriendNotificationRecord> onOpenNotification;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.titleSmall,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CountPill(count: notifications.length),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...notifications.map(
            (notification) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: NotificationCard(
                notification: notification,
                onTap: () => onOpenNotification(notification.source),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CountPill extends StatelessWidget {
  const CountPill({
    super.key,
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: AppTypography.helper,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final NotificationCardModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeStyle = NotificationTypeStyle.resolve(notification.actionType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: notification.isUnread
                ? AppColors.primarySoft.withValues(
                    alpha: AppOpacity.notificationUnread,
                  )
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.border.withValues(
                alpha: AppOpacity.notificationBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              _NotificationAvatar(
                avatarUrl: notification.avatarUrl,
                initials: notification.initials,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.body,
                        fontWeight: notification.isUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.caption,
                          height: AppTypography.helperLineHeight,
                          fontWeight: notification.isUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        children: [
                          TextSpan(
                            text: notification.actionLabel,
                            style: TextStyle(
                              color: typeStyle.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: ' ${notification.message}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.timestamp,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: AppTypography.caption,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (notification.isUnread) ...[
                Container(
                  width: AppSizes.notificationUnreadDot,
                  height: AppSizes.notificationUnreadDot,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
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

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({
    required this.avatarUrl,
    required this.initials,
  });

  final String avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.notificationAvatar,
      height: AppSizes.notificationAvatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(
          alpha: AppOpacity.notificationAvatarImage,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.trim().isNotEmpty
          ? AppAvatar(
              size: AppSizes.notificationAvatar,
              imageUrl: avatarUrl,
              iconSize: 18,
              backgroundColor: Colors.transparent,
            )
          : _InitialsAvatar(initials: initials),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
  });

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: AppTypography.body,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class NotificationTypeStyle {
  const NotificationTypeStyle({
    required this.color,
  });

  final Color color;

  static NotificationTypeStyle resolve(NotificationActionType actionType) {
    return switch (actionType) {
      NotificationActionType.replied => const NotificationTypeStyle(
          color: AppColors.primary,
        ),
      NotificationActionType.commented => const NotificationTypeStyle(
          color: AppColors.primary,
        ),
      NotificationActionType.liked => const NotificationTypeStyle(
          color: AppColors.like,
        ),
      NotificationActionType.accepted => const NotificationTypeStyle(
          color: AppColors.accepted,
        ),
      NotificationActionType.mentioned => const NotificationTypeStyle(
          color: AppColors.mentioned,
        ),
      NotificationActionType.shared => const NotificationTypeStyle(
          color: AppColors.shared,
        ),
      NotificationActionType.requested => const NotificationTypeStyle(
          color: AppColors.primary,
        ),
      NotificationActionType.updated => const NotificationTypeStyle(
          color: AppColors.textSecondary,
        ),
    };
  }
}

class NotificationCardModel {
  const NotificationCardModel({
    required this.username,
    required this.avatarUrl,
    required this.initials,
    required this.actionType,
    required this.actionLabel,
    required this.message,
    required this.timestamp,
    required this.isUnread,
    required this.source,
  });

  final String username;
  final String avatarUrl;
  final String initials;
  final NotificationActionType actionType;
  final String actionLabel;
  final String message;
  final String timestamp;
  final bool isUnread;
  final FriendNotificationRecord source;

  factory NotificationCardModel.fromRecord(
    FriendNotificationRecord notification,
  ) {
    final sender = _senderCard(notification);
    final username = _displayName(notification, sender);
    final actionType = _actionType(notification);

    return NotificationCardModel(
      username: username,
      avatarUrl: sender?.avatarUrl ?? '',
      initials: _initials(username),
      actionType: actionType,
      actionLabel: _actionLabel(actionType),
      message: _message(notification),
      timestamp: notification.createdAt == null
          ? ''
          : _timeAgo(notification.createdAt!.toLocal()),
      isUnread: notification.readAt == null,
      source: notification,
    );
  }

  static FriendSummary? _senderCard(FriendNotificationRecord notification) {
    final request = notification.friendRequest;
    if (request != null) {
      return notification.isPendingIncomingRequest
          ? request.requester
          : request.addressee;
    }

    return notification.feedInteraction?.author;
  }

  static String _displayName(
    FriendNotificationRecord notification,
    FriendSummary? sender,
  ) {
    if (sender != null) {
      final displayName = sender.displayName.trim();
      return displayName.isEmpty ? sender.username : displayName;
    }

    final explicitTitle = notification.title.trim();
    return explicitTitle.isEmpty ? 'Notification' : explicitTitle;
  }

  static NotificationActionType _actionType(
    FriendNotificationRecord notification,
  ) {
    if (notification.isFeedReply) return NotificationActionType.replied;
    if (notification.isFeedPostComment) return NotificationActionType.commented;
    if (notification.isAcceptedRequest) return NotificationActionType.accepted;
    if (notification.isPendingIncomingRequest) {
      return NotificationActionType.requested;
    }

    final type = notification.type.toLowerCase();
    if (type.contains('like')) return NotificationActionType.liked;
    if (type.contains('mention')) return NotificationActionType.mentioned;
    if (type.contains('share')) return NotificationActionType.shared;

    return NotificationActionType.updated;
  }

  static String _actionLabel(NotificationActionType actionType) {
    return switch (actionType) {
      NotificationActionType.replied => 'replied',
      NotificationActionType.commented => 'commented',
      NotificationActionType.liked => 'liked',
      NotificationActionType.accepted => 'accepted',
      NotificationActionType.mentioned => 'mentioned',
      NotificationActionType.shared => 'shared',
      NotificationActionType.requested => 'sent',
      NotificationActionType.updated => 'updated',
    };
  }

  static String _message(FriendNotificationRecord notification) {
    if (notification.isFeedReply) return 'to your comment';
    if (notification.isFeedPostComment) return 'on your post';
    if (notification.isAcceptedRequest) return 'your request';
    if (notification.isPendingIncomingRequest) return 'you a friend request';

    final body = notification.body.trim();
    return body.isEmpty ? 'your notifications' : body;
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'N';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  static String _timeAgo(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';

    return '${difference.inDays}d ago';
  }
}

class _NotificationSections {
  const _NotificationSections({
    required this.newItems,
    required this.todayItems,
    required this.earlierItems,
  });

  final List<NotificationCardModel> newItems;
  final List<NotificationCardModel> todayItems;
  final List<NotificationCardModel> earlierItems;

  factory _NotificationSections.from(
    List<FriendNotificationRecord> notifications,
  ) {
    final newItems = <NotificationCardModel>[];
    final todayItems = <NotificationCardModel>[];
    final earlierItems = <NotificationCardModel>[];
    final now = DateTime.now();

    for (final notification in notifications) {
      final model = NotificationCardModel.fromRecord(notification);
      final createdAt = notification.createdAt?.toLocal();
      final isToday = createdAt != null &&
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;

      if (notification.readAt == null) {
        newItems.add(model);
      } else if (isToday) {
        todayItems.add(model);
      } else {
        earlierItems.add(model);
      }
    }

    return _NotificationSections(
      newItems: newItems,
      todayItems: todayItems,
      earlierItems: earlierItems,
    );
  }
}

enum NotificationActionType {
  replied,
  commented,
  liked,
  accepted,
  mentioned,
  shared,
  requested,
  updated,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: AppSizes.notificationAvatar,
            height: AppSizes.notificationAvatar,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
