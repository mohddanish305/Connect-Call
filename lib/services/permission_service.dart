import 'package:permission_handler/permission_handler.dart';

enum CallPermissionStatus { granted, denied, permanentlyDenied }

class PermissionService {
  Future<CallPermissionStatus> requestAudioPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return CallPermissionStatus.granted;
    if (status.isPermanentlyDenied) return CallPermissionStatus.permanentlyDenied;
    return CallPermissionStatus.denied;
  }

  Future<CallPermissionStatus> requestVideoPermissions() async {
    final micStatus = await Permission.microphone.request();
    final camStatus = await Permission.camera.request();

    if (micStatus.isGranted && camStatus.isGranted) {
      return CallPermissionStatus.granted;
    }
    if (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied) {
      return CallPermissionStatus.permanentlyDenied;
    }
    return CallPermissionStatus.denied;
  }

  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }
}
