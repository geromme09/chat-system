import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../chat/data/chat_unread_controller.dart';
import '../../chat/presentation/chat_home_screen.dart';
import '../../feed/presentation/news_feed_screen.dart';
import '../../profile/presentation/profile_home_screen.dart';

class HomeShellArgs {
  const HomeShellArgs({
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;
}

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({
    super.key,
    this.args = const HomeShellArgs(),
  });

  final HomeShellArgs args;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  late int _currentIndex = widget.args.initialTabIndex.clamp(0, 2);

  @override
  void initState() {
    super.initState();
    chatUnreadController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const NewsFeedScreen(),
      const ChatHomeScreen(isEmbedded: true),
      const ProfileHomeScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
              color: AppColors.border.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
        ),
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: 'Feed',
                  selected: _currentIndex == 0,
                  icon: const Icon(Icons.grid_view_rounded),
                  onTap: () {
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: chatUnreadController,
                  builder: (context, _) {
                    return _BottomNavItem(
                      label: 'Chats',
                      selected: _currentIndex == 1,
                      icon: Badge(
                        isLabelVisible: chatUnreadController.hasUnread,
                        label: Text(chatUnreadController.badgeLabel),
                        child: Icon(
                          _currentIndex == 1
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.chat_bubble_outline_rounded,
                        ),
                      ),
                      onTap: () async {
                        setState(() {
                          _currentIndex = 1;
                        });
                        await chatUnreadController.refresh();
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'Profile',
                  selected: _currentIndex == 2,
                  icon: const Icon(Icons.person_outline_rounded),
                  onTap: () {
                    setState(() {
                      _currentIndex = 2;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: 20,
                    color:
                        selected ? AppColors.primary : AppColors.textTertiary,
                  ),
                  child: icon,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1,
                    color:
                        selected ? AppColors.primary : AppColors.textTertiary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
