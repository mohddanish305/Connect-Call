import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import '../../models/call_model.dart';

class AgoraJoinResult {
  final bool success;
  final int? errorCode;
  final String? errorMessage;
  final String? exceptionType;

  const AgoraJoinResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
    this.exceptionType,
  });
}

/// Service wrapping the Agora RTC Engine for real 1-to-1 audio and video calling
class AgoraService {
  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isJoined = false;
  bool get isJoined => _isJoined;

  bool _isJoining = false;
  bool get isJoining => _isJoining;

  int? _localUid;
  int? get localUid => _localUid;

  int? _remoteUid;
  int? get remoteUid => _remoteUid;

  String? _currentChannel;
  String? get currentChannel => _currentChannel;

  CallType? _currentCallType;
  CallType? get currentCallType => _currentCallType;

  // Event callbacks
  void Function(String channel, int uid)? onJoinChannelSuccess;
  void Function(int remoteUid)? onUserJoined;
  void Function(int remoteUid, UserOfflineReasonType reason)? onUserOffline;
  void Function(RtcConnection connection, RtcStats stats)? onLeaveChannel;
  void Function(ConnectionStateType state, ConnectionChangedReasonType reason)? onConnectionStateChanged;
  void Function(String token)? onTokenPrivilegeWillExpire;
  void Function(ErrorCodeType err, String msg)? onError;
  void Function(int remoteUid, bool muted)? onUserMuteVideo;
  void Function(int remoteUid, bool muted)? onUserMuteAudio;
  void Function(int remoteUid, RemoteVideoState state)? onRemoteVideoStateChanged;
  void Function(int uid, QualityType txQuality, QualityType rxQuality)? onNetworkQuality;

  AgoraJoinResult? _lastJoinResult;
  AgoraJoinResult? get lastJoinResult => _lastJoinResult;

  int? _lastErrorCode;
  int? get lastErrorCode => _lastErrorCode;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  /// Initialize Agora RTC Engine with App ID
  Future<bool> initialize({required String appId}) async {
    if (_isInitialized && _engine != null) {
      debugPrint('[AGORA] initialize already initialized, reusing engine');
      return true;
    }

    if (appId.isEmpty) {
      debugPrint('[AgoraService] Warning: Agora App ID is empty.');
      _lastErrorMessage = 'Agora App ID is empty.';
      return false;
    }

    try {
      debugPrint('[AGORA] initialize START');
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      _registerEventHandlers();
      await _engine!.enableAudio();
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioDefault,
      );

      _isInitialized = true;
      debugPrint('[AGORA] initialize SUCCESS');
      debugPrint('[AgoraService] RTC Engine initialized successfully with appId format length: ${appId.length}');
      return true;
    } on AgoraRtcException catch (e) {
      _lastErrorCode = e.code;
      _lastErrorMessage = e.message;
      debugPrint('[AgoraService] Initialization AgoraRtcException - code: ${e.code}, msg: ${e.message}');
      _isInitialized = false;
      return false;
    } catch (e) {
      _lastErrorMessage = e.toString();
      debugPrint('[AgoraService] Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  void _registerEventHandlers() {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[AGORA] onJoinChannelSuccess: channel=${connection.channelId}, uid=${connection.localUid}');
          debugPrint('[AGORA EVENT]\nevent: onJoinChannelSuccess\nchannel: ${connection.channelId}\nuid: ${connection.localUid}');
          _isJoining = false;
          _isJoined = true;
          _localUid = connection.localUid;
          _currentChannel = connection.channelId;
          onJoinChannelSuccess?.call(connection.channelId ?? '', connection.localUid ?? 0);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[AGORA] onUserJoined: remoteUid=$remoteUid, channel=${connection.channelId}');
          debugPrint('[AGORA REMOTE JOIN] remoteUid=$remoteUid');
          debugPrint('[AGORA EVENT]\nevent: onUserJoined\nremoteUid: $remoteUid\nchannel: ${connection.channelId}');
          _remoteUid = remoteUid;
          onUserJoined?.call(remoteUid);
        },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          debugPrint('[AGORA REMOTE VIDEO STATE] uid=$remoteUid state=$state');
          debugPrint('[AGORA EVENT]\nevent: onRemoteVideoStateChanged\nremoteUid: $remoteUid\nstate: $state\nreason: $reason');
          onRemoteVideoStateChanged?.call(remoteUid, state);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('[AGORA] onUserOffline: remoteUid=$remoteUid (reason=$reason)');
          debugPrint('[AGORA EVENT]\nevent: onUserOffline\nremoteUid: $remoteUid\nreason: $reason');
          if (_remoteUid == remoteUid) {
            _remoteUid = null;
          }
          onUserOffline?.call(remoteUid, reason);
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('[AGORA EVENT]\nevent: onLeaveChannel\nchannel: ${connection.channelId}');
          _isJoining = false;
          _isJoined = false;
          _remoteUid = null;
          _currentChannel = null;
          _currentCallType = null;
          onLeaveChannel?.call(connection, stats);
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[AGORA] connection state=$state (reason=$reason)');
          debugPrint('[AGORA EVENT]\nevent: onConnectionStateChanged\nstate: $state\nreason: $reason');
          if (state == ConnectionStateType.connectionStateConnected) {
            _isJoining = false;
            _isJoined = true;
          } else if (state == ConnectionStateType.connectionStateFailed) {
            _isJoining = false;
          }
          onConnectionStateChanged?.call(state, reason);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('[AGORA EVENT]\nevent: onTokenPrivilegeWillExpire');
          onTokenPrivilegeWillExpire?.call(token);
        },
        onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
          debugPrint('[AGORA EVENT]\nevent: onUserMuteVideo\nremoteUid: $remoteUid\nmuted: $muted');
          onUserMuteVideo?.call(remoteUid, muted);
        },
        onUserMuteAudio: (RtcConnection connection, int remoteUid, bool muted) {
          debugPrint('[AGORA EVENT]\nevent: onUserMuteAudio\nremoteUid: $remoteUid\nmuted: $muted');
          onUserMuteAudio?.call(remoteUid, muted);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[AGORA] error: code=$err, msg=$msg');
          debugPrint('[AGORA EVENT]\nevent: onError\nerrorCode: $err\nmessage: $msg');
          if (err == ErrorCodeType.errJoinChannelRejected || err == ErrorCodeType.errInvalidToken || err == ErrorCodeType.errTokenExpired) {
            _isJoining = false;
          }
          onError?.call(err, msg);
        },
        onNetworkQuality: (RtcConnection connection, int remoteUid, QualityType txQuality, QualityType rxQuality) {
          onNetworkQuality?.call(remoteUid, txQuality, rxQuality);
        },
      ),
    );
    debugPrint('[AGORA] event handlers registered');
  }

  /// Join channel with token, channel name, and UID
  Future<AgoraJoinResult> joinChannel({
    required String token,
    required String channelName,
    required int uid,
    required CallType callType,
    String? callId,
    DateTime? tokenExpiry,
  }) async {
    if (_engine == null || !_isInitialized) {
      debugPrint('[AgoraService] Engine not initialized before joinChannel.');
      const res = AgoraJoinResult(
        success: false,
        errorMessage: 'Agora RTC engine is not initialized.',
        exceptionType: 'NotInitializedException',
      );
      _lastJoinResult = res;
      return res;
    }

    // Idempotent duplicate-join guard: Prevent re-joining while already active or in-flight
    if ((_isJoined || _isJoining) && _currentChannel == channelName && _localUid == uid) {
      debugPrint('[AGORA] joinChannel skipped: already ${_isJoined ? "joined" : "joining"} channel $channelName with uid $uid');
      const res = AgoraJoinResult(success: true);
      _lastJoinResult = res;
      return res;
    }

    try {
      _isJoining = true;
      debugPrint('[AGORA] joinChannel START');
      _currentCallType = callType;
      _localUid = uid;
      _currentChannel = channelName;

      if (callType == CallType.video) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 480),
            frameRate: 15,
            bitrate: 800,
            orientationMode: OrientationMode.orientationModeAdaptive,
          ),
        );
      } else {
        await _engine!.disableVideo();
      }

      final options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: callType == CallType.video,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: callType == CallType.video,
      );

      final cleanToken = token.trim();
      debugPrint('[AGORA TOKEN DIAGNOSTIC] channel used by app: $channelName');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] numeric UID used by app: $uid');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] whether token is present: ${cleanToken.isNotEmpty}');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] token string length: ${cleanToken.length}');
      debugPrint('[AGORA] joinChannel invoked (channel: $channelName, uid: $uid)');
      await _engine!.joinChannel(
        token: cleanToken,
        channelId: channelName,
        uid: uid,
        options: options,
      );

      // Default speaker to ON for video call, OFF (earpiece) for audio call
      await enableSpeakerphone(callType == CallType.video);
      const res = AgoraJoinResult(success: true);
      _lastJoinResult = res;

      // Phase 5 Structured Log (Never log token contents or App Certificate)
      debugPrint('[AGORA]\ncallId=${callId ?? "none"}\nchannel=$channelName\nuid=$uid\ntokenPresent=${cleanToken.isNotEmpty}\ntokenExpiry=${tokenExpiry?.toIso8601String() ?? "none"}\ncallType=${callType.name}\njoinResult=true');

      return res;
    } on AgoraRtcException catch (e) {
      _isJoining = false;
      _lastErrorCode = e.code;
      _lastErrorMessage = e.message;
      debugPrint('[AgoraService] Join channel AgoraRtcException - code: ${e.code}, msg: ${e.message}');
      final res = AgoraJoinResult(
        success: false,
        errorCode: e.code,
        errorMessage: e.message,
        exceptionType: 'AgoraRtcException',
      );
      _lastJoinResult = res;
      debugPrint('[AGORA]\ncallId=${callId ?? "none"}\nchannel=$channelName\nuid=$uid\ntokenPresent=${token.trim().isNotEmpty}\ntokenExpiry=${tokenExpiry?.toIso8601String() ?? "none"}\ncallType=${callType.name}\njoinResult=false');
      return res;
    } catch (e) {
      _isJoining = false;
      _lastErrorMessage = e.toString();
      debugPrint('[AgoraService] Join channel error: $e');
      final res = AgoraJoinResult(
        success: false,
        errorMessage: e.toString(),
        exceptionType: e.runtimeType.toString(),
      );
      _lastJoinResult = res;
      debugPrint('[AGORA]\ncallId=${callId ?? "none"}\nchannel=$channelName\nuid=$uid\ntokenPresent=${token.trim().isNotEmpty}\ntokenExpiry=${tokenExpiry?.toIso8601String() ?? "none"}\ncallType=${callType.name}\njoinResult=false');
      return res;
    }
  }

  /// Renew token when expired or expiring
  Future<void> renewToken(String newToken) async {
    if (_engine != null && _isJoined) {
      try {
        await _engine!.renewToken(newToken);
        debugPrint('[AgoraService] Token renewed successfully.');
      } catch (e) {
        debugPrint('[AgoraService] Renew token error: $e');
      }
    }
  }

  /// Toggle local audio mute
  Future<void> muteLocalAudio(bool mute) async {
    if (_engine != null) {
      try {
        await _engine!.muteLocalAudioStream(mute);
      } catch (e) {
        debugPrint('[AgoraService] Mute audio error: $e');
      }
    }
  }

  /// Toggle local camera video
  Future<void> enableLocalVideo(bool enable) async {
    if (_engine != null) {
      try {
        await _engine!.muteLocalVideoStream(!enable);
        if (enable) {
          await _engine!.startPreview();
        } else {
          await _engine!.stopPreview();
        }
      } catch (e) {
        debugPrint('[AgoraService] Enable video error: $e');
      }
    }
  }

  /// Switch between front and rear cameras
  Future<void> switchCamera() async {
    if (_engine != null) {
      try {
        await _engine!.switchCamera();
      } catch (e) {
        debugPrint('[AgoraService] Switch camera error: $e');
      }
    }
  }

  /// Join an audio-only channel with token, channel name, and numeric UID
  Future<AgoraJoinResult> joinAudioChannel({
    required String token,
    required String channelName,
    required int uid,
    String? callId,
    DateTime? tokenExpiry,
  }) =>
      joinChannel(
        token: token,
        channelName: channelName,
        uid: uid,
        callType: CallType.audio,
        callId: callId,
        tokenExpiry: tokenExpiry,
      );

  /// Mute local microphone
  Future<void> muteMicrophone() => muteLocalAudio(true);

  /// Unmute local microphone
  Future<void> unmuteMicrophone() => muteLocalAudio(false);

  /// Enable device speakerphone
  Future<void> enableSpeaker() => enableSpeakerphone(true);

  /// Disable device speakerphone (route to earpiece)
  Future<void> disableSpeaker() => enableSpeakerphone(false);

  /// Enable or disable device speakerphone
  Future<void> enableSpeakerphone(bool enable) async {
    if (_engine != null) {
      try {
        await _engine!.setEnableSpeakerphone(enable);
      } catch (e) {
        debugPrint('[AgoraService] Set speakerphone error: $e');
      }
    }
  }

  /// Leave the active channel
  Future<void> leaveChannel() async {
    _isJoining = false;
    if (_engine != null && (_isJoined || _currentChannel != null)) {
      try {
        await _engine!.stopPreview();
        await _engine!.leaveChannel();
        _isJoined = false;
        _remoteUid = null;
        _currentChannel = null;
        _currentCallType = null;
        debugPrint('[AgoraService] Left channel successfully.');
      } catch (e) {
        debugPrint('[AgoraService] Leave channel error: $e');
      }
    } else {
      _isJoined = false;
      _remoteUid = null;
      _currentChannel = null;
      _currentCallType = null;
    }
  }

  /// Dispose and release the engine instance
  Future<void> dispose() async {
    await leaveChannel();
    if (_engine != null) {
      try {
        await _engine!.release();
        _engine = null;
        _isInitialized = false;
        debugPrint('[AgoraService] Engine released.');
      } catch (e) {
        debugPrint('[AgoraService] Release engine error: $e');
      }
    }
  }
}
