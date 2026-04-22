import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../data/friends_api.dart';

class FriendRequestProfileScreen extends StatefulWidget {
  const FriendRequestProfileScreen({
    super.key,
    required this.request,
    required this.title,
    required this.isIncomingRequest,
    required this.showChatButton,
    required this.onAcceptRequest,
    required this.onDeclineRequest,
    required this.onOpenChat,
  });

  final FriendRequestRecord request;
  final String title;
  final bool isIncomingRequest;
  final bool showChatButton;
  final Future<bool> Function() onAcceptRequest;
  final Future<bool> Function() onDeclineRequest;
  final FutureOr<void> Function() onOpenChat;

  @override
  State<FriendRequestProfileScreen> createState() =>
      _FriendRequestProfileScreenState();
}

class _FriendRequestProfileScreenState
    extends State<FriendRequestProfileScreen> {
  late bool _showChatButton = widget.showChatButton;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final person = widget.isIncomingRequest
        ? widget.request.requester
        : widget.request.addressee;
    final textTheme = Theme.of(context).textTheme;
    final location =
        person.city.trim().isEmpty ? 'Location not shared yet' : person.city;

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
          Center(
            child: Text(
              'Friend request',
              style: textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            child: Column(
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFE4E2FF),
                        Color(0xFFD7DBFF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.title.characters.first.toUpperCase(),
                    style: textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.title,
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '@${person.username}',
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 20,
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
                  width: double.infinity,
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1E8),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.sports_basketball_rounded,
                          color: Color(0xFFFF8A00),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Weekend player looking for friendly but competitive runs.',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _headlineCopy(person.username),
            style: textTheme.headlineMedium?.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _subheadlineCopy(person.username),
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : () {},
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('View full profile'),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_showChatButton)
            FilledButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      await widget.onOpenChat();
                    },
              icon: const Icon(Icons.chat_bubble_rounded),
              label: const Text('Open chat'),
            )
          else ...[
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleAccept,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSubmitting ? 'Accepting...' : 'Accept request'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _handleDecline,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFFE15241),
              ),
              label: const Text(
                'Decline request',
                style: TextStyle(color: Color(0xFFE15241)),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
              ),
              Text(
                _showChatButton
                    ? 'This update has already been seen. You can jump back into chat anytime.'
                    : 'They will be notified once you respond.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _headlineCopy(String username) {
    if (_showChatButton && widget.isIncomingRequest) {
      return '@$username is already connected with you.';
    }
    if (_showChatButton) {
      return '@$username accepted your friend request.';
    }
    return '@$username wants to connect with you.';
  }

  String _subheadlineCopy(String username) {
    if (_showChatButton && widget.isIncomingRequest) {
      return 'You are already friends. Open the chat to continue the conversation.';
    }
    if (_showChatButton) {
      return 'Your request has already been accepted. Open the chat to say hi.';
    }
    return 'Accept or decline this request.';
  }

  Future<void> _handleAccept() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final accepted = await widget.onAcceptRequest();
      if (!mounted || !accepted) {
        return;
      }

      setState(() {
        _showChatButton = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleDecline() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final declined = await widget.onDeclineRequest();
      if (!mounted || !declined) {
        return;
      }
      Navigator.of(context).maybePop();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
