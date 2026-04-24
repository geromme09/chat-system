import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../data/profile_api.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const List<String> _genderOptions = <String>[
    '',
    'Woman',
    'Man',
    'Non-binary',
    'Prefer not to say',
  ];

  final ProfileApi _profileApi = ProfileApi();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();

  String _selectedGender = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final currentProfile = appSession.profile;

    if (currentProfile == null) {
      return;
    }

    _bioController.text = currentProfile.bio;
    _hobbiesController.text = currentProfile.hobbiesText;
    _selectedGender = currentProfile.gender;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _hobbiesController.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    final token = appSession.token;
    final currentProfile = appSession.profile;

    if (token == null || currentProfile == null) {
      setState(() {
        _errorMessage = 'Your session expired. Please sign in again.';
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
          gender: _selectedGender,
          hobbiesText: _hobbiesController.text.trim(),
          visible: currentProfile.visible,
        ),
      );

      appSession.updateProfile(updatedProfile, profileComplete: true);
      appSession.clear();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoute.welcome.path,
        (_) => false,
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
          Text(
            'Finish your profile',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add a little context so your account feels complete before you log in.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender (optional)',
                  ),
                  items: _genderOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option.isEmpty ? 'Prefer not to share' : option,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _hobbiesController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Hobbies or interests (optional)',
                    hintText: 'Music, anime, coffee runs, arcades',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Short bio',
                    hintText: 'Tell friends a little about yourself.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
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
