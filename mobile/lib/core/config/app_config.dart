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
}
