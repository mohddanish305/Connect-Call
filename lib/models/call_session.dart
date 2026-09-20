import '../services/network_quality_service.dart';
import 'call_model.dart';

class CallSession {
  final CallModel? call;
  final bool isMuted;
  final bool isCameraOff;
  final bool isRemoteCameraOff;
  final bool isSpeakerOn;
  final bool isFrontCamera;
  final int durationSeconds;
  final CallStatus status;
  final String? errorMessage;
  final bool isLocalPreviewReady;
  final bool isRemoteStreamReady;
  final int? localUid;
  final int? remoteUid;
  final NetworkCallQuality networkQuality;

  // Section 20 convenience getters
  bool get isCameraEnabled => !isCameraOff;
  bool get isLocalVideoReady => !isCameraOff && isLocalPreviewReady;
  bool get isRemoteVideoReady => isRemoteStreamReady && !isRemoteCameraOff;
  int? get remoteUserId => remoteUid;

  const CallSession({
    this.call,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isRemoteCameraOff = false,
    this.isSpeakerOn = false,
    this.isFrontCamera = true,
    this.durationSeconds = 0,
    this.status = CallStatus.ended,
    this.errorMessage,
    this.isLocalPreviewReady = false,
    this.isRemoteStreamReady = false,
    this.localUid,
    this.remoteUid,
    this.networkQuality = NetworkCallQuality.good,
  });

  CallSession copyWith({
    CallModel? call,
    bool? isMuted,
    bool? isCameraOff,
    bool? isRemoteCameraOff,
    bool? isSpeakerOn,
    bool? isFrontCamera,
    int? durationSeconds,
    CallStatus? status,
    String? errorMessage,
    bool? isLocalPreviewReady,
    bool? isRemoteStreamReady,
    int? localUid,
    int? remoteUid,
    NetworkCallQuality? networkQuality,
    bool clearError = false,
  }) {
    return CallSession(
      call: call ?? this.call,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isRemoteCameraOff: isRemoteCameraOff ?? this.isRemoteCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLocalPreviewReady: isLocalPreviewReady ?? this.isLocalPreviewReady,
      isRemoteStreamReady: isRemoteStreamReady ?? this.isRemoteStreamReady,
      localUid: localUid ?? this.localUid,
      remoteUid: remoteUid ?? this.remoteUid,
      networkQuality: networkQuality ?? this.networkQuality,
    );
  }
}
