import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/chat/presentation/chat_home_screen.dart';
import '../features/profile/presentation/profile_setup_screen.dart';
import '../features/sports/presentation/sports_selection_screen.dart';

enum AppRoute {
  welcome('/'),
  signUp('/sign-up'),
  login('/login'),
  sportsSelection('/sports-selection'),
  profileSetup('/profile-setup'),
  chatHome('/chat-home');

  const AppRoute(this.path);

  final String path;
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute<void>(
          builder: (_) => const WelcomeScreen(),
          settings: settings,
        );
      case '/sign-up':
        return MaterialPageRoute<void>(
          builder: (_) => const SignUpScreen(),
          settings: settings,
        );
      case '/login':
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case '/sports-selection':
        return MaterialPageRoute<void>(
          builder: (_) => const SportsSelectionScreen(),
          settings: settings,
        );
      case '/profile-setup':
        final selectedSports = settings.arguments is List<String>
            ? settings.arguments! as List<String>
            : const <String>[];
        return MaterialPageRoute<void>(
          builder: (_) => ProfileSetupScreen(selectedSports: selectedSports),
          settings: settings,
        );
      case '/chat-home':
        return MaterialPageRoute<void>(
          builder: (_) => const ChatHomeScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const WelcomeScreen(),
          settings: settings,
        );
    }
  }
}
