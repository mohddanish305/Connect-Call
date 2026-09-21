import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'ConnectCall';
  static const String appTagline = 'Connect with anyone, anywhere.';

  // Agora RTC Configuration (App ID is public; App Certificate is kept strictly on backend)
  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: 'f8accb6b3dc04d2c85f43cc502bb7b23',
  );

  // Environment Mode: Default to release mode or compile-time override
  static const bool isProduction = bool.fromEnvironment(
    'IS_PRODUCTION',
    defaultValue: kReleaseMode,
  );

  // Production Backend URL (Vercel Serverless API)
  // Set after Vercel deployment: flutter run --dart-define=BACKEND_BASE_URL=https://<YOUR_VERCEL_PROJECT>.vercel.app
  static const String productionBackendUrl = 'https://YOUR_VERCEL_PROJECT.vercel.app';

  // Compile-time configured backend URL via: --dart-define=BACKEND_BASE_URL=https://...
  static const String _configuredBackendUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  // Runtime configurable backend URL (e.g. for developer settings / testing)
  static String? customBackendUrl;

  /// Resolves the active backend base URL depending on environment and platform:
  /// 1. Runtime override (`customBackendUrl`) if explicitly set.
  /// 2. Compile-time `--dart-define=BACKEND_BASE_URL=...` if provided.
  /// 3. In Production (`isProduction` or release mode): `productionBackendUrl`.
  /// 4. In Local Development:
  ///    - Android emulator: `http://10.0.2.2:3000`
  ///    - Web / Desktop / iOS simulator: `http://localhost:3000`
  static String get backendBaseUrl {
    if (customBackendUrl != null && customBackendUrl!.isNotEmpty) {
      return customBackendUrl!;
    }
    if (_configuredBackendUrl.isNotEmpty) {
      return _configuredBackendUrl;
    }
    if (isProduction) {
      return productionBackendUrl;
    }

    // Development fallbacks
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    try {
      if (Platform.isAndroid) {
        // Standard Android Emulator loopback mapping to host machine
        return 'http://10.0.2.2:3000';
      }
      return 'http://localhost:3000';
    } catch (_) {
      return 'http://localhost:3000';
    }
  }

  // Backend Mode: 'firebase' (canonical Firestore signaling) or 'local' (offline simulation)
  static const String backendMode = String.fromEnvironment('BACKEND_MODE', defaultValue: 'firebase');
}
