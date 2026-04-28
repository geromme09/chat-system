import 'package:flutter/material.dart';

import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/section_card.dart';
import '../../friends/data/friend_search_api.dart';
import '../../friends/presentation/friend_search_profile_screen.dart';
import '../../home/presentation/home_shell_screen.dart';
import '../data/feed_api.dart';
import 'comment_widgets.dart';

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
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  FeedPost? _post;
  List<FeedComment> _comments = const <FeedComment>[];
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  bool _isReacting = false;
  CommentReplyTarget? _replyTarget;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
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
      final updated = post.reactedByMe
          ? await _feedApi.unlikePost(token: token, postID: post.id)
          : await _feedApi.likePost(token: token, postID: post.id);
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
    final replyTarget = _replyTarget;
    final rawBody = _commentController.text.trim();
    final body = _bodyWithMention(rawBody, replyTarget);
    if (token == null ||
        token.isEmpty ||
        post == null ||
        rawBody.isEmpty ||
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
          parentCommentID: replyTarget?.parentCommentID ?? '',
        ),
      );
      if (!mounted) return;
      setState(() {
        _comments = <FeedComment>[..._comments, comment];
        _post = post.copyWith(commentCount: post.commentCount + 1);
        _commentController.clear();
        _replyTarget = null;
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

  void _replyTo(CommentReplyTarget target) {
    setState(() => _replyTarget = target);
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  String _bodyWithMention(String body, CommentReplyTarget? target) {
    if (target == null || !target.shouldPrefixMention) return body;
    final username = target.targetUsername.replaceFirst('@', '').trim();
    if (username.isEmpty || body.startsWith('@$username')) return body;
    return '@$username $body';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadPost,
          child: ListView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
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
                  isReacting: _isReacting,
                  onOpenAuthorProfile: () => _openAuthorProfile(post.author),
                  onReact: _toggleReaction,
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _CommentsSection(
                    comments: _comments,
                    focusCommentID: widget.focusCommentID,
                    onReply: _replyTo,
                  ),
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
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTarget != null)
              ReplyContextBar(
                username: _replyTarget!.targetUsername,
                onCancel: _cancelReply,
              ),
            CommentInputBar(
              controller: _commentController,
              focusNode: _commentFocusNode,
              isSubmitting: _isSubmittingComment,
              replyingToUsername: _replyTarget?.targetUsername ?? '',
              onSubmit: _submitComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isReacting,
    required this.onOpenAuthorProfile,
    required this.onReact,
  });

  final FeedPost post;
  final bool isReacting;
  final VoidCallback onOpenAuthorProfile;
  final VoidCallback onReact;

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
                AppAvatar(
                  size: 44,
                  imageUrl: post.author.avatarUrl,
                  iconSize: 20,
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

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.focusCommentID,
    required this.onReply,
  });

  final List<FeedComment> comments;
  final String focusCommentID;
  final ValueChanged<CommentReplyTarget> onReply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comments.isEmpty)
          Text(
            'No comments yet. Start the conversation.',
            style: textTheme.bodyMedium,
          )
        else
          CommentList(
            comments: comments,
            focusCommentID: focusCommentID,
            onReply: onReply,
          ),
      ],
    );
  }
}

class _FeedPostImage extends StatelessWidget {
  const _FeedPostImage({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return AppPostImage(imageUrl: imageUrl);
  }
}
