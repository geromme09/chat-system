import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FriendScannerScreen extends StatelessWidget {
  const FriendScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ScannerBackdrop(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.48),
                  Colors.black.withValues(alpha: 0.70),
                  Colors.black.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _ScannerIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          'Scan QR',
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const _ScannerIconButton(
                        icon: Icons.flash_on_rounded,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      const _ScannerFrame(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Position the QR code\nwithin the frame',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _GalleryAction(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerBackdrop extends StatelessWidget {
  const _ScannerBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF14110F),
            Color(0xFF0C0F19),
            Color(0xFF171724),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 120,
            left: 48,
            child: _GlowOrb(
              size: 140,
              color: const Color(0x44FF9A62),
            ),
          ),
          Positioned(
            top: 220,
            right: 40,
            child: _GlowOrb(
              size: 88,
              color: const Color(0x339A7BFF),
            ),
          ),
          Positioned(
            bottom: 140,
            left: 32,
            child: _GlowOrb(
              size: 120,
              color: const Color(0x228B5CF6),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size,
            spreadRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _ScannerIconButton extends StatelessWidget {
  const _ScannerIconButton({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        children: const [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(
                    color: Color(0x66FFFFFF),
                    width: 1.2,
                  ),
                ),
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              child: SizedBox(width: 280, height: 280),
            ),
          ),
          _ScannerCorner(alignment: Alignment.topLeft),
          _ScannerCorner(alignment: Alignment.topRight),
          _ScannerCorner(alignment: Alignment.bottomLeft),
          _ScannerCorner(alignment: Alignment.bottomRight),
        ],
      ),
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({
    required this.alignment,
  });

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isTop && isLeft ? 16 : 0),
            topRight: Radius.circular(isTop && !isLeft ? 16 : 0),
            bottomLeft: Radius.circular(!isTop && isLeft ? 16 : 0),
            bottomRight: Radius.circular(!isTop && !isLeft ? 16 : 0),
          ),
          border: Border(
            top: isTop
                ? const BorderSide(color: Color(0xFF9F92FF), width: 5)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Color(0xFF9F92FF), width: 5)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Color(0xFF9F92FF), width: 5)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Color(0xFF9F92FF), width: 5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _GalleryAction extends StatelessWidget {
  const _GalleryAction();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          child: const Icon(
            Icons.photo_library_outlined,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Upload from gallery',
          style: textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
