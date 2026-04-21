import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/presentation/welcome_screen.dart';
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
        _errorMessage = 'Your session expired. Please sign up again.';
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
      appSession.clear();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoute.welcome.path,
        (_) => false,
        arguments: const WelcomeScreenArgs(
          successMessage: 'Registration complete',
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
            'Shape your player card',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This is what people see before they connect or play.',
            style: textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.lg),

          /// PROFILE CARD
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sports',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),

                /// SPORTS CHIPS
                if (widget.selectedSports.isEmpty)
                  Text(
                    'You can add sports later anytime.',
                    style: textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: widget.selectedSports.map((sport) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppRadius.sm,
                          ),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Text(
                          sport,
                          style: textTheme.bodyMedium,
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: AppSpacing.lg),

                /// BIO
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

          /// ERROR STATE
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          /// CTA
          FilledButton(
            onPressed: _isSubmitting ? null : _finishSetup,
            child: Text(
              _isSubmitting ? 'Saving profile...' : 'Finish setup',
            ),
          ),
        ],
      ),
    );
  }
}
