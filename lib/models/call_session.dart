import 'call_model.dart';

class CallSession {
  final CallModel? call;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isFrontCamera;
  final int durationSeconds;
  final CallStatus status;
  final String? errorMessage;
  final bool isLocalPreviewReady;
  final bool isRemoteStreamReady;

  const CallSession({
    this.call,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = false,
    this.isFrontCamera = true,
    this.durationSeconds = 0,
    this.status = CallStatus.ended,
    this.errorMessage,
    this.isLocalPreviewReady = false,
    this.isRemoteStreamReady = false,
  });

  CallSession copyWith({
    CallModel? call,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    bool? isFrontCamera,
    int? durationSeconds,
    CallStatus? status,
    String? errorMessage,
    bool? isLocalPreviewReady,
    bool? isRemoteStreamReady,
    bool clearError = false,
  }) {
    return CallSession(
      call: call ?? this.call,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLocalPreviewReady: isLocalPreviewReady ?? this.isLocalPreviewReady,
      isRemoteStreamReady: isRemoteStreamReady ?? this.isRemoteStreamReady,
    );
  }
}
