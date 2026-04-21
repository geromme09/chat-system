import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../data/sports_api.dart';

class SportsSelectionScreen extends StatefulWidget {
  const SportsSelectionScreen({super.key});

  @override
  State<SportsSelectionScreen> createState() => _SportsSelectionScreenState();
}

class _SportsSelectionScreenState extends State<SportsSelectionScreen> {
  static const int _pageSize = 15;

  final SportsApi _sportsApi = SportsApi();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedSports = {'Basketball'};
  final List<SportItem> _sports = <SportItem>[];

  Timer? _searchDebounce;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int? _nextPage;

  @override
  void initState() {
    super.initState();
    _fetchSports();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSports({bool loadMore = false}) async {
    if (loadMore && (_isLoadingMore || _nextPage == null)) {
      return;
    }

    setState(() {
      _errorMessage = null;
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isInitialLoading = true;
      }
    });

    try {
      final page = await _sportsApi.listSports(
        query: _searchController.text,
        page: loadMore ? _nextPage! : 1,
        limit: _pageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (loadMore) {
          _sports.addAll(page.items);
        } else {
          _sports
            ..clear()
            ..addAll(page.items);
        }
        _nextPage = page.nextPage;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Could not load sports from the server. Check that the API is running and reachable from the simulator.';
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandShell(
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        children: [
          Text('Choose the sports you actually play', style: textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'The backend now supports a paged sports catalog. This onboarding page mirrors that flow: show a default set first, search fast, and only load more when needed.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppTheme.slate,
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search sports',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 350),
                      () => _fetchSports(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_isInitialLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () {
                          _fetchSports();
                        },
                        child: const Text('Try again'),
                      ),
                    ],
                  )
                else if (_sports.isEmpty)
                  Text(
                    'No sports matched your search yet.',
                    style: textTheme.bodyMedium?.copyWith(color: AppTheme.slate),
                  )
                else ...[
                  Text(
                    'Showing ${_sports.length} sports${_nextPage != null ? ' so far' : ''}',
                    style: textTheme.bodyMedium?.copyWith(color: AppTheme.slate),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _sports.map((sport) {
                      final selected = _selectedSports.contains(sport.name);
                      return FilterChip(
                        label: Text(sport.name),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedSports.add(sport.name);
                            } else {
                              _selectedSports.remove(sport.name);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (_nextPage != null && _errorMessage == null && !_isInitialLoading) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _isLoadingMore
                        ? null
                        : () {
                            _fetchSports(loadMore: true);
                          },
                    child: Text(_isLoadingMore ? 'Loading more...' : 'Load 15 more'),
                  ),
                ],
                if (_searchController.text.trim().isNotEmpty &&
                    _sports.isNotEmpty &&
                    !_isInitialLoading) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                      });
                      _fetchSports();
                    },
                    child: const Text('Clear search'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected sports', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                if (_selectedSports.isEmpty)
                  Text(
                    'Pick at least one sport so the first profile card feels relevant.',
                    style: textTheme.bodyMedium?.copyWith(color: AppTheme.slate),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _selectedSports
                        .map(
                          (sport) => Chip(
                            label: Text(sport),
                            backgroundColor: AppTheme.paper,
                            side: const BorderSide(color: AppTheme.line),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _selectedSports.isEmpty
                ? null
                : () => Navigator.of(context).pushNamed(
                      AppRoute.profileSetup.path,
                      arguments: _selectedSports.toList()..sort(),
                    ),
            child: const Text('Continue to profile setup'),
          ),
        ],
      ),
    );
  }
}
