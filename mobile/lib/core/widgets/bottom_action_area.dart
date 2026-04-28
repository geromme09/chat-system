import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BottomActionArea extends StatelessWidget {
  const BottomActionArea({
    super.key,
    required this.primaryButton,
    this.footer,
    this.isKeyboardAware = true,
  });

  final Widget primaryButton;
  final Widget? footer;
  final bool isKeyboardAware;

  @override
  Widget build(BuildContext context) {
    final keyboardInset =
        isKeyboardAware ? MediaQuery.viewInsetsOf(context).bottom : 0.0;

    return AnimatedPadding(
      duration: AppMotion.quick,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            primaryButton,
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.md),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
