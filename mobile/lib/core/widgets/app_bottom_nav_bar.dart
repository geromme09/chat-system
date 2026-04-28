import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.showChatsBadge = false,
    this.chatsBadgeLabel = '',
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool showChatsBadge;
  final String chatsBadgeLabel;

  static const _items = <_AppBottomNavItemData>[
    _AppBottomNavItemData(
      label: 'Feed',
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
    ),
    _AppBottomNavItemData(
      label: 'Chats',
      activeIcon: Icons.chat_bubble_rounded,
      inactiveIcon: Icons.chat_bubble_outline_rounded,
    ),
    _AppBottomNavItemData(
      label: 'Profile',
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: AppOpacity.navSurface),
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: AppOpacity.navBorder),
            width: AppSizes.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.navHorizontalPadding,
          ),
          child: SizedBox(
            height: AppSizes.bottomNavHeight,
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final isSelected = currentIndex == index;

                return Expanded(
                  child: _AppBottomNavItem(
                    label: item.label,
                    icon: isSelected ? item.activeIcon : item.inactiveIcon,
                    isSelected: isSelected,
                    showBadge: index == 1 && showChatsBadge,
                    badgeLabel: chatsBadgeLabel,
                    onTap: () => onTabSelected(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBottomNavItemData {
  const _AppBottomNavItemData({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });

  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
}

class _AppBottomNavItem extends StatefulWidget {
  const _AppBottomNavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.showBadge = false,
    this.badgeLabel = '',
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBadge;
  final String badgeLabel;

  @override
  State<_AppBottomNavItem> createState() => _AppBottomNavItemState();
}

class _AppBottomNavItemState extends State<_AppBottomNavItem> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;

    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isSelected ? AppColors.primary : AppColors.textTertiary;
    final iconSize = widget.isSelected
        ? AppSizes.bottomNavActiveIcon
        : AppSizes.bottomNavIcon;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: AppMotion.quick,
          curve: Curves.easeOutCubic,
          scale: _isPressed ? AppSizes.bottomNavPressedScale : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.bottomNavMinItemWidth,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppMotion.quick,
                  curve: Curves.easeOutCubic,
                  width: AppSizes.bottomNavIndicatorWidth,
                  height: widget.isSelected
                      ? AppSizes.bottomNavIndicatorHeight
                      : AppSizes.bottomNavIndicatorHiddenHeight,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: 2),
                Badge(
                  isLabelVisible: widget.showBadge,
                  label: Text(widget.badgeLabel),
                  child: AnimatedSwitcher(
                    duration: AppMotion.quick,
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon),
                      color: color,
                      size: iconSize,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.navIconLabelGap),
                AnimatedDefaultTextStyle(
                  duration: AppMotion.quick,
                  style: TextStyle(
                    color: color,
                    fontSize: AppTypography.navLabel,
                    height: 1,
                    fontWeight:
                        widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
