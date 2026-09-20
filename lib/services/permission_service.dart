import 'package:permission_handler/permission_handler.dart' as ph;
import '../models/call_model.dart';

enum CallPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Centralized permission management for ConnectCall Audio & Video calling.
/// Implements Section 2, 3, 4, 5 & 6 of Calling Reliability.
class PermissionService {
  /// Check current microphone permission status without prompting
  Future<CallPermissionStatus> checkAudioPermissions() async {
    final status = await ph.Permission.microphone.status;
    return _mapPermissionStatus(status);
  }

  /// Check current camera and microphone permission status without prompting
  Future<CallPermissionStatus> checkVideoPermissions() async {
    final micStatus = await ph.Permission.microphone.status;
    final camStatus = await ph.Permission.camera.status;

    if (micStatus.isGranted && camStatus.isGranted) {
      return CallPermissionStatus.granted;
    }
    if (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied) {
      return CallPermissionStatus.permanentlyDenied;
    }
    if (micStatus.isRestricted || camStatus.isRestricted) {
      return CallPermissionStatus.restricted;
    }
    return CallPermissionStatus.denied;
  }

  /// Request microphone permission for audio calls
  Future<CallPermissionStatus> requestAudioPermissions() async {
    final status = await ph.Permission.microphone.request();
    return _mapPermissionStatus(status);
  }

  /// Request camera and microphone permissions for video calls
  Future<CallPermissionStatus> requestVideoPermissions() async {
    final micStatus = await ph.Permission.microphone.request();
    final camStatus = await ph.Permission.camera.request();

    if (micStatus.isGranted && camStatus.isGranted) {
      return CallPermissionStatus.granted;
    }
    if (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied) {
      return CallPermissionStatus.permanentlyDenied;
    }
    if (micStatus.isRestricted || camStatus.isRestricted) {
      return CallPermissionStatus.restricted;
    }
    return CallPermissionStatus.denied;
  }

  /// Direct user to system App Settings when permissions are permanently denied
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  /// Centralized user-friendly error message resolution
  String getPermissionErrorMessage(CallType callType, CallPermissionStatus status) {
    final isVideo = callType == CallType.video;
    switch (status) {
      case CallPermissionStatus.permanentlyDenied:
        return isVideo
            ? 'Camera and microphone permissions are required. Please enable them in App Settings.'
            : 'Microphone permission is required to make calls. Please enable it in App Settings.';
      case CallPermissionStatus.restricted:
        return isVideo
            ? 'Camera or microphone access is restricted on this device.'
            : 'Microphone access is restricted on this device.';
      case CallPermissionStatus.denied:
      case CallPermissionStatus.granted:
        return isVideo
            ? 'Camera permission is required for video calls.'
            : 'Microphone permission is required to make calls.';
    }
  }

  CallPermissionStatus _mapPermissionStatus(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return CallPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return CallPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return CallPermissionStatus.restricted;
    }
    return CallPermissionStatus.denied;
  }
}
