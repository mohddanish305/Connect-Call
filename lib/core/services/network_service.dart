import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight network connectivity verification service.
/// Adheres to zero unnecessary external package constraint by utilizing standard dart:io DNS resolution.
class NetworkService {
  static const String defaultHost = 'dns.google';
  static const Duration defaultTimeout = Duration(milliseconds: 2500);

  /// Checks if the device has an active, working internet connection.
  Future<bool> hasInternetConnection({
    String host = defaultHost,
    Duration timeout = defaultTimeout,
  }) async {
    // In web environment or unit tests where socket lookup might fail or not be supported,
    // handle gracefully
    if (kIsWeb) return true;

    try {
      final result = await InternetAddress.lookup(host).timeout(timeout);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      debugPrint('[NetworkService] Connectivity probe notice: $e');
      return false;
    }
  }

  /// Standard user-facing error message for disconnected state
  static const String noInternetMessage =
      'No internet connection. Please check your connection and try again.';
}
