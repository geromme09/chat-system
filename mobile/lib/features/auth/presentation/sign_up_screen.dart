import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/session/app_session.dart';
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
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _cityController = TextEditingController();
  bool _agreeToSafety = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _authApi.signUp(
        SignUpRequest(
          email: _emailController.text.trim(),
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

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamed(AppRoute.sportsSelection.path);
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
          Text('Create your player profile', style: textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Start with a safe identity, a clear profile photo, and the city where you usually play.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppTheme.slate,
            ),
          ),
          const SizedBox(height: 22),
          const _AvatarPickerCard(),
          const SizedBox(height: 18),
          SectionCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(labelText: 'Display name'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Display name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => (value == null || !value.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 8)
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Home city'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'City is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      border: Border.all(color: AppTheme.line),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
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
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'I understand this app is for real people, real sports, and respectful meetups.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            onPressed: _agreeToSafety && !_isSubmitting
                ? () {
                    _submit();
                  }
                : null,
            child: Text(_isSubmitting ? 'Creating account...' : 'Continue to sports'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoute.login.path),
            child: const Text('Already registered? Sign in'),
          ),
        ],
      ),
    );
  }
}

class _AvatarPickerCard extends StatelessWidget {
  const _AvatarPickerCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppTheme.blush,
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.add_a_photo_rounded,
              size: 34,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add your first profile photo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Keep it simple, clear, and real. The product should feel social first, not overdesigned.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
