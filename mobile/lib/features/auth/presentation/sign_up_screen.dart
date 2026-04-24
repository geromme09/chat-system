import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../data/auth_api.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthApi _authApi = AuthApi();
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _cityController = TextEditingController();

  bool _agreeToSafety = true;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _errorMessage;
  XFile? _selectedAvatar;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedImage == null || !mounted) {
        return;
      }

      setState(() {
        _errorMessage = null;
        _selectedAvatar = pickedImage;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to open ${source == ImageSource.camera ? 'camera' : 'gallery'} right now.';
      });
    }
  }

  Future<void> _showAvatarOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
                if (_selectedAvatar != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove photo'),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedAvatar = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _authApi.signUp(
        SignUpRequest(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          city: _cityController.text.trim(),
          avatarFileName: _selectedAvatar?.name ?? '',
        ),
      );

      appSession.setSession(
        token: result.token,
        userID: result.userID,
        profile: result.profile,
        profileComplete: result.profileComplete,
      );

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoute.profileSetup.path,
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
          /// HEADER
          Text(
            'Create your FaceOff Social profile',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start with a safe identity so friends can find and recognize you.',
            style: textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.lg),

          /// AVATAR
          _AvatarPickerCard(
            selectedAvatar: _selectedAvatar,
            onTap: _showAvatarOptions,
          ),

          const SizedBox(height: AppSpacing.lg),

          /// FORM
          SectionCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _displayNameController,
                    decoration:
                        const InputDecoration(labelText: 'Display name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Display name is required'
                            : null,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: (value) {
                      final username = value?.trim() ?? '';
                      final usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');
                      if (!usernamePattern.hasMatch(username)) {
                        return 'Use 3-20 lowercase letters, numbers, or underscores';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => (value == null || value.length < 8)
                        ? 'Use at least 8 characters'
                        : null,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Home city'),
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'City is required'
                            : null,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  /// SAFETY AGREEMENT (lighter UI)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreeToSafety,
                        onChanged: (value) {
                          setState(() {
                            _agreeToSafety = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'I agree to respectful and safe interactions.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
            onPressed: _agreeToSafety && !_isSubmitting ? _submit : null,
            child: Text(
              _isSubmitting ? 'Creating account...' : 'Continue',
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          /// SECONDARY ACTION
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacementNamed(AppRoute.login.path),
              child: const Text('Already have an account? Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// AVATAR CARD (REFINED)
/// =======================

class _AvatarPickerCard extends StatelessWidget {
  const _AvatarPickerCard({
    required this.selectedAvatar,
    required this.onTap,
  });

  final XFile? selectedAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                image: selectedAvatar == null
                    ? null
                    : DecorationImage(
                        image: FileImage(File(selectedAvatar!.path)),
                        fit: BoxFit.cover,
                      ),
              ),
              child: selectedAvatar == null
                  ? const Icon(
                      Icons.add_a_photo_rounded,
                      size: 30,
                      color: AppColors.textPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedAvatar == null
                        ? 'Add a profile photo'
                        : 'Profile photo selected',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    selectedAvatar == null
                        ? 'Take a photo or choose one from your gallery.'
                        : selectedAvatar!.name,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
