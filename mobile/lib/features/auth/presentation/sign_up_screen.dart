import 'package:flutter/material.dart';

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
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _cityController = TextEditingController();

  bool _agreeToSafety = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _cityController.dispose();
    super.dispose();
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
        ),
      );

      appSession.setSession(
        token: result.token,
        userID: result.userID,
        profile: result.profile,
      );

      if (!mounted) return;

      Navigator.of(context).pushNamed(AppRoute.sportsSelection.path);
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
            'Create your player profile',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start with a safe identity and where you usually play.',
            style: textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.lg),

          /// AVATAR
          const _AvatarPickerCard(),

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
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value == null || value.length < 8)
                        ? 'Use at least 8 characters'
                        : null,
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
  const _AvatarPickerCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.add_a_photo_rounded,
              size: 30,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a profile photo',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Clear and real photos build trust.',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
