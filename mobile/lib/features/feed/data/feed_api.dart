import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class FeedPostAuthor {
  const FeedPostAuthor({
    required this.userID,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
    required this.connectionStatus,
  });

  final String userID;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;
  final String connectionStatus;

  factory FeedPostAuthor.fromJson(Map<String, dynamic> json) {
    return FeedPostAuthor(
      userID: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      city: json['city'] as String? ?? '',
      connectionStatus: json['connection_status'] as String? ?? '',
    );
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.author,
    required this.type,
    required this.caption,
    required this.imageUrl,
    required this.reactionCount,
    required this.commentCount,
    required this.reactedByMe,
    required this.createdAt,
  });

  final String id;
  final FeedPostAuthor author;
  final String type;
  final String caption;
  final String imageUrl;
  final int reactionCount;
  final int commentCount;
  final bool reactedByMe;
  final DateTime? createdAt;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as String? ?? '',
      author: FeedPostAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? const {},
      ),
      type: json['type'] as String? ?? 'text',
      caption: json['caption'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      reactedByMe: json['reacted_by_me'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  FeedPost copyWith({
    int? reactionCount,
    int? commentCount,
    bool? reactedByMe,
  }) {
    return FeedPost(
      id: id,
      author: author,
      type: type,
      caption: caption,
      imageUrl: imageUrl,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      reactedByMe: reactedByMe ?? this.reactedByMe,
      createdAt: createdAt,
    );
  }
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.postID,
    required this.parentCommentID,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postID;
  final String parentCommentID;
  final FeedPostAuthor author;
  final String body;
  final DateTime? createdAt;

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    return FeedComment(
      id: json['id'] as String? ?? '',
      postID: json['post_id'] as String? ?? '',
      parentCommentID: json['parent_comment_id'] as String? ?? '',
      author: FeedPostAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? const {},
      ),
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class CreateFeedPostRequest {
  const CreateFeedPostRequest({
    required this.caption,
    this.imageDataUrl = '',
  });

  final String caption;
  final String imageDataUrl;

  Map<String, dynamic> toJson() {
    return {
      'caption': caption,
      'image_data_url': imageDataUrl,
    };
  }
}

class CreateFeedCommentRequest {
  const CreateFeedCommentRequest({
    required this.body,
    this.parentCommentID = '',
  });

  final String body;
  final String parentCommentID;

  Map<String, dynamic> toJson() {
    return {
      'body': body,
      'parent_comment_id': parentCommentID,
    };
  }
}

class FeedPostPage {
  const FeedPostPage({
    required this.items,
    required this.nextCursor,
  });

  final List<FeedPost> items;
  final String nextCursor;

  bool get hasMore => nextCursor.trim().isNotEmpty;

  factory FeedPostPage.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing feed payload');
    }

    final items = data['items'];
    if (items is! List<dynamic>) {
      throw const FormatException('Missing feed items payload');
    }

    return FeedPostPage(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(FeedPost.fromJson)
          .toList(),
      nextCursor: data['next_cursor'] as String? ?? '',
    );
  }
}

class FeedApi {
  FeedApi({
    ApiClient? client,
  }) : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  Future<FeedPostPage> listPosts({
    required String token,
    int limit = 20,
    String cursor = '',
    String authorUserID = '',
  }) async {
    final queryParameters = <String, String>{
      'limit': limit.toString(),
    };
    if (cursor.trim().isNotEmpty) {
      queryParameters['cursor'] = cursor.trim();
    }
    if (authorUserID.trim().isNotEmpty) {
      queryParameters['author_user_id'] = authorUserID.trim();
    }

    final response = await _client.get(
      '/api/v1/feed',
      authToken: token,
      queryParameters: queryParameters,
    );

    return FeedPostPage.fromEnvelope(response);
  }

  Future<FeedPost> createPost({
    required String token,
    required CreateFeedPostRequest request,
  }) async {
    final response = await _client.post(
      '/api/v1/feed',
      authToken: token,
      body: request.toJson(),
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing feed post payload');
    }

    return FeedPost.fromJson(data);
  }

  Future<FeedPost> toggleReaction({
    required String token,
    required String postID,
  }) async {
    final response = await _client.post(
      '/api/v1/feed/$postID/react',
      authToken: token,
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing feed post payload');
    }

    return FeedPost.fromJson(data);
  }

  Future<FeedPost> getPost({
    required String token,
    required String postID,
  }) async {
    final response = await _client.get(
      '/api/v1/feed/$postID',
      authToken: token,
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing feed post payload');
    }

    return FeedPost.fromJson(data);
  }

  Future<List<FeedComment>> listComments({
    required String token,
    required String postID,
    int limit = 20,
  }) async {
    final response = await _client.get(
      '/api/v1/feed/$postID/comments',
      authToken: token,
      queryParameters: <String, String>{'limit': limit.toString()},
    );

    final data = response['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Missing comments payload');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedComment.fromJson)
        .toList();
  }

  Future<FeedComment> createComment({
    required String token,
    required String postID,
    required CreateFeedCommentRequest request,
  }) async {
    final response = await _client.post(
      '/api/v1/feed/$postID/comments',
      authToken: token,
      body: request.toJson(),
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing comment payload');
    }

    return FeedComment.fromJson(data);
  }
}
