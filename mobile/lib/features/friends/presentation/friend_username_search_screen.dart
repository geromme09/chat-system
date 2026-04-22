import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../data/friend_search_api.dart';
import 'friend_search_profile_screen.dart';

class FriendUsernameSearchScreen extends StatefulWidget {
  const FriendUsernameSearchScreen({
    super.key,
    this.initialQuery = '',
  });

  final String initialQuery;

  @override
  State<FriendUsernameSearchScreen> createState() =>
      _FriendUsernameSearchScreenState();
}

class _FriendUsernameSearchScreenState
    extends State<FriendUsernameSearchScreen> {
  final FriendSearchApi _friendSearchApi = FriendSearchApi();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<FriendSearchResult> _results = <FriendSearchResult>[];

  Timer? _searchDebounce;
  bool _isSearching = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _message = 'Type at least 2 characters to search usernames.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
      if (widget.initialQuery.trim().length >= 2) {
        _runSearch(widget.initialQuery);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String rawQuery) async {
    final token = appSession.token;
    final query = rawQuery.trim().toLowerCase();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _results.clear();
        _isSearching = false;
        _message = 'Type at least 2 characters to search usernames.';
      });
      return;
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results.clear();
        _isSearching = false;
        _message = 'Please sign in again to search for friends.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _message = null;
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
        _message = results.isEmpty ? 'No players found for "$query".' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results.clear();
        _message = 'Unable to search right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(value),
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    if (!mounted) return;
    setState(() {
      _results.clear();
      _isSearching = false;
      _message = 'Type at least 2 characters to search usernames.';
    });
  }

  Future<void> _submitSearch(String value) async {
    await _runSearch(value);
    _clearSearch();
  }

  Future<void> _openProfile(FriendSearchResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendSearchProfileScreen(result: result),
      ),
    );
    _clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: _scheduleSearch,
                      onSubmitted: _submitSearch,
                      decoration: InputDecoration(
                        hintText: 'Search by username',
                        prefixIcon: const Icon(Icons.search_rounded),
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: [
                  Text(
                    'Add by username',
                    style: textTheme.headlineMedium?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Search results first, then open a profile to add a friend.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_message != null)
                    _SearchMessageCard(message: _message!)
                  else
                    Column(
                      children: [
                        for (final result in _results) ...[
                          _SearchResultRow(
                            result: result,
                            onTap: () => _openProfile(result),
                          ),
                          if (result != _results.last)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMessageCard extends StatelessWidget {
  const _SearchMessageCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.result,
    required this.onTap,
  });

  final FriendSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = result.displayName.trim().isEmpty
        ? result.username
        : result.displayName.trim();
    final subtitle =
        result.city.trim().isEmpty ? '@${result.username}' : result.city.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  title.characters.first.toUpperCase(),
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
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
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _statusLabel(result.connectionStatus),
                style: textTheme.bodyMedium?.copyWith(
                  color: result.connectionStatus == FriendConnectionStatus.add
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
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

  static String _statusLabel(String status) {
    switch (status) {
      case FriendConnectionStatus.friends:
        return 'Friends';
      case FriendConnectionStatus.requested:
        return 'Requested';
      case FriendConnectionStatus.incomingRequest:
        return 'Respond';
      default:
        return 'View';
    }
  }
}
