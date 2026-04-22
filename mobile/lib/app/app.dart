import 'package:flutter/material.dart';

import '../core/session/app_session.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/home/presentation/home_shell_screen.dart';
import '../features/sports/presentation/sports_selection_screen.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class ChatSystemApp extends StatelessWidget {
  const ChatSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appSession,
      builder: (context, _) {
        return MaterialApp(
          title: 'Play Circle',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const _SessionGate(),
        );
      },
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    if (!appSession.isAuthenticated) {
      return const WelcomeScreen();
    }

    final profile = appSession.profile;
    final hasFinishedProfile = profile != null &&
        profile.displayName.trim().isNotEmpty &&
        profile.sports.isNotEmpty;

    if (!hasFinishedProfile) {
      return const SportsSelectionScreen();
    }

    return const HomeShellScreen();
  }
}
