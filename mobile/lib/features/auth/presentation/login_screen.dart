import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/bottom_action_area.dart';
import '../../../core/widgets/onboarding_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.args = const LoginScreenArgs(),
  });

  final LoginScreenArgs args;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class LoginScreenArgs {
  const LoginScreenArgs({
    this.identifier = '',
    this.registrationSuccessMessage,
  });

  final String identifier;
  final String? registrationSuccessMessage;
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthApi _authApi = AuthApi();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canSubmit {
    return _identifierController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        !_isSubmitting;
  }

  @override
  void initState() {
    super.initState();
    _identifierController
      ..text = widget.args.identifier
      ..addListener(_handleFieldChanged);
    _passwordController.addListener(_handleFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final message = widget.args.registrationSuccessMessage;
      if (!mounted || message == null || message.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  void dispose() {
    _identifierController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    _passwordController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFieldChanged() {
    if (_errorMessage == null) {
      setState(() {});
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your email or username.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your password.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _authApi.login(
        LoginRequest(
          identifier: identifier,
          password: password,
        ),
      );

      appSession.setSession(
        token: result.token,
        userID: result.userID,
        username: result.username,
        email: result.email,
        profile: result.profile,
        profileComplete: result.profileComplete,
      );

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        result.profileComplete
            ? AppRoute.appHome.path
            : AppRoute.profileSetup.path,
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

  void _showForgotPasswordMessage() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset is not available yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.md,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: AppSpacing.authTitleTop),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.loginTitle,
                          height: AppTypography.compactLineHeight,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Pick up where you left off with your chats, friends, and profile.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.body,
                          height: AppTypography.bodyLineHeight,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.authFormTop),
                      OnboardingTextField(
                        controller: _identifierController,
                        label: 'Email or username',
                        hint: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OnboardingTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: !_isPasswordVisible,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (_canSubmit) _submit();
                        },
                        trailing: IconButton(
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordMessage,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: AppTypography.helper,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: AppMotion.quick,
                        child: _errorMessage == null
                            ? const SizedBox(height: AppSpacing.lg)
                            : Padding(
                                key: ValueKey(_errorMessage),
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                  bottom: AppSpacing.sm,
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: AppTypography.helper,
                                    height: AppTypography.helperLineHeight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              BottomActionArea(
                primaryButton: PrimaryButton(
                  label: _isSubmitting ? 'Signing in...' : 'Sign in',
                  onPressed: _canSubmit ? _submit : null,
                ),
                footer: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pushReplacementNamed(
                            AppRoute.signUp.path,
                          ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Don\'t have an account? Create account',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: AppTypography.footer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
