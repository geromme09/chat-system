import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/chat_constants.dart';
import '../../chat/data/chat_realtime_client.dart';
import '../../chat/data/chat_unread_controller.dart';
import '../../chat/presentation/chat_conversation_screen.dart';
import '../../friends/data/friend_search_api.dart';
import '../../friends/data/friends_api.dart';
import '../../friends/presentation/friend_request_profile_screen.dart';
import '../../friends/presentation/friend_search_profile_screen.dart';
import '../../friends/presentation/notifications_screen.dart';
import '../../home/presentation/home_shell_screen.dart';
import '../data/feed_api.dart';
import 'post_detail_screen.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final FeedApi _feedApi = FeedApi();
  final FriendsApi _friendsApi = FriendsApi();
  final ChatApi _chatApi = ChatApi();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<FeedPost> _posts = const <FeedPost>[];
  final List<FriendNotificationRecord> _notifications =
      <FriendNotificationRecord>[];
  final Map<String, List<FeedComment>> _commentsByPostID =
      <String, List<FeedComment>>{};
  final Set<String> _expandedCommentPostIDs = <String>{};
  final Set<String> _loadingCommentPostIDs = <String>{};
  final Set<String> _submittingCommentPostIDs = <String>{};
  final Set<String> _reactingPostIDs = <String>{};
  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  StreamSubscription<ChatRealtimeStatus>? _statusSubscription;
  XFile? _selectedImage;
  String _nextCursor = '';
  int? _nextNotificationsPage;
  bool _isComposerExpanded = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingNotifications = false;
  bool _isLoadingMoreNotifications = false;
  bool _isSubmitting = false;
  String? _message;
  String? _notificationsMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadPosts();
    _loadNotifications();
    _connectRealtime();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _realtimeSubscription?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _composerFocusNode.dispose();
    _composerController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _message = 'Please sign in again to load your feed.';
      });
      return;
    }
    if (loadMore && (_isLoadingMore || _nextCursor.isEmpty)) {
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
      _message = null;
    });

    try {
      final page = await _feedApi.listPosts(
        token: token,
        cursor: loadMore ? _nextCursor : '',
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
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || _isLoading) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      _loadPosts(loadMore: true);
    }
  }

  Future<void> _connectRealtime() async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    await _statusSubscription?.cancel();
    _statusSubscription = ChatRealtimeClient.instance.statuses.listen((status) {
      if (status == ChatRealtimeStatus.connected) {
        _loadNotifications();
        chatUnreadController.refresh();
      }
    });

    try {
      await ChatRealtimeClient.instance.connect(token);
      await _realtimeSubscription?.cancel();
      _realtimeSubscription =
          ChatRealtimeClient.instance.events.listen((event) {
        if (!mounted) return;
        if (event.event == ChatRealtimeEvents.notificationCreated) {
          final rawNotification = event.notification;
          if (rawNotification != null) {
            try {
              final notification =
                  FriendNotificationRecord.fromJson(rawNotification);
              _upsertNotification(notification);
            } catch (_) {
              // Fall back to a full refresh if the payload shape changes.
            }
          }
          _loadNotifications();
          return;
        }
        if (event.event == ChatRealtimeEvents.messageCreated) {
          chatUnreadController.refresh();
        }
      });
    } catch (_) {
      // Realtime is optional; feed still works over HTTP.
    }
  }

  Future<void> _loadNotifications({bool loadMore = false}) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
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
        limit: 15,
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

  void _upsertNotification(FriendNotificationRecord notification) {
    setState(() {
      final index =
          _notifications.indexWhere((item) => item.id == notification.id);
      if (index >= 0) {
        _notifications[index] = notification;
      } else {
        _notifications.insert(0, notification);
      }
    });
  }

  Future<void> _markNotificationRead(String notificationID) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final readAt = DateTime.now();
    try {
      await _friendsApi.markNotificationRead(
        token: token,
        notificationID: notificationID,
      );
      if (!mounted) return;
      setState(() {
        for (var index = 0; index < _notifications.length; index++) {
          final current = _notifications[index];
          if (current.id == notificationID && current.readAt == null) {
            _notifications[index] = current.copyWith(readAt: readAt);
            break;
          }
        }
      });
    } catch (_) {
      // Keep local notification state if the mark-read call fails.
    }
  }

  Future<void> _openNotification(FriendNotificationRecord notification) async {
    await _markNotificationRead(notification.id);

    if (notification.isFeedInteraction) {
      await _openFeedInteractionNotification(notification);
      return;
    }

    await _openFriendRequestNotification(notification);
  }

  Future<void> _openFeedInteractionNotification(
    FriendNotificationRecord notification,
  ) async {
    final feedInteraction = notification.feedInteraction;
    if (feedInteraction == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(
          postID: feedInteraction.postID,
          focusCommentID: feedInteraction.commentID,
        ),
      ),
    );
  }

  Future<void> _openFriendRequestNotification(
    FriendNotificationRecord notification,
  ) async {
    final request = notification.friendRequest;
    if (request == null) {
      return;
    }

    final isIncomingRequest = notification.type == 'friend_request_received';
    final peer = isIncomingRequest ? request.requester : request.addressee;
    final title = _friendSummaryTitle(peer);
    final showChatButton =
        notification.isAcceptedRequest || request.status == 'accepted';

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendRequestProfileScreen(
          request: request,
          title: title,
          isIncomingRequest: isIncomingRequest,
          showChatButton: showChatButton,
          onAcceptRequest: () => _respondToRequest(request, 'accept'),
          onDeclineRequest: () => _respondToRequest(request, 'decline'),
          onOpenChat: () => _openChatWithUser(
            userID: peer.userID,
            title: title,
            subtitle: _friendSummarySubtitle(peer),
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
      await _loadNotifications();
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

  Future<void> _openChatWithUser({
    required String userID,
    required String title,
    required String subtitle,
  }) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final conversation = await _chatApi.createConversation(
        token: token,
        request: CreateConversationRequest(
          participantIDs: [userID],
        ),
      );
      await chatUnreadController.refresh();
      if (!mounted) return;

      await Navigator.of(context).pushNamed(
        AppRoute.chatConversation.path,
        arguments: ChatConversationArgs(
          conversationID: conversation.id,
          title: title,
          participantUserID: userID,
          subtitle: subtitle,
        ),
      );

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

  Future<void> _pickImage(ImageSource source) async {
    _expandComposer();

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = image;
        _message = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = source == ImageSource.camera
            ? 'Unable to open the camera right now.'
            : 'Unable to open the gallery right now.';
      });
    }
  }

  Future<void> _submitPost() async {
    final caption = _composerController.text.trim();
    if (_isSubmitting) return;

    if (caption.isEmpty) {
      setState(() {
        _message = _selectedImage == null
            ? 'Write something to post.'
            : 'Add a caption for your image post.';
      });
      _composerFocusNode.requestFocus();
      return;
    }

    final token = appSession.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _message = 'Please sign in again to create a post.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final imageDataUrl =
          _selectedImage == null ? '' : await _toImageDataUrl(_selectedImage!);
      final createdPost = await _feedApi.createPost(
        token: token,
        request: CreateFeedPostRequest(
          caption: caption,
          imageDataUrl: imageDataUrl,
        ),
      );

      if (!mounted) return;
      setState(() {
        _posts = <FeedPost>[createdPost, ..._posts];
        _composerController.clear();
        _selectedImage = null;
        _isComposerExpanded = false;
      });
      _composerFocusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted to your feed')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String> _toImageDataUrl(XFile file) async {
    final bytes = await File(file.path).readAsBytes();
    final mimeType = switch (_extensionFor(file.name)) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  void _expandComposer() {
    if (_isComposerExpanded) return;
    setState(() {
      _isComposerExpanded = true;
    });
  }

  void _collapseComposerIfEmpty() {
    if (_composerController.text.trim().isNotEmpty || _selectedImage != null) {
      return;
    }

    _composerFocusNode.unfocus();
    setState(() {
      _isComposerExpanded = false;
      _message = null;
    });
  }

  static String _extensionFor(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
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

  String _friendSummaryTitle(FriendSummary friend) {
    final displayName = friend.displayName.trim();
    return displayName.isEmpty ? friend.username : displayName;
  }

  String _friendSummarySubtitle(FriendSummary friend) {
    final city = friend.city.trim();
    return city.isEmpty ? '@${friend.username}' : city;
  }

  Future<void> _toggleReaction(FeedPost post) async {
    final token = appSession.token;
    if (token == null || token.isEmpty || _reactingPostIDs.contains(post.id)) {
      return;
    }

    setState(() {
      _reactingPostIDs.add(post.id);
      _posts = _posts.map((item) {
        if (item.id != post.id) return item;
        final nextReacted = !item.reactedByMe;
        return item.copyWith(
          reactedByMe: nextReacted,
          reactionCount: item.reactionCount + (nextReacted ? 1 : -1),
        );
      }).toList();
    });

    try {
      final updatedPost = await _feedApi.toggleReaction(
        token: token,
        postID: post.id,
      );
      if (!mounted) return;
      _replacePost(updatedPost);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString().replaceFirst('HttpException: ', '');
        _posts =
            _posts.map((item) => item.id == post.id ? post : item).toList();
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
      _message = null;
    });

    try {
      final comments = await _feedApi.listComments(
        token: token,
        postID: postID,
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
      FeedPost post, String body, String parentCommentID) async {
    final token = appSession.token;
    if (token == null ||
        token.isEmpty ||
        body.trim().isEmpty ||
        _submittingCommentPostIDs.contains(post.id)) {
      return;
    }

    setState(() {
      _submittingCommentPostIDs.add(post.id);
      _message = null;
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
        _replacePostInState(
          post.copyWith(commentCount: post.commentCount + 1),
        );
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

  void _replacePost(FeedPost post) {
    setState(() {
      _replacePostInState(post);
    });
  }

  void _replacePostInState(FeedPost post) {
    _posts = _posts.map((item) => item.id == post.id ? post : item).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadPosts();
            await _loadNotifications();
            await chatUnreadController.refresh();
          },
          child: ListView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            children: [
              _FeedHeader(
                postCount: _posts.length,
                unreadNotificationCount:
                    _notifications.where((item) => item.readAt == null).length,
                isLoadingNotifications: _isLoadingNotifications,
                onOpenNotifications: _openNotifications,
              ),
              const SizedBox(height: AppSpacing.md),
              _InlineComposer(
                controller: _composerController,
                focusNode: _composerFocusNode,
                selectedImage: _selectedImage,
                isExpanded: _isComposerExpanded,
                isSubmitting: _isSubmitting,
                onTapComposer: _expandComposer,
                onCancel: _collapseComposerIfEmpty,
                onPickCamera: () => _pickImage(ImageSource.camera),
                onPickGallery: () => _pickImage(ImageSource.gallery),
                onRemoveImage: () {
                  setState(() {
                    _selectedImage = null;
                  });
                },
                onPost: _submitPost,
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Latest updates',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Fresh posts from your FaceOff Social circle.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_posts.isEmpty)
                const _EmptyFeedCard()
              else
                for (final post in _posts) ...[
                  _FeedPostCard(
                    post: post,
                    comments:
                        _commentsByPostID[post.id] ?? const <FeedComment>[],
                    commentsExpanded: _expandedCommentPostIDs.contains(post.id),
                    commentsLoading: _loadingCommentPostIDs.contains(post.id),
                    commentSubmitting:
                        _submittingCommentPostIDs.contains(post.id),
                    reactionBusy: _reactingPostIDs.contains(post.id),
                    onOpenAuthorProfile: () => _openAuthorProfile(post.author),
                    onReact: () => _toggleReaction(post),
                    onToggleComments: () => _toggleComments(post),
                    onSubmitComment: (body, parentCommentID) =>
                        _submitComment(post, body, parentCommentID),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.postCount,
    required this.unreadNotificationCount,
    required this.isLoadingNotifications,
    required this.onOpenNotifications,
  });

  final int postCount;
  final int unreadNotificationCount;
  final bool isLoadingNotifications;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feed',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                postCount == 0
                    ? 'Start the first conversation today.'
                    : '$postCount updates from your circle',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: isLoadingNotifications ? null : onOpenNotifications,
          icon: isLoadingNotifications
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Badge(
                  isLabelVisible: unreadNotificationCount > 0,
                  label: Text(
                    unreadNotificationCount > 9
                        ? '9+'
                        : '$unreadNotificationCount',
                  ),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
          color: AppColors.textSecondary,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineComposer extends StatelessWidget {
  const _InlineComposer({
    required this.controller,
    required this.focusNode,
    required this.selectedImage,
    required this.isExpanded,
    required this.isSubmitting,
    required this.onTapComposer,
    required this.onCancel,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemoveImage,
    required this.onPost,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final XFile? selectedImage;
  final bool isExpanded;
  final bool isSubmitting;
  final VoidCallback onTapComposer;
  final VoidCallback onCancel;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemoveImage;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = appSession.profile;
    final displayName = (profile?.displayName.trim().isNotEmpty ?? false)
        ? profile!.displayName.trim()
        : 'Player';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isExpanded ? AppColors.borderFocus : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft.withValues(alpha: isExpanded ? 1 : 0.5),
            blurRadius: isExpanded ? 22 : 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: isExpanded
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  _initialsFor(displayName),
                  style: textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  onTap: onTapComposer,
                  onChanged: (_) => onTapComposer(),
                  decoration: InputDecoration(
                    labelText: null,
                    hintText: isExpanded
                        ? 'Share something with your circle...'
                        : 'What’s happening, $displayName?',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isExpanded ? AppSpacing.md : AppSpacing.sm,
                      vertical: isExpanded ? AppSpacing.md : AppSpacing.sm,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSoft,
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
                      borderSide: const BorderSide(
                        color: AppColors.borderFocus,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Column(
            children: [
              if (selectedImage != null || isExpanded) ...[
                if (selectedImage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.file(
                            File(selectedImage!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: IconButton(
                          onPressed: onRemoveImage,
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.textPrimary.withValues(alpha: 0.78),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  _ComposerActionChip(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    onTap: onPickCamera,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ComposerActionChip(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: onPickGallery,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: isSubmitting ? null : onPost,
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Post'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _ComposerActionChip extends StatelessWidget {
  const _ComposerActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No posts yet',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The composer is ready when you are. Share the first update without leaving this screen.',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatefulWidget {
  const _FeedPostCard({
    required this.post,
    required this.comments,
    required this.commentsExpanded,
    required this.commentsLoading,
    required this.commentSubmitting,
    required this.reactionBusy,
    required this.onOpenAuthorProfile,
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
  final VoidCallback onOpenAuthorProfile;
  final VoidCallback onReact;
  final VoidCallback onToggleComments;
  final Future<void> Function(String body, String parentCommentID)
      onSubmitComment;

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  final TextEditingController _commentController = TextEditingController();
  String _replyingToCommentID = '';
  String _replyingToAuthorName = '';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    await widget.onSubmitComment(body, _replyingToCommentID);
    if (!mounted) return;
    _commentController.clear();
    setState(() {
      _replyingToCommentID = '';
      _replyingToAuthorName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authorName = widget.post.author.displayName.trim().isNotEmpty
        ? widget.post.author.displayName.trim()
        : widget.post.author.username;

    return SectionCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: widget.onOpenAuthorProfile,
                borderRadius: BorderRadius.circular(999),
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
                  ],
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: widget.onOpenAuthorProfile,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${widget.post.author.username} · ${_relativeTime(widget.post.createdAt)}',
                        style: textTheme.bodySmall,
                      ),
                      if (_friendBadgeLabel(
                              widget.post.author.connectionStatus) !=
                          null) ...[
                        const SizedBox(height: 6),
                        _ConnectionBadge(
                          label: _friendBadgeLabel(
                              widget.post.author.connectionStatus)!,
                          tone: _friendBadgeTone(
                            widget.post.author.connectionStatus,
                          ),
                        ),
                      ],
                    ],
                  ),
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
            widget.post.caption,
            style: textTheme.bodyLarge,
          ),
          if (widget.post.hasImage) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _FeedPostImage(imageUrl: widget.post.imageUrl),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _PostAction(
                icon: widget.post.reactedByMe
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: widget.post.reactionCount == 0
                    ? 'React'
                    : widget.post.reactionCount.toString(),
                selected: widget.post.reactedByMe,
                busy: widget.reactionBusy,
                onTap: widget.onReact,
              ),
              _PostAction(
                icon: Icons.mode_comment_outlined,
                label: widget.post.commentCount == 0
                    ? 'Comment'
                    : widget.post.commentCount.toString(),
                selected: widget.commentsExpanded,
                onTap: widget.onToggleComments,
              ),
              const _PostAction(
                icon: Icons.ios_share_rounded,
                label: 'Share',
              ),
            ],
          ),
          if (widget.commentsExpanded)
            _CommentsPanel(
              comments: widget.comments,
              isLoading: widget.commentsLoading,
              isSubmitting: widget.commentSubmitting,
              controller: _commentController,
              replyingToAuthorName: _replyingToAuthorName,
              onCancelReply: () {
                setState(() {
                  _replyingToCommentID = '';
                  _replyingToAuthorName = '';
                });
              },
              onReplyToComment: (comment) {
                final name = comment.author.displayName.trim().isNotEmpty
                    ? comment.author.displayName.trim()
                    : comment.author.username;
                setState(() {
                  _replyingToCommentID = comment.id;
                  _replyingToAuthorName = name;
                });
              },
              onSubmit: _submitComment,
            ),
        ],
      ),
    );
  }

  static String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  static String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Now';

    final difference = DateTime.now().difference(createdAt.toLocal());
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  static String? _friendBadgeLabel(String connectionStatus) {
    switch (connectionStatus) {
      case FriendConnectionStatus.requested:
        return 'Request sent';
      case FriendConnectionStatus.incomingRequest:
        return 'Sent you a request';
      case FriendConnectionStatus.add:
        return 'Not friends yet';
      default:
        return null;
    }
  }

  static _ConnectionBadgeTone _friendBadgeTone(String connectionStatus) {
    switch (connectionStatus) {
      case FriendConnectionStatus.requested:
        return _ConnectionBadgeTone.warning;
      case FriendConnectionStatus.incomingRequest:
        return _ConnectionBadgeTone.info;
      default:
        return _ConnectionBadgeTone.danger;
    }
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
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
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentsPanel extends StatelessWidget {
  const _CommentsPanel({
    required this.comments,
    required this.isLoading,
    required this.isSubmitting,
    required this.controller,
    required this.replyingToAuthorName,
    required this.onCancelReply,
    required this.onReplyToComment,
    required this.onSubmit,
  });

  final List<FeedComment> comments;
  final bool isLoading;
  final bool isSubmitting;
  final TextEditingController controller;
  final String replyingToAuthorName;
  final VoidCallback onCancelReply;
  final ValueChanged<FeedComment> onReplyToComment;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tree = _CommentTree.build(comments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (tree.roots.isEmpty)
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
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
  });

  final FeedComment comment;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authorName = comment.author.displayName.trim().isNotEmpty
        ? comment.author.displayName.trim()
        : comment.author.username;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surfaceSoft,
          child: Text(
            authorName.isEmpty ? 'P' : authorName.substring(0, 1).toUpperCase(),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
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
                Text(comment.body, style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      _relativeTime(comment.createdAt),
                      style: textTheme.bodySmall,
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

  static String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Just now';
    final difference = DateTime.now().difference(createdAt.toLocal());
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}

class _CommentBranch extends StatelessWidget {
  const _CommentBranch({
    required this.node,
    required this.repliesByParentID,
    required this.onReply,
    this.depth = 0,
  });

  final _CommentNode node;
  final Map<String, List<FeedComment>> repliesByParentID;
  final ValueChanged<FeedComment> onReply;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final replies = repliesByParentID[node.comment.id] ?? const <FeedComment>[];

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTile(
            comment: node.comment,
            onReply: () => onReply(node.comment),
          ),
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _CommentBranch(
                node: _CommentNode(reply),
                repliesByParentID: repliesByParentID,
                onReply: onReply,
                depth: depth >= 4 ? 4 : depth + 1,
              ),
            ),
        ],
      ),
    );
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

enum _ConnectionBadgeTone { info, warning, danger }

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.label,
    required this.tone,
  });

  final String label;
  final _ConnectionBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      _ConnectionBadgeTone.info => (
          const Color(0xFFEEF2FF),
          const Color(0xFF4F46E5),
        ),
      _ConnectionBadgeTone.warning => (
          const Color(0xFFFFF4E6),
          const Color(0xFFD97706),
        ),
      _ConnectionBadgeTone.danger => (
          const Color(0xFFFFF1F0),
          const Color(0xFFE15241),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.$2,
              fontWeight: FontWeight.w700,
            ),
      ),
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
