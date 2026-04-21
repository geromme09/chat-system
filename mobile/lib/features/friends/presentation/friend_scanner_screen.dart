import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../data/friends_api.dart';
import '../data/friend_search_api.dart';

class FriendScannerScreen extends StatefulWidget {
  const FriendScannerScreen({super.key});

  @override
  State<FriendScannerScreen> createState() => _FriendScannerScreenState();
}

class _FriendScannerScreenState extends State<FriendScannerScreen> {
  final FriendSearchApi _friendSearchApi = FriendSearchApi();
  final FriendsApi _friendsApi = FriendsApi();
  final TextEditingController _searchController = TextEditingController();

  final List<FriendSearchResult> _results = <FriendSearchResult>[];
  final List<FriendRequestRecord> _incomingRequests = <FriendRequestRecord>[];
  Timer? _searchDebounce;
  bool _isSearching = false;
  bool _isLoadingRequests = true;
  String? _searchMessage;
  String? _requestMessage;

  @override
  void initState() {
    super.initState();
    _loadIncomingRequests();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openChats() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoute.chatHome.path,
      (_) => false,
    );
  }

  Future<void> _loadIncomingRequests() async {
    final token = appSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingRequests = false;
        _requestMessage = 'Please sign in again to load friend requests.';
      });
      return;
    }

    setState(() {
      _isLoadingRequests = true;
      _requestMessage = null;
    });

    try {
      final requests = await _friendsApi.listIncomingRequests(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _incomingRequests
          ..clear()
          ..addAll(requests);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _requestMessage = 'Unable to load friend requests right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(FriendSearchResult result) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) return;

    try {
      await _friendsApi.sendFriendRequest(
        token: token,
        targetUserID: result.userID,
      );

      if (mounted) {
        setState(() {
          final index =
              _results.indexWhere((item) => item.userID == result.userID);
          if (index >= 0) {
            _results[index] = FriendSearchResult(
              userID: result.userID,
              username: result.username,
              displayName: result.displayName,
              avatarUrl: result.avatarUrl,
              city: result.city,
              connectionStatus: FriendConnectionStatus.requested,
            );
          }
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to @${result.username}.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('HttpException: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _respondToRequest(
    FriendRequestRecord request,
    String action,
  ) async {
    final token = appSession.token;
    if (token == null || token.isEmpty) return;

    try {
      await _friendsApi.respondToRequest(
        token: token,
        requestID: request.id,
        action: action,
      );
      await _loadIncomingRequests();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'accept'
                ? 'You are now connected with @${request.requester.username}.'
                : 'Friend request declined.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('HttpException: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _runSearch(String rawQuery) async {
    final token = appSession.token;
    final query = rawQuery.trim().toLowerCase();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _results.clear();
        _isSearching = false;
        _searchMessage = 'Type at least 2 characters to search usernames.';
      });
      return;
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results.clear();
        _isSearching = false;
        _searchMessage = 'Please sign in again to search for friends.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchMessage = null;
    });

    try {
      final results = await _friendSearchApi.searchUsers(
        token: token,
        query: query,
      );

      if (!mounted) return;

      setState(() {
        _results
          ..clear()
          ..addAll(results);
        _searchMessage =
            results.isEmpty ? 'No players found for "$query".' : null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _results.clear();
        _searchMessage = 'Unable to search right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandShell(
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Scan and add friends',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Build your trusted circle first, then we can open the chat flow on top of it.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ScannerPreviewCard(),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friend requests',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isLoadingRequests)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_requestMessage != null)
                  Text(
                    _requestMessage!,
                    style: textTheme.bodyMedium,
                  )
                else if (_incomingRequests.isEmpty)
                  Text(
                    'No pending friend requests yet.',
                    style: textTheme.bodyMedium,
                  )
                else
                  Column(
                    children: _incomingRequests
                        .map(
                          (request) => Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.sm,
                            ),
                            child: _IncomingRequestTile(
                              request: request,
                              onAccept: () =>
                                  _respondToRequest(request, 'accept'),
                              onDecline: () =>
                                  _respondToRequest(request, 'decline'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find by username',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Search by username to add a friend. We start searching after 2 characters with a short debounce.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Username search',
                    hintText: 'Search like ge',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 350),
                      () => _runSearch(value),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_isSearching)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_searchMessage != null)
                  Text(
                    _searchMessage!,
                    style: textTheme.bodyMedium,
                  )
                else if (_results.isNotEmpty)
                  Column(
                    children: _results
                        .map(
                          (result) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _SearchResultTile(
                              result: result,
                              onAdd: () => _sendFriendRequest(result),
                            ),
                          ),
                        )
                        .toList(),
                  )
                else
                  Text(
                    'Search results will appear here.',
                    style: textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: _openChats,
            child: const Text('Skip for now'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _openChats,
            child: const Text('Continue to chats'),
          ),
        ],
      ),
    );
  }
}

class _ScannerPreviewCard extends StatelessWidget {
  const _ScannerPreviewCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scanner preview',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF111827),
                  Color(0xFF1F2937),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 188,
                  height: 188,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.accentStrong,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: const [
                      _ScanCorner(alignment: Alignment.topLeft),
                      _ScanCorner(alignment: Alignment.topRight),
                      _ScanCorner(alignment: Alignment.bottomLeft),
                      _ScanCorner(alignment: Alignment.bottomRight),
                    ],
                  ),
                ),
                Positioned(
                  bottom: AppSpacing.lg,
                  child: Text(
                    'Point your camera at a friend QR code',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({
    required this.alignment,
  });

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(
                    color: AppColors.accentStrong,
                    width: 4,
                  )
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(
                    color: AppColors.accentStrong,
                    width: 4,
                  )
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(
                    color: AppColors.accentStrong,
                    width: 4,
                  )
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(
                    color: AppColors.accentStrong,
                    width: 4,
                  )
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.onAdd,
  });

  final FriendSearchResult result;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buttonLabel = switch (result.connectionStatus) {
      FriendConnectionStatus.requested => 'Requested',
      FriendConnectionStatus.incomingRequest => 'Respond',
      FriendConnectionStatus.friends => 'Friends',
      _ => 'Add',
    };
    final isAddable = result.connectionStatus == FriendConnectionStatus.add;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.displayName.isEmpty
                      ? result.username
                      : result.displayName,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '@${result.username}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (result.city.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(result.city, style: textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: isAddable ? onAdd : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestTile extends StatelessWidget {
  const _IncomingRequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequestRecord request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requester.displayName.isEmpty
                          ? request.requester.username
                          : request.requester.displayName,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '@${request.requester.username}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
