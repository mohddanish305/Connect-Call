class AppConfig {
  AppConfig._();

  static const String appName = 'ConnectCall';
  static const String appTagline = 'Connect with anyone, anywhere.';

  // Calling Server Configuration
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
    {'urls': 'stun:stun4.l.google.com:19302'},
  ];

  // Optional 3rd Party Calling Service Keys (if Agora or Zego are plugged in)
  static const String agoraAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
  static const String zegoAppId = String.fromEnvironment('ZEGO_APP_ID', defaultValue: '');
  static const String zegoAppSign = String.fromEnvironment('ZEGO_APP_SIGN', defaultValue: '');

  // Backend Mode: 'local' (offline-ready persistence + simulation signaling) or 'firebase'
  static const String backendMode = String.fromEnvironment('BACKEND_MODE', defaultValue: 'local');
}
