import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/chat/presentation/chat_conversation_screen.dart';
import '../features/chat/presentation/chat_home_screen.dart';
import '../features/home/presentation/home_shell_screen.dart';
import '../features/profile/presentation/profile_setup_screen.dart';
import '../features/sports/presentation/sports_selection_screen.dart';

enum AppRoute {
  welcome('/'),
  signUp('/sign-up'),
  login('/login'),
  sportsSelection('/sports-selection'),
  profileSetup('/profile-setup'),
  appHome('/home'),
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
        return _buildRoute<void>(
          builder: (_) => WelcomeScreen(args: welcomeArgs),
          settings: settings,
        );
      case '/sign-up':
        return _buildRoute<void>(
          builder: (_) => const SignUpScreen(),
          settings: settings,
        );
      case '/login':
        final loginArgs = settings.arguments is LoginScreenArgs
            ? settings.arguments! as LoginScreenArgs
            : const LoginScreenArgs();
        return _buildRoute<void>(
          builder: (_) => LoginScreen(args: loginArgs),
          settings: settings,
        );
      case '/sports-selection':
        return _buildRoute<void>(
          builder: (_) => const SportsSelectionScreen(),
          settings: settings,
        );
      case '/profile-setup':
        final selectedSports = settings.arguments is List<String>
            ? settings.arguments! as List<String>
            : const <String>[];
        return _buildRoute<void>(
          builder: (_) => ProfileSetupScreen(selectedSports: selectedSports),
          settings: settings,
        );
      case '/home':
        final homeArgs = settings.arguments is HomeShellArgs
            ? settings.arguments! as HomeShellArgs
            : const HomeShellArgs();
        return _buildRoute<void>(
          builder: (_) => HomeShellScreen(args: homeArgs),
          settings: settings,
        );
      case '/chat-home':
        return _buildRoute<void>(
          builder: (_) => const ChatHomeScreen(),
          settings: settings,
        );
      case '/chat-conversation':
        final chatArgs = settings.arguments is ChatConversationArgs
            ? settings.arguments! as ChatConversationArgs
            : const ChatConversationArgs(
                conversationID: '',
                title: 'Friend',
                participantUserID: '',
                subtitle: 'Conversation',
              );
        return _buildRoute<void>(
          builder: (_) => ChatConversationScreen(args: chatArgs),
          settings: settings,
        );
      default:
        return _buildRoute<void>(
          builder: (_) => const WelcomeScreen(),
          settings: settings,
        );
    }
  }

  static PageRoute<T> _buildRoute<T>({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
    );
  }
}
