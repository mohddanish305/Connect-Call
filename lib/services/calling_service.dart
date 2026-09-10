import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/config/app_config.dart';
import '../models/call_model.dart';
import '../models/call_session.dart';
import 'call_history_service.dart';

typedef CallSessionCallback = void Function(CallSession session);

class CallingService {
  final CallHistoryService _callHistoryService;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  CallSession _currentSession = const CallSession();
  CallSession get currentSession => _currentSession;

  CallSessionCallback? onSessionChanged;
  Timer? _durationTimer;
  Timer? _ringSimulationTimer;
  bool _renderersInitialized = false;

  CallingService(this._callHistoryService);

  Future<void> initializeRenderers() async {
    if (!_renderersInitialized) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
    }
  }

  void _updateSession(CallSession session) {
    _currentSession = session;
    onSessionChanged?.call(_currentSession);
  }

  /// Start an outgoing audio or video call
  Future<void> startCall(CallModel call) async {
    try {
      await initializeRenderers();

      _updateSession(CallSession(
        call: call,
        status: CallStatus.calling,
        isFrontCamera: true,
        isMuted: false,
        isCameraOff: false,
        isSpeakerOn: call.callType == CallType.video, // Default to speaker for video
      ));

      // Acquire hardware camera/mic stream
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': call.callType == CallType.video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
              }
            : false,
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        localRenderer.srcObject = _localStream;

        _updateSession(_currentSession.copyWith(
          isLocalPreviewReady: call.callType == CallType.video,
        ));
      } catch (e) {
        debugPrint('Media stream capture warning: $e');
      }

      // Configure speakerphone
      await Helper.setSpeakerphoneOn(_currentSession.isSpeakerOn);

      // Create WebRTC Peer Connection with STUN servers
      final configuration = <String, dynamic>{
        'iceServers': AppConfig.iceServers,
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // Add local media tracks
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection?.addTrack(track, _localStream!);
        }
      }

      // Handle incoming remote media tracks
      _peerConnection?.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          remoteRenderer.srcObject = _remoteStream;
          _updateSession(_currentSession.copyWith(isRemoteStreamReady: true));
        }
      };

      _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('ICE connection state: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _updateSession(_currentSession.copyWith(status: CallStatus.disconnected));
        }
      };

      // Call State Flow: Calling -> Ringing -> Connected -> In Call
      _ringSimulationTimer?.cancel();
      _ringSimulationTimer = Timer(const Duration(milliseconds: 1500), () {
        if (_currentSession.status == CallStatus.calling) {
          _updateSession(_currentSession.copyWith(status: CallStatus.ringing));

          // Connect call after ringing
          _ringSimulationTimer = Timer(const Duration(milliseconds: 2500), () {
            if (_currentSession.status == CallStatus.ringing) {
              _onCallConnected();
            }
          });
        }
      });
    } catch (e) {
      _updateSession(_currentSession.copyWith(
        status: CallStatus.failed,
        errorMessage: 'Failed to start call: $e',
      ));
    }
  }

  /// Receive an incoming call
  void receiveIncomingCall(CallModel call) {
    _updateSession(CallSession(
      call: call,
      status: CallStatus.ringing,
      isSpeakerOn: call.callType == CallType.video,
    ));
  }

  /// Accept an incoming call
  Future<void> acceptCall() async {
    final call = _currentSession.call;
    if (call == null) return;

    try {
      await initializeRenderers();

      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': call.callType == CallType.video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        localRenderer.srcObject = _localStream;
      } catch (e) {
        debugPrint('Media stream capture warning: $e');
      }

      await Helper.setSpeakerphoneOn(_currentSession.isSpeakerOn);

      _onCallConnected();
    } catch (e) {
      _updateSession(_currentSession.copyWith(
        status: CallStatus.failed,
        errorMessage: 'Failed to accept call: $e',
      ));
    }
  }

  /// Reject incoming call
  Future<void> rejectCall() async {
    _ringSimulationTimer?.cancel();
    final call = _currentSession.call;
    if (call != null) {
      await _callHistoryService.logCall(call.copyWith(
        status: CallStatus.rejected,
        endedAt: DateTime.now(),
        duration: 0,
        isMissed: false,
      ));
    }
    _updateSession(_currentSession.copyWith(status: CallStatus.rejected));
    await _cleanupMedia();
  }

  void _onCallConnected() {
    _ringSimulationTimer?.cancel();
    _updateSession(_currentSession.copyWith(status: CallStatus.connected));

    // Transition to InCall and start ticking duration
    Future.delayed(const Duration(milliseconds: 600), () {
      if (_currentSession.status == CallStatus.connected) {
        _updateSession(_currentSession.copyWith(status: CallStatus.inCall));
        _startDurationTimer();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSession.status == CallStatus.inCall) {
        _updateSession(_currentSession.copyWith(
          durationSeconds: _currentSession.durationSeconds + 1,
        ));
      }
    });
  }

  /// Toggle Microphone Mute/Unmute
  Future<void> toggleMicrophone() async {
    final nextMuted = !_currentSession.isMuted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !nextMuted;
      }
    }
    _updateSession(_currentSession.copyWith(isMuted: nextMuted));
  }

  /// Toggle Camera On/Off
  Future<void> toggleCamera() async {
    final nextCameraOff = !_currentSession.isCameraOff;
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = !nextCameraOff;
      }
    }
    _updateSession(_currentSession.copyWith(isCameraOff: nextCameraOff));
  }

  /// Switch front / rear camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final track = videoTracks.first;
        await Helper.switchCamera(track);
        _updateSession(_currentSession.copyWith(
          isFrontCamera: !_currentSession.isFrontCamera,
        ));
      }
    }
  }

  /// Toggle Speakerphone / Earpiece
  Future<void> toggleSpeaker([bool? forceState]) async {
    final nextSpeaker = forceState ?? !_currentSession.isSpeakerOn;
    await Helper.setSpeakerphoneOn(nextSpeaker);
    _updateSession(_currentSession.copyWith(isSpeakerOn: nextSpeaker));
  }

  /// End Call
  Future<void> endCall() async {
    _durationTimer?.cancel();
    _ringSimulationTimer?.cancel();

    final call = _currentSession.call;
    final finalDuration = _currentSession.durationSeconds;

    if (call != null) {
      final isMissed = _currentSession.status == CallStatus.ringing || _currentSession.status == CallStatus.calling;
      await _callHistoryService.logCall(call.copyWith(
        status: isMissed ? CallStatus.missed : CallStatus.ended,
        endedAt: DateTime.now(),
        duration: finalDuration,
        isMissed: isMissed,
      ));
    }

    _updateSession(_currentSession.copyWith(status: CallStatus.ended));
    await _cleanupMedia();
  }

  Future<void> _cleanupMedia() async {
    _durationTimer?.cancel();
    _ringSimulationTimer?.cancel();

    try {
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream?.dispose();
        _localStream = null;
      }

      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          track.stop();
        }
        await _remoteStream?.dispose();
        _remoteStream = null;
      }

      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    } catch (e) {
      debugPrint('Cleanup media error: $e');
    }
  }

  Future<void> dispose() async {
    await _cleanupMedia();
    if (_renderersInitialized) {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      _renderersInitialized = false;
    }
  }
}
