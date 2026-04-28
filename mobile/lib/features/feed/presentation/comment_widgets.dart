import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_avatar.dart';
import '../data/feed_api.dart';

class CommentReplyTarget {
  const CommentReplyTarget({
    required this.parentCommentID,
    required this.targetUserID,
    required this.targetUsername,
    required this.replyDepth,
    required this.shouldPrefixMention,
  });

  final String parentCommentID;
  final String targetUserID;
  final String targetUsername;
  final int replyDepth;
  final bool shouldPrefixMention;
}

class CommentList extends StatefulWidget {
  const CommentList({
    super.key,
    required this.comments,
    required this.onReply,
    this.focusCommentID = '',
    this.initialCommentLimit = 10,
    this.commentBatchSize = 10,
  });

  final List<FeedComment> comments;
  final ValueChanged<CommentReplyTarget> onReply;
  final String focusCommentID;
  final int initialCommentLimit;
  final int commentBatchSize;

  @override
  State<CommentList> createState() => _CommentListState();
}

class _CommentListState extends State<CommentList> {
  late int _visibleCommentCount = widget.initialCommentLimit;
  final Map<String, int> _visibleReplyCountsByID = <String, int>{};

  @override
  void initState() {
    super.initState();
    _revealFocusedComment();
  }

  @override
  void didUpdateWidget(CommentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comments != widget.comments ||
        oldWidget.focusCommentID != widget.focusCommentID) {
      _revealFocusedComment();
    }
  }

  void _revealFocusedComment() {
    final focusID = widget.focusCommentID.trim();
    if (focusID.isEmpty) return;

    final tree = _CommentTree.build(widget.comments);
    final rootIndex = tree.roots.indexWhere((comment) => comment.id == focusID);
    if (rootIndex >= 0) {
      _visibleCommentCount = _max(_visibleCommentCount, rootIndex + 1);
      return;
    }

    for (var index = 0; index < tree.roots.length; index++) {
      final root = tree.roots[index];
      final replies = tree.repliesByRootID[root.id] ?? const <FeedComment>[];
      final replyIndex = replies.indexWhere((reply) => reply.id == focusID);
      if (replyIndex >= 0) {
        _visibleCommentCount = _max(_visibleCommentCount, index + 1);
        _visibleReplyCountsByID[root.id] = _safeVisibleCount(
          neededCount: replyIndex + 1,
          totalCount: replies.length,
        );
        return;
      }

      for (final reply in replies) {
        final nested =
            tree.nestedRepliesByReplyID[reply.id] ?? const <FeedComment>[];
        final nestedIndex =
            nested.indexWhere((nestedReply) => nestedReply.id == focusID);
        if (nestedIndex < 0) continue;

        _visibleCommentCount = _max(_visibleCommentCount, index + 1);
        _visibleReplyCountsByID[root.id] = _max(
          _visibleReplyCountsByID[root.id] ?? 0,
          replies.indexOf(reply) + 1,
        );
        _visibleReplyCountsByID[reply.id] = _safeVisibleCount(
          neededCount: nestedIndex + 1,
          totalCount: nested.length,
        );
        return;
      }
    }
  }

  int _safeVisibleCount({
    required int neededCount,
    required int totalCount,
  }) {
    if (totalCount <= 0) return 0;
    final minimumVisible = totalCount < ReplyList.initialReplyLimit
        ? totalCount
        : ReplyList.initialReplyLimit;
    return neededCount.clamp(minimumVisible, totalCount);
  }

  void _showMoreComments(int totalCount) {
    setState(() {
      _visibleCommentCount =
          (_visibleCommentCount + widget.commentBatchSize).clamp(0, totalCount);
    });
  }

  void _toggleReplies(String ownerID) {
    setState(() {
      final currentCount = _visibleReplyCountsByID[ownerID] ?? 0;
      if (currentCount == 0) {
        _visibleReplyCountsByID[ownerID] = ReplyList.initialReplyLimit;
      } else {
        _visibleReplyCountsByID.remove(ownerID);
      }
    });
  }

  void _showMoreReplies(String ownerID, int totalCount) {
    setState(() {
      final currentCount = _visibleReplyCountsByID[ownerID] ?? 0;
      _visibleReplyCountsByID[ownerID] =
          (currentCount + ReplyList.replyBatchSize).clamp(0, totalCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tree = _CommentTree.build(widget.comments);
    final visibleRoots = tree.roots.take(_visibleCommentCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final comment in visibleRoots)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CommentItem(
              comment: comment,
              replies:
                  tree.repliesByRootID[comment.id] ?? const <FeedComment>[],
              nestedRepliesByReplyID: tree.nestedRepliesByReplyID,
              visibleReplyCountsByID: _visibleReplyCountsByID,
              focusCommentID: widget.focusCommentID,
              onReply: widget.onReply,
              onToggleReplies: _toggleReplies,
              onViewMoreReplies: _showMoreReplies,
            ),
          ),
        if (_visibleCommentCount < tree.roots.length)
          ViewMoreButton(
            label: 'View more comments',
            onTap: () => _showMoreComments(tree.roots.length),
          ),
      ],
    );
  }
}

class CommentItem extends StatelessWidget {
  const CommentItem({
    super.key,
    required this.comment,
    required this.replies,
    required this.nestedRepliesByReplyID,
    required this.visibleReplyCountsByID,
    required this.focusCommentID,
    required this.onReply,
    required this.onToggleReplies,
    required this.onViewMoreReplies,
  });

  final FeedComment comment;
  final List<FeedComment> replies;
  final Map<String, List<FeedComment>> nestedRepliesByReplyID;
  final Map<String, int> visibleReplyCountsByID;
  final String focusCommentID;
  final ValueChanged<CommentReplyTarget> onReply;
  final ValueChanged<String> onToggleReplies;
  final void Function(String ownerID, int totalCount) onViewMoreReplies;

  @override
  Widget build(BuildContext context) {
    final visibleReplyCount = visibleReplyCountsByID[comment.id] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentBubble(
          comment: comment,
          depth: 1,
          isHighlighted: comment.id == focusCommentID,
          onReply: () => onReply(_replyTargetFor(comment, depth: 1)),
        ),
        if (replies.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: ViewRepliesButton(
              label: visibleReplyCount == 0
                  ? 'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}'
                  : 'Hide replies',
              onTap: () => onToggleReplies(comment.id),
            ),
          ),
        ],
        if (visibleReplyCount > 0)
          ReplyList(
            ownerID: comment.id,
            replies: replies,
            nestedRepliesByReplyID: nestedRepliesByReplyID,
            visibleReplyCountsByID: visibleReplyCountsByID,
            visibleReplyCount: visibleReplyCount,
            focusCommentID: focusCommentID,
            depth: 2,
            onReply: onReply,
            onToggleReplies: onToggleReplies,
            onViewMoreReplies: onViewMoreReplies,
          ),
      ],
    );
  }
}

class ReplyList extends StatelessWidget {
  const ReplyList({
    super.key,
    required this.ownerID,
    required this.replies,
    required this.nestedRepliesByReplyID,
    required this.visibleReplyCountsByID,
    required this.visibleReplyCount,
    required this.focusCommentID,
    required this.depth,
    required this.onReply,
    required this.onToggleReplies,
    required this.onViewMoreReplies,
  });

  static const int initialReplyLimit = 3;
  static const int replyBatchSize = 3;

  final String ownerID;
  final List<FeedComment> replies;
  final Map<String, List<FeedComment>> nestedRepliesByReplyID;
  final Map<String, int> visibleReplyCountsByID;
  final int visibleReplyCount;
  final String focusCommentID;
  final int depth;
  final ValueChanged<CommentReplyTarget> onReply;
  final ValueChanged<String> onToggleReplies;
  final void Function(String ownerID, int totalCount) onViewMoreReplies;

  @override
  Widget build(BuildContext context) {
    final visibleReplies = replies.take(visibleReplyCount);

    return Padding(
      padding:
          EdgeInsets.only(left: _indentForDepth(depth), top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reply in visibleReplies)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ReplyThread(
                ownerID: ownerID,
                reply: reply,
                nestedReplies:
                    nestedRepliesByReplyID[reply.id] ?? const <FeedComment>[],
                visibleReplyCountsByID: visibleReplyCountsByID,
                focusCommentID: focusCommentID,
                depth: depth,
                onReply: onReply,
                onToggleReplies: onToggleReplies,
                onViewMoreReplies: onViewMoreReplies,
              ),
            ),
          if (visibleReplyCount < replies.length)
            ViewMoreButton(
              label: 'View more replies',
              onTap: () => onViewMoreReplies(ownerID, replies.length),
            ),
        ],
      ),
    );
  }
}

class _ReplyThread extends StatelessWidget {
  const _ReplyThread({
    required this.ownerID,
    required this.reply,
    required this.nestedReplies,
    required this.visibleReplyCountsByID,
    required this.focusCommentID,
    required this.depth,
    required this.onReply,
    required this.onToggleReplies,
    required this.onViewMoreReplies,
  });

  final String ownerID;
  final FeedComment reply;
  final List<FeedComment> nestedReplies;
  final Map<String, int> visibleReplyCountsByID;
  final String focusCommentID;
  final int depth;
  final ValueChanged<CommentReplyTarget> onReply;
  final ValueChanged<String> onToggleReplies;
  final void Function(String ownerID, int totalCount) onViewMoreReplies;

  @override
  Widget build(BuildContext context) {
    final nestedVisibleCount = visibleReplyCountsByID[reply.id] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentBubble(
          comment: reply,
          depth: depth,
          isHighlighted: reply.id == focusCommentID,
          onReply: () => onReply(
            _replyTargetFor(
              reply,
              depth: depth,
              parentCommentID: depth >= 3 ? ownerID : reply.id,
            ),
          ),
        ),
        if (nestedReplies.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: ViewRepliesButton(
              label: nestedVisibleCount == 0
                  ? 'View ${nestedReplies.length} ${nestedReplies.length == 1 ? 'reply' : 'replies'}'
                  : 'Hide replies',
              onTap: () => onToggleReplies(reply.id),
            ),
          ),
        ],
        if (nestedVisibleCount > 0)
          ReplyList(
            ownerID: reply.id,
            replies: nestedReplies,
            nestedRepliesByReplyID: const <String, List<FeedComment>>{},
            visibleReplyCountsByID: visibleReplyCountsByID,
            visibleReplyCount: nestedVisibleCount,
            focusCommentID: focusCommentID,
            depth: 3,
            onReply: onReply,
            onToggleReplies: onToggleReplies,
            onViewMoreReplies: onViewMoreReplies,
          ),
      ],
    );
  }
}

class ViewRepliesButton extends StatelessWidget {
  const ViewRepliesButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ViewMoreButton(label: label, onTap: onTap);
  }
}

class ViewMoreButton extends StatelessWidget {
  const ViewMoreButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class ReplyContextBar extends StatelessWidget {
  const ReplyContextBar({
    super.key,
    required this.username,
    required this.onCancel,
  });

  final String username;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cleanUsername = username.replaceFirst('@', '');
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Replying to @$cleanUsername',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              InkWell(
                onTap: onCancel,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    'Cancel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
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

class CommentInputBar extends StatelessWidget {
  const CommentInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.onSubmit,
    this.replyingToUsername = '',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String replyingToUsername;

  @override
  Widget build(BuildContext context) {
    final cleanUsername = replyingToUsername.replaceFirst('@', '');
    final isReplying = cleanUsername.trim().isNotEmpty;

    return Material(
      color: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: isReplying
                      ? 'Reply to @$cleanUsername'
                      : 'Write a comment',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.compact,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: isSubmitting ? null : onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textTertiary,
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.depth,
    required this.isHighlighted,
    required this.onReply,
  });

  final FeedComment comment;
  final int depth;
  final bool isHighlighted;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authorName = comment.author.displayName.trim().isNotEmpty
        ? comment.author.displayName.trim()
        : comment.author.username;
    final avatarRadius = depth == 1 ? 16.0 : 14.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(
          size: avatarRadius * 2,
          imageUrl: comment.author.avatarUrl,
          iconSize: avatarRadius,
          backgroundColor: AppColors.surfaceSoft,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.compact,
            ),
            decoration: BoxDecoration(
              color:
                  isHighlighted ? AppColors.primarySoft : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isHighlighted ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorName,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      _relativeTime(comment.createdAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: onReply,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Reply',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTree {
  const _CommentTree({
    required this.roots,
    required this.repliesByRootID,
    required this.nestedRepliesByReplyID,
  });

  final List<FeedComment> roots;
  final Map<String, List<FeedComment>> repliesByRootID;
  final Map<String, List<FeedComment>> nestedRepliesByReplyID;

  factory _CommentTree.build(List<FeedComment> comments) {
    final commentsByID = <String, FeedComment>{
      for (final comment in comments) comment.id: comment,
    };
    final roots = <FeedComment>[];
    final repliesByRootID = <String, List<FeedComment>>{};
    final nestedRepliesByReplyID = <String, List<FeedComment>>{};

    for (final comment in comments) {
      final parentID = comment.parentCommentID.trim();
      final parent = commentsByID[parentID];
      if (parentID.isEmpty || parent == null) {
        roots.add(comment);
        continue;
      }

      final root = _rootFor(comment, commentsByID);
      if (root == null || root.id == comment.id) {
        roots.add(comment);
        continue;
      }

      final levelTwoAncestor = _levelTwoAncestorFor(comment, commentsByID);
      if (levelTwoAncestor == null || levelTwoAncestor.id == comment.id) {
        repliesByRootID
            .putIfAbsent(root.id, () => <FeedComment>[])
            .add(comment);
        continue;
      }

      nestedRepliesByReplyID
          .putIfAbsent(levelTwoAncestor.id, () => <FeedComment>[])
          .add(comment);
    }

    return _CommentTree(
      roots: roots,
      repliesByRootID: repliesByRootID,
      nestedRepliesByReplyID: nestedRepliesByReplyID,
    );
  }

  static FeedComment? _rootFor(
    FeedComment comment,
    Map<String, FeedComment> commentsByID,
  ) {
    var current = comment;
    final seenIDs = <String>{comment.id};

    while (true) {
      final parent = commentsByID[current.parentCommentID.trim()];
      if (parent == null) return current == comment ? null : current;
      if (!seenIDs.add(parent.id)) return current;
      current = parent;
    }
  }

  static FeedComment? _levelTwoAncestorFor(
    FeedComment comment,
    Map<String, FeedComment> commentsByID,
  ) {
    var current = comment;
    final seenIDs = <String>{comment.id};
    FeedComment? childOfRoot;

    while (true) {
      final parent = commentsByID[current.parentCommentID.trim()];
      if (parent == null) return childOfRoot;
      if (parent.parentCommentID.trim().isEmpty) return current;
      if (!seenIDs.add(parent.id)) return childOfRoot;
      childOfRoot = parent;
      current = parent;
    }
  }
}

CommentReplyTarget _replyTargetFor(
  FeedComment comment, {
  required int depth,
  String? parentCommentID,
}) {
  final cappedDepth = depth.clamp(1, 3);
  final targetUsername = _usernameFor(comment);

  return CommentReplyTarget(
    parentCommentID: parentCommentID ?? comment.id,
    targetUserID: comment.author.userID,
    targetUsername: targetUsername,
    replyDepth: cappedDepth == 1 ? 2 : 3,
    shouldPrefixMention: cappedDepth >= 2,
  );
}

double _indentForDepth(int depth) {
  if (depth <= 1) return 0;
  if (depth == 2) return 24;
  return 40;
}

int _max(int left, int right) => left > right ? left : right;

String _usernameFor(FeedComment comment) {
  final username = comment.author.username.trim();
  if (username.isNotEmpty) return username;
  final displayName = comment.author.displayName.trim();
  return displayName.isEmpty
      ? 'user'
      : displayName.replaceAll(' ', '').toLowerCase();
}

String _relativeTime(DateTime? createdAt) {
  if (createdAt == null) return 'Just now';
  final difference = DateTime.now().difference(createdAt.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  return '${difference.inDays}d';
}
