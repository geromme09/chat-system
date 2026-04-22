import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../chat/data/chat_unread_controller.dart';

class ProfileHomeScreen extends StatefulWidget {
  const ProfileHomeScreen({super.key});

  @override
  State<ProfileHomeScreen> createState() => _ProfileHomeScreenState();
}

class _ProfileHomeScreenState extends State<ProfileHomeScreen> {
  String get _currentStatus {
    final savedStatus = appSession.customStatus?.trim() ?? '';
    if (savedStatus.isNotEmpty) {
      return savedStatus;
    }

    return 'Looking for games this weekend!';
  }

  Future<void> _editStatus() async {
    final controller = TextEditingController(text: _currentStatus);
    final nextStatus = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update status',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Share what kind of game you are up for right now.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  maxLength: 60,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    hintText: 'Looking for games this weekend!',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(controller.text.trim());
                  },
                  child: const Text('Save status'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (nextStatus == null || nextStatus.trim().isEmpty) {
      return;
    }

    setState(() {
      appSession.updateCustomStatus(nextStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = appSession.profile;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            _ProfileHero(
              displayName: _displayName(profile),
              location: _locationLabel(profile),
              status: _currentStatus,
              onEditStatus: _editStatus,
              onOpenSettings: () {
                Navigator.of(context).pushNamed(
                  AppRoute.profileSetup.path,
                  arguments: profile?.sports ?? const <String>[],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              child: _ProfileSection(
                icon: Icons.info_outline_rounded,
                title: 'About',
                action: IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoute.profileSetup.path,
                      arguments: profile?.sports ?? const <String>[],
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceSoft,
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
                child: Text(
                  _valueOrFallback(
                    profile?.bio,
                    fallback:
                        'Add a short intro so people know how you like to play.',
                  ),
                  style: textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              child: _ProfileSection(
                icon: Icons.sports_basketball_rounded,
                title: 'Sports',
                action: IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoute.profileSetup.path,
                      arguments: profile?.sports ?? const <String>[],
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceSoft,
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
                child: profile == null || profile.sports.isEmpty
                    ? Text(
                        'No sports selected yet.',
                        style: textTheme.bodyMedium,
                      )
                    : Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: profile.sports
                            .map(
                              (sport) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: _sportColor(sport)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  sport,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: _sportColor(sport),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoute.profileSetup.path,
                  arguments: profile?.sports ?? const <String>[],
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                appSession.clear();
                chatUnreadController.clear();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoute.welcome.path,
                  (_) => false,
                );
              },
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE15241),
              ),
              label: const Text(
                'Log out',
                style: TextStyle(color: Color(0xFFE15241)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _displayName(SessionProfile? profile) {
    return _valueOrFallback(profile?.displayName, fallback: 'Player');
  }

  static String _valueOrFallback(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String _locationLabel(SessionProfile? profile) {
    if (profile == null) {
      return 'Complete your profile';
    }

    final parts = <String>[
      if (profile.city.trim().isNotEmpty) profile.city.trim(),
      if (profile.country.trim().isNotEmpty) profile.country.trim(),
    ];

    return parts.isEmpty ? 'Location not set' : parts.join(', ');
  }

  static Color _sportColor(String sport) {
    final normalized = sport.toLowerCase();
    if (normalized.contains('basket')) {
      return AppColors.primary;
    }
    if (normalized.contains('soccer') || normalized.contains('football')) {
      return const Color(0xFFFF8A00);
    }
    if (normalized.contains('run')) {
      return const Color(0xFF2383E2);
    }
    return const Color(0xFF2CA56D);
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.location,
    required this.status,
    required this.onEditStatus,
    required this.onOpenSettings,
  });

  final String displayName;
  final String location;
  final String status;
  final VoidCallback onEditStatus;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              72,
            ),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7D75F7),
                  Color(0xFF545AF2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -60),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD9D7FF),
                        border: Border.all(
                          color: Colors.white,
                          width: 5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        displayName.characters.first.toUpperCase(),
                        style: textTheme.displaySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF44B96B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    children: [
                      Text(
                        displayName,
                        style: textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              location,
                              style: textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3FAF5),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFE3F2E7),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF59C17A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                status,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFF43506D),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onEditStatus,
                              icon: const Icon(Icons.edit_outlined),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.child,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: textTheme.titleLarge,
            ),
            const Spacer(),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
