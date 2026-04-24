import 'package:flutter/material.dart';

import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../../friends/data/friend_search_api.dart';
import '../../friends/presentation/friend_search_profile_screen.dart';
import '../../home/presentation/home_shell_screen.dart';
import '../data/feed_api.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postID,
    this.focusCommentID = '',
  });

  final String postID;
  final String focusCommentID;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FeedApi _feedApi = FeedApi();
  final TextEditingController _commentController = TextEditingController();

  FeedPost? _post;
  List<FeedComment> _comments = const <FeedComment>[];
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  bool _isReacting = false;
  String _replyingToCommentID = '';
  String _replyingToAuthorName = '';
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Please sign in again to open this post.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _feedApi.getPost(token: token, postID: widget.postID),
        _feedApi.listComments(token: token, postID: widget.postID, limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _post = results[0] as FeedPost;
        _comments = results[1] as List<FeedComment>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleReaction() async {
    final token = appSession.token;
    final post = _post;
    if (token == null || token.isEmpty || post == null || _isReacting) {
      return;
    }

    setState(() {
      _isReacting = true;
      final nextReacted = !post.reactedByMe;
      _post = post.copyWith(
        reactedByMe: nextReacted,
        reactionCount: post.reactionCount + (nextReacted ? 1 : -1),
      );
    });

    try {
      final updated =
          await _feedApi.toggleReaction(token: token, postID: post.id);
      if (!mounted) return;
      setState(() {
        _post = updated;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
        _post = post;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReacting = false;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final token = appSession.token;
    final post = _post;
    final body = _commentController.text.trim();
    if (token == null ||
        token.isEmpty ||
        post == null ||
        body.isEmpty ||
        _isSubmittingComment) {
      return;
    }

    setState(() {
      _isSubmittingComment = true;
      _message = null;
    });

    try {
      final comment = await _feedApi.createComment(
        token: token,
        postID: post.id,
        request: CreateFeedCommentRequest(
          body: body,
          parentCommentID: _replyingToCommentID,
        ),
      );
      if (!mounted) return;
      setState(() {
        _comments = <FeedComment>[..._comments, comment];
        _post = post.copyWith(commentCount: post.commentCount + 1);
        _commentController.clear();
        _replyingToCommentID = '';
        _replyingToAuthorName = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  void _openAuthorProfile(FeedPostAuthor author) {
    if (_isCurrentUser(author.userID)) {
      _openMyProfileTab();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendSearchProfileScreen(
          result: _friendSearchResultFromAuthor(author),
        ),
      ),
    );
  }

  bool _isCurrentUser(String userID) => userID == appSession.userID;

  void _openMyProfileTab() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const HomeShellScreen(args: HomeShellArgs(initialTabIndex: 2)),
      ),
    );
  }

  FriendSearchResult _friendSearchResultFromAuthor(FeedPostAuthor author) {
    return FriendSearchResult(
      userID: author.userID,
      username: author.username,
      displayName: author.displayName,
      avatarUrl: author.avatarUrl,
      city: author.city,
      connectionStatus: author.connectionStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final textTheme = Theme.of(context).textTheme;

    return BrandShell(
      showBack: true,
      child: RefreshIndicator(
        onRefresh: _loadPost,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Text('Post', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Stay in context and keep the conversation going here.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (post == null)
              SectionCard(
                child: Text(
                  _message ?? 'Unable to load this post.',
                  style: textTheme.bodyMedium,
                ),
              )
            else ...[
              _PostCard(
                post: post,
                comments: _comments,
                focusCommentID: widget.focusCommentID,
                isSubmitting: _isSubmittingComment,
                isReacting: _isReacting,
                controller: _commentController,
                replyingToAuthorName: _replyingToAuthorName,
                onOpenAuthorProfile: () => _openAuthorProfile(post.author),
                onReact: _toggleReaction,
                onReplyToComment: (comment) {
                  final authorName =
                      comment.author.displayName.trim().isNotEmpty
                          ? comment.author.displayName.trim()
                          : comment.author.username;
                  setState(() {
                    _replyingToCommentID = comment.id;
                    _replyingToAuthorName = authorName;
                  });
                },
                onCancelReply: () {
                  setState(() {
                    _replyingToCommentID = '';
                    _replyingToAuthorName = '';
                  });
                },
                onSubmitComment: _submitComment,
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _message!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.comments,
    required this.focusCommentID,
    required this.isSubmitting,
    required this.isReacting,
    required this.controller,
    required this.replyingToAuthorName,
    required this.onOpenAuthorProfile,
    required this.onReact,
    required this.onReplyToComment,
    required this.onCancelReply,
    required this.onSubmitComment,
  });

  final FeedPost post;
  final List<FeedComment> comments;
  final String focusCommentID;
  final bool isSubmitting;
  final bool isReacting;
  final TextEditingController controller;
  final String replyingToAuthorName;
  final VoidCallback onOpenAuthorProfile;
  final VoidCallback onReact;
  final ValueChanged<FeedComment> onReplyToComment;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmitComment;

  @override
  Widget build(BuildContext context) {
    final authorName = post.author.displayName.trim().isNotEmpty
        ? post.author.displayName.trim()
        : post.author.username;
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenAuthorProfile,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    _initialsFor(authorName),
                    style: textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '@${post.author.username} · ${_relativeTime(post.createdAt)}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(post.caption, style: textTheme.bodyLarge),
          if (post.hasImage) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _FeedPostImage(imageUrl: post.imageUrl),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: isReacting ? null : onReact,
                  icon: isReacting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          post.reactedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: post.reactedByMe
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                  label: Text(
                    post.reactionCount == 0
                        ? 'React'
                        : '${post.reactionCount} reacts',
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: Text(
                    post.commentCount == 0
                        ? 'Comment'
                        : '${post.commentCount} comments',
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.border),
          _RecursiveCommentsSection(
            comments: comments,
            focusCommentID: focusCommentID,
            controller: controller,
            isSubmitting: isSubmitting,
            replyingToAuthorName: replyingToAuthorName,
            onReplyToComment: onReplyToComment,
            onCancelReply: onCancelReply,
            onSubmit: onSubmitComment,
          ),
        ],
      ),
    );
  }

  static String _initialsFor(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((it) => it.isNotEmpty);
    final values = parts.toList();
    if (values.isEmpty) return 'P';
    if (values.length == 1) return values.first.substring(0, 1).toUpperCase();
    return '${values.first.substring(0, 1)}${values.last.substring(0, 1)}'
        .toUpperCase();
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

class _RecursiveCommentsSection extends StatelessWidget {
  const _RecursiveCommentsSection({
    required this.comments,
    required this.focusCommentID,
    required this.controller,
    required this.isSubmitting,
    required this.replyingToAuthorName,
    required this.onReplyToComment,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final List<FeedComment> comments;
  final String focusCommentID;
  final TextEditingController controller;
  final bool isSubmitting;
  final String replyingToAuthorName;
  final ValueChanged<FeedComment> onReplyToComment;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tree = _CommentTree.build(comments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tree.roots.isEmpty)
          Text(
            'No comments yet. Start the conversation.',
            style: textTheme.bodyMedium,
          )
        else
          ...tree.roots.map(
            (node) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CommentBranch(
                node: node,
                repliesByParentID: tree.repliesByParentID,
                onReply: onReplyToComment,
                focusCommentID: focusCommentID,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (replyingToAuthorName.trim().isNotEmpty) ...[
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
                    'Replying to $replyingToAuthorName',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onCancelReply,
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
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: const InputDecoration(
                  hintText: 'Write a comment',
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
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentBranch extends StatelessWidget {
  const _CommentBranch({
    required this.node,
    required this.repliesByParentID,
    required this.onReply,
    required this.focusCommentID,
    this.depth = 0,
  });

  final _CommentNode node;
  final Map<String, List<FeedComment>> repliesByParentID;
  final ValueChanged<FeedComment> onReply;
  final String focusCommentID;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final children =
        repliesByParentID[node.comment.id] ?? const <FeedComment>[];
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentBubble(
            comment: node.comment,
            isHighlighted: node.comment.id == focusCommentID,
            onReply: () => onReply(node.comment),
          ),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _CommentBranch(
                node: _CommentNode(child),
                repliesByParentID: repliesByParentID,
                onReply: onReply,
                focusCommentID: focusCommentID,
                depth: depth >= 4 ? 4 : depth + 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.isHighlighted,
    required this.onReply,
  });

  final FeedComment comment;
  final bool isHighlighted;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final authorName = comment.author.displayName.trim().isNotEmpty
        ? comment.author.displayName.trim()
        : comment.author.username;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surfaceSoft,
          child: Text(
            authorName.isEmpty ? 'P' : authorName.substring(0, 1).toUpperCase(),
            style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color:
                  isHighlighted ? AppColors.primarySoft : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(comment.body, style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(_timeAgo(comment.createdAt),
                        style: textTheme.bodySmall),
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

  static String _timeAgo(DateTime? createdAt) {
    if (createdAt == null) return 'Just now';
    final difference = DateTime.now().difference(createdAt.toLocal());
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}

class _CommentTree {
  const _CommentTree({
    required this.roots,
    required this.repliesByParentID,
  });

  final List<_CommentNode> roots;
  final Map<String, List<FeedComment>> repliesByParentID;

  factory _CommentTree.build(List<FeedComment> comments) {
    final roots = <_CommentNode>[];
    final repliesByParentID = <String, List<FeedComment>>{};
    final commentsByID = <String, FeedComment>{
      for (final comment in comments) comment.id: comment,
    };

    for (final comment in comments) {
      final parentID = comment.parentCommentID.trim();
      if (parentID.isEmpty || !commentsByID.containsKey(parentID)) {
        roots.add(_CommentNode(comment));
        continue;
      }
      repliesByParentID.putIfAbsent(parentID, () => <FeedComment>[]);
      repliesByParentID[parentID]!.add(comment);
    }

    return _CommentTree(roots: roots, repliesByParentID: repliesByParentID);
  }
}

class _CommentNode {
  const _CommentNode(this.comment);

  final FeedComment comment;
}

class _FeedPostImage extends StatelessWidget {
  const _FeedPostImage({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      final data = Uri.parse(imageUrl).data;
      if (data == null) return const ColoredBox(color: AppColors.surfaceSoft);
      return Image.memory(data.contentAsBytes(), fit: BoxFit.cover);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return const ColoredBox(color: AppColors.surfaceSoft);
      },
    );
  }
}
