import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class ChatSystemApp extends StatelessWidget {
  const ChatSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Play Circle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRoute.welcome.path,
    );
  }
}
