import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.size,
    this.imageUrl = '',
    this.iconSize,
    this.backgroundColor,
  });

  final double size;
  final String imageUrl;
  final double? iconSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppColors.surfaceSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: _AppImage(
        imageUrl: imageUrl,
        fallback: Icon(
          Icons.person_rounded,
          color: AppColors.textTertiary,
          size: iconSize ?? size * 0.48,
        ),
      ),
    );
  }
}

class AppPostImage extends StatelessWidget {
  const AppPostImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return _AppImage(
      imageUrl: imageUrl,
      fit: fit,
      fallback: const ColoredBox(
        color: AppColors.surfaceSoft,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: AppColors.textTertiary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _AppImage extends StatelessWidget {
  const _AppImage({
    required this.imageUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return fallback;

    if (trimmed.startsWith('data:image/')) {
      final data = Uri.tryParse(trimmed)?.data;
      if (data == null) return fallback;
      return Image.memory(
        data.contentAsBytes(),
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    try {
      return Image.memory(
        base64Decode(trimmed),
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }
}
