import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BrandShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.ink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.sports_basketball_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text(
                'Play Circle',
                style: textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Find your people.\nPlay outside.\nKeep score later.',
            style: textTheme.displaySmall,
          ),
          const SizedBox(height: 18),
          Text(
            'A social sports app for meeting players, adding friends, and building real matchups without making the whole thing feel like a dating app.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppTheme.slate,
            ),
          ),
          const SizedBox(height: 28),
          const _SportStrip(),
          const SizedBox(height: 28),
          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ValueRow(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Add friends with QR',
                  subtitle: 'Bring your actual circle into the app without discovery.',
                ),
                SizedBox(height: 18),
                _ValueRow(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Start with chat',
                  subtitle: 'Get the MVP strong on messaging before layering matches.',
                ),
                SizedBox(height: 18),
                _ValueRow(
                  icon: Icons.emoji_events_rounded,
                  title: 'Grow into challenges',
                  subtitle: 'Later, turn real games into posts, winners, and rank points.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoute.signUp.path),
            child: const Text('Create your account'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoute.login.path),
            child: const Text('I already have an account'),
          ),
        ],
      ),
    );
  }
}

class _SportStrip extends StatelessWidget {
  const _SportStrip();

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Basketball', Icons.sports_basketball_rounded),
      ('Badminton', Icons.sports_tennis_rounded),
      ('Volleyball', Icons.sports_volleyball_rounded),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(item.$2, color: AppTheme.ink, size: 18),
                const SizedBox(width: 8),
                Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.blush,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.slate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
