import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../data/profile_api.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.selectedSports,
  });

  final List<String> selectedSports;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final ProfileApi _profileApi = ProfileApi();
  final _bioController = TextEditingController(
    text: 'Weekend player looking for friendly but competitive runs.',
  );
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final currentProfile = appSession.profile;
    if (currentProfile != null && currentProfile.bio.trim().isNotEmpty) {
      _bioController.text = currentProfile.bio;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    final token = appSession.token;
    final currentProfile = appSession.profile;
    if (token == null || currentProfile == null) {
      setState(() {
        _errorMessage = 'Your session is missing. Please sign up again.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updatedProfile = await _profileApi.updateMe(
        token: token,
        request: UpdateProfileRequest(
          displayName: currentProfile.displayName,
          bio: _bioController.text.trim(),
          city: currentProfile.city,
          country: currentProfile.country,
          sports: widget.selectedSports,
          skillLevel: currentProfile.skillLevel,
          visible: currentProfile.visible,
        ),
      );

      appSession.updateProfile(updatedProfile);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoute.chatHome.path,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
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
          Text('Shape your first player card', style: textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'This profile is what people will eventually see before they chat, add you with QR, or challenge you to play.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppTheme.slate,
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sports selected', style: textTheme.titleLarge),
                const SizedBox(height: 14),
                if (widget.selectedSports.isEmpty)
                  Text(
                    'You can still finish profile setup now and add sports from the onboarding selector later.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.slate,
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.selectedSports
                        .map(
                          (sport) => Chip(
                            label: Text(sport),
                            backgroundColor: AppTheme.paper,
                            side: const BorderSide(color: AppTheme.line),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Short bio',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MVP build note',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Verified accounts, Google login, Facebook login, and phone signup come later. The first pass should feel clean, calm, and fast.',
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    _finishSetup();
                  },
            child: Text(_isSubmitting ? 'Saving profile...' : 'Finish setup'),
          ),
        ],
      ),
    );
  }
}
