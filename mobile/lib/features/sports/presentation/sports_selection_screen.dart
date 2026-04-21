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
    if (loadMore && (_isLoadingMore || _nextPage == null)) return;

    setState(() {
      _errorMessage = null;
      loadMore ? _isLoadingMore = true : _isInitialLoading = true;
    });

    try {
      final page = await _sportsApi.listSports(
        query: _searchController.text,
        page: loadMore ? _nextPage! : 1,
        limit: _pageSize,
      );

      if (!mounted) return;

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
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to load sports. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
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
          /// HEADER
          Text(
            'Choose your sports',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pick the sports you actually play.',
            style: textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.lg),

          /// SEARCH + RESULTS
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

                const SizedBox(height: AppSpacing.md),

                /// STATES
                if (_isInitialLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
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
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: _fetchSports,
                        child: const Text('Try again'),
                      ),
                    ],
                  )
                else if (_sports.isEmpty)
                  Text(
                    'No sports found.',
                    style: textTheme.bodyMedium,
                  )
                else ...[
                  Text(
                    'Available sports',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  /// CUSTOM CHIPS (replaces FilterChip)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _sports.map((sport) {
                      final selected = _selectedSports.contains(sport.name);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selected
                                ? _selectedSports.remove(sport.name)
                                : _selectedSports.add(sport.name);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            sport.name,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                if (_nextPage != null &&
                    !_isInitialLoading &&
                    _errorMessage == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: _isLoadingMore
                        ? null
                        : () => _fetchSports(loadMore: true),
                    child: Text(
                      _isLoadingMore ? 'Loading...' : 'Load more',
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          /// SELECTED SPORTS
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_selectedSports.isEmpty)
                  Text(
                    'Pick at least one sport.',
                    style: textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _selectedSports.map((sport) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Text(sport),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          /// CTA
          FilledButton(
            onPressed: _selectedSports.isEmpty
                ? null
                : () => Navigator.of(context).pushNamed(
                      AppRoute.profileSetup.path,
                      arguments: _selectedSports.toList()..sort(),
                    ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
