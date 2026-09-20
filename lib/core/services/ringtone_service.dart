import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Service managing device ringtone and incoming call audio alerts.
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Start playing incoming call ringtone in a loop
  Future<void> startRingtone() async {
    if (_isPlaying) return;
    try {
      _isPlaying = true;
      debugPrint('[RingtoneService] Starting incoming ringtone playback...');
      await FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );
    } catch (e) {
      debugPrint('[RingtoneService] Error starting ringtone: $e');
    }
  }

  /// Stop incoming call ringtone playback immediately
  Future<void> stopRingtone() async {
    if (!_isPlaying) return;
    try {
      _isPlaying = false;
      debugPrint('[RingtoneService] Stopping incoming ringtone playback.');
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('[RingtoneService] Error stopping ringtone: $e');
    }
  }
}
