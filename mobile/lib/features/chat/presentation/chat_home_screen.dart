import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ChatHomeScreen extends StatelessWidget {
  const ChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your chats', style: textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Start with friends and trusted connections first.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: const [
                  _ChatTile(
                    name: 'Marco Santos',
                    preview: 'Game later at the covered court?',
                    badge: 'Basketball',
                  ),
                  SizedBox(height: 14),
                  _ChatTile(
                    name: 'Ariane Flores',
                    preview: 'Let’s lock the badminton schedule for Saturday.',
                    badge: 'Badminton',
                  ),
                  SizedBox(height: 24),
                  _MvpNoteCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_rounded),
        label: const Text('New chat'),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.name,
    required this.preview,
    required this.badge,
  });

  final String name;
  final String preview;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.blush,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: TextStyle(
                    color: AppTheme.slate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badge),
          ),
        ],
      ),
    );
  }
}

class _MvpNoteCard extends StatelessWidget {
  const _MvpNoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What comes next',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'After the chat foundation, we can add QR friends, swipe discovery by sport, and challenge flows on top of this mobile shell.',
            style: TextStyle(
              height: 1.45,
              color: Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }
}
