import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/chat/presentation/chat_conversation_screen.dart';
import '../features/chat/presentation/chat_home_screen.dart';
import '../features/friends/presentation/friend_scanner_screen.dart';
import '../features/profile/presentation/profile_setup_screen.dart';
import '../features/sports/presentation/sports_selection_screen.dart';

enum AppRoute {
  welcome('/'),
  signUp('/sign-up'),
  login('/login'),
  sportsSelection('/sports-selection'),
  profileSetup('/profile-setup'),
  friendScanner('/friend-scanner'),
  chatConversation('/chat-conversation'),
  chatHome('/chat-home');

  const AppRoute(this.path);

  final String path;
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        final welcomeArgs = settings.arguments is WelcomeScreenArgs
            ? settings.arguments! as WelcomeScreenArgs
            : const WelcomeScreenArgs();
        return MaterialPageRoute<void>(
          builder: (_) => WelcomeScreen(args: welcomeArgs),
          settings: settings,
        );
      case '/sign-up':
        return MaterialPageRoute<void>(
          builder: (_) => const SignUpScreen(),
          settings: settings,
        );
      case '/login':
        final loginArgs = settings.arguments is LoginScreenArgs
            ? settings.arguments! as LoginScreenArgs
            : const LoginScreenArgs();
        return MaterialPageRoute<void>(
          builder: (_) => LoginScreen(args: loginArgs),
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
      case '/chat-conversation':
        final chatArgs = settings.arguments is ChatConversationArgs
            ? settings.arguments! as ChatConversationArgs
            : const ChatConversationArgs(
                name: 'Friend',
                sport: 'Sport',
                lastSeenLabel: 'Active recently',
              );
        return MaterialPageRoute<void>(
          builder: (_) => ChatConversationScreen(args: chatArgs),
          settings: settings,
        );
      case '/friend-scanner':
        return MaterialPageRoute<void>(
          builder: (_) => const FriendScannerScreen(),
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
