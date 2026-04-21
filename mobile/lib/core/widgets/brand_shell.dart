import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandShell extends StatelessWidget {
  const BrandShell({
    super.key,
    required this.child,
    this.showBack = false,
  });

  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundDecor(),
          SafeArea(
            child: Column(
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundDecor extends StatelessWidget {
  const _BackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.paper,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 26,
            right: 24,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.lime,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 138,
            left: 24,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.blush,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            right: 28,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.ink.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
