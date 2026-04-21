import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_shell.dart';

class WelcomeScreenArgs {
  const WelcomeScreenArgs({
    this.successMessage,
  });

  final String? successMessage;
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    this.args = const WelcomeScreenArgs(),
  });

  final WelcomeScreenArgs args;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showSuccessPill = false;

  @override
  void initState() {
    super.initState();
    final message = widget.args.successMessage;
    if (message == null || message.isEmpty) return;

    _showSuccessPill = true;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _showSuccessPill = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return BrandShell(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                RichText(
                  text: TextSpan(
                    style: textTheme.displaySmall?.copyWith(height: 1.08),
                    children: const [
                      TextSpan(text: 'Play what\n'),
                      TextSpan(
                        text: 'you love.',
                        style: TextStyle(color: AppColors.accentStrong),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Any game. Any court.\nAnytime.',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: SizedBox(
                    height: screenHeight * 0.38,
                    child: Image.asset(
                      'assets/images/welcome.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoute.signUp.path),
                  child: const Text('Create account'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoute.login.path),
                  child: const Text('I already have an account'),
                ),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                opacity: _showSuccessPill ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AnimatedSlide(
                  offset:
                      _showSuccessPill ? Offset.zero : const Offset(0.15, -0.2),
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.args.successMessage ?? '',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
