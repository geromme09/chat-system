import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav_bar.dart';
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
      bottomNavigationBar: AnimatedBuilder(
        animation: chatUnreadController,
        builder: (context, _) {
          return AppBottomNavBar(
            currentIndex: _currentIndex,
            showChatsBadge: chatUnreadController.hasUnread,
            chatsBadgeLabel: chatUnreadController.badgeLabel,
            onTabSelected: _handleTabSelected,
          );
        },
      ),
    );
  }

  Future<void> _handleTabSelected(int index) async {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }

    if (index == 1) {
      await chatUnreadController.refresh();
    }
  }
}
