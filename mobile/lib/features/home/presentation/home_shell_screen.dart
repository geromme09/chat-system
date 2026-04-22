import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../chat/data/chat_unread_controller.dart';
import '../../chat/presentation/chat_home_screen.dart';
import '../../friends/presentation/friend_scanner_screen.dart';
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
      ChatHomeScreen(
        isEmbedded: true,
        onOpenFriendsTab: () => setState(() => _currentIndex = 1),
      ),
      FriendScannerScreen(
        isEmbedded: true,
        onOpenChatsTab: () => setState(() => _currentIndex = 0),
      ),
      const ProfileHomeScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: NavigationBar(
            height: 72,
            selectedIndex: _currentIndex,
            indicatorColor: AppColors.primarySoft,
            backgroundColor: AppColors.surface,
            onDestinationSelected: (index) async {
              setState(() {
                _currentIndex = index;
              });
              if (index == 0) {
                await chatUnreadController.refresh();
              }
            },
            destinations: [
              NavigationDestination(
                icon: AnimatedBuilder(
                  animation: chatUnreadController,
                  builder: (context, _) {
                    return Badge(
                      isLabelVisible: chatUnreadController.hasUnread,
                      label: Text(chatUnreadController.badgeLabel),
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    );
                  },
                ),
                selectedIcon: AnimatedBuilder(
                  animation: chatUnreadController,
                  builder: (context, _) {
                    return Badge(
                      isLabelVisible: chatUnreadController.hasUnread,
                      label: Text(chatUnreadController.badgeLabel),
                      child: const Icon(Icons.chat_bubble_rounded),
                    );
                  },
                ),
                label: 'Chats',
              ),
              const NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group_rounded),
                label: 'Friends',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
