import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum PostOptionAction {
  edit,
  delete,
  hide,
  report,
  copyLink,
}

class PostOptionsBottomSheet extends StatelessWidget {
  const PostOptionsBottomSheet({
    super.key,
    required this.isOwnPost,
  });

  final bool isOwnPost;

  static Future<PostOptionAction?> show(
    BuildContext context, {
    required bool isOwnPost,
  }) {
    return showModalBottomSheet<PostOptionAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PostOptionsBottomSheet(isOwnPost: isOwnPost),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = isOwnPost
        ? const <_PostOptionItem>[
            _PostOptionItem(
              action: PostOptionAction.edit,
              icon: Icons.edit_outlined,
              label: 'Edit post',
            ),
            _PostOptionItem(
              action: PostOptionAction.delete,
              icon: Icons.delete_outline_rounded,
              label: 'Delete post',
              destructive: true,
            ),
            _PostOptionItem(
              action: PostOptionAction.copyLink,
              icon: Icons.link_rounded,
              label: 'Copy link',
            ),
          ]
        : const <_PostOptionItem>[
            _PostOptionItem(
              action: PostOptionAction.hide,
              icon: Icons.visibility_off_outlined,
              label: 'Hide post',
            ),
            _PostOptionItem(
              action: PostOptionAction.report,
              icon: Icons.flag_outlined,
              label: 'Report post',
              destructive: true,
            ),
            _PostOptionItem(
              action: PostOptionAction.copyLink,
              icon: Icons.link_rounded,
              label: 'Copy link',
            ),
          ];

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final option in options)
              _PostOptionRow(
                option: option,
                onTap: () => Navigator.of(context).pop(option.action),
              ),
            const Divider(height: AppSpacing.lg, color: AppColors.border),
            _PostOptionRow(
              option: const _PostOptionItem(
                action: PostOptionAction.hide,
                icon: Icons.close_rounded,
                label: 'Cancel',
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostOptionItem {
  const _PostOptionItem({
    required this.action,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final PostOptionAction action;
  final IconData icon;
  final String label;
  final bool destructive;
}

class _PostOptionRow extends StatelessWidget {
  const _PostOptionRow({
    required this.option,
    required this.onTap,
  });

  final _PostOptionItem option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = option.destructive ? AppColors.error : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(option.icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
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
