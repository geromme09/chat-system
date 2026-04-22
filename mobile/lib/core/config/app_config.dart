import 'package:flutter/foundation.dart';

import '../constants/android_constants.dart';
import '../constants/ios_constants.dart';

class AppConfig {
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorApiBaseUrl;
    }

    return appleSimulatorApiBaseUrl;
  }

  static String get chatWebSocketUrl {
    final uri = Uri.parse(apiBaseUrl);
    final scheme = switch (uri.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      _ => uri.scheme,
    };

    return uri
        .replace(
          scheme: scheme,
          path: '/ws/chat',
          queryParameters: null,
        )
        .toString();
  }
}
