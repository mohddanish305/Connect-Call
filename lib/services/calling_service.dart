import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/config/agora_debug_config.dart';
import '../core/config/app_config.dart';
import '../core/models/call_history_model.dart' show CallHistoryStatus;
import '../core/services/agora_service.dart';
import '../core/services/agora_token_client.dart';
import '../core/services/network_service.dart';
import '../models/call_model.dart';
import '../models/call_session.dart';
import 'block_service.dart';
import 'call_history_service.dart';
import 'call_signaling_service.dart';
import 'network_quality_service.dart';
import 'notification_service.dart';

typedef CallSessionCallback = void Function(CallSession session);

/// Service coordinating Firebase Authentication, Cloud Firestore Signaling, and Agora RTC Engine
/// Hardened for reliability, network detection, state consistency, and error handling.
class CallingService {
  final AgoraService agoraService;
  final AgoraTokenClient _tokenClient;
  final CallSignalingService _signalingService;
  final CallHistoryService _callHistoryService;
  final NetworkService _networkService;

  CallSession _currentSession = const CallSession();
  CallSession get currentSession => _currentSession;

  CallSessionCallback? onSessionChanged;
  Timer? _durationTimer;
  Timer? _ringingTimeoutTimer;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer;
  StreamSubscription<CallModel?>? _callDocSubscription;
  bool _isDisposed = false;
  bool _isConnectingAgora = false;
  String? _connectingCallId;
  final Set<String> _recordedCallIds = {};
  ConnectionStateType _lastConnectionState = ConnectionStateType.connectionStateDisconnected;

  /// Ringing timeout in seconds before marking a call as missed (Section 14 & 23)
  static const int ringingTimeoutSeconds = 30;

  /// Reconnection timeout in seconds before marking a call as failed (Section 9)
  static const int reconnectTimeoutSeconds = 25;

  /// Connection timeout in seconds before marking a call as failed (Phase 4)
  static const int connectionTimeoutSeconds = 25;

  CallingService({
    required this.agoraService,
    AgoraTokenClient? tokenClient,
    CallSignalingService? signalingService,
    required CallHistoryService historyService,
    NetworkService? networkService,
  })  : _tokenClient = tokenClient ?? AgoraTokenClient(),
        _signalingService = signalingService ?? CallSignalingService(),
        _callHistoryService = historyService,
        _networkService = networkService ?? NetworkService() {
    _bindAgoraEvents();
  }

  void _bindAgoraEvents() {
    agoraService.onJoinChannelSuccess = (channel, uid) {
      debugPrint('[CallingService] Agora channel joined: $channel (local uid: $uid)');
      final isCaller = _currentSession.call?.callerId == FirebaseAuth.instance.currentUser?.uid;
      final role = isCaller ? 'caller' : 'receiver';
      debugPrint('[CALL FLOW] callId=${_currentSession.call?.id} role=$role step=LOCAL_JOINED timestamp=${DateTime.now().toIso8601String()}');
      if (isCaller) {
        debugPrint('[AGORA DEBUG A]\nonJoinChannelSuccess: true');
      } else {
        debugPrint('[AGORA DEBUG B]\nonJoinChannelSuccess: true');
      }
      _updateSession(_currentSession.copyWith(
        localUid: uid,
        isLocalPreviewReady: true,
      ));
    };

    agoraService.onUserMuteVideo = (remoteUid, muted) {
      debugPrint('[CallingService] Remote user $remoteUid muted video: $muted');
      if (_currentSession.remoteUid == remoteUid) {
        _updateSession(_currentSession.copyWith(
          isRemoteCameraOff: muted,
        ));
      }
    };

    agoraService.onNetworkQuality = (uid, txQuality, rxQuality) {
      if (uid == 0 || uid == _currentSession.localUid) {
        final mapped = NetworkQualityService.fromAgoraQuality(txQuality);
        if (mapped != _currentSession.networkQuality && mapped != NetworkCallQuality.unknown) {
          debugPrint('[CallingService] Network quality updated: ${mapped.label}');
          _updateSession(_currentSession.copyWith(networkQuality: mapped));
        }
      }
    };

    agoraService.onUserJoined = (remoteUid) {
      debugPrint('[AGORA REMOTE JOIN] remoteUid=$remoteUid');
      debugPrint('[CallingService] Remote user joined Agora: $remoteUid');
      final call = _currentSession.call;

      // Section 25: Remote user validation to prevent arbitrary participants from intercepting
      int? expectedRemoteUid;
      if (call != null) {
        final isCaller = _currentSession.localUid == getDeterministicAgoraUid(call.callerId);
        final expectedUserId = isCaller ? call.receiverId : call.callerId;
        expectedRemoteUid = getDeterministicAgoraUid(expectedUserId);
      }

      final isCaller = _currentSession.localUid == getDeterministicAgoraUid(call?.callerId ?? '');
      final role = isCaller ? 'caller' : 'receiver';
      debugPrint('[CALL FLOW] callId=${call?.id} role=$role step=REMOTE_JOINED timestamp=${DateTime.now().toIso8601String()}');
      debugPrint('[CALL FLOW] callId=${call?.id} role=$role step=CONNECTED timestamp=${DateTime.now().toIso8601String()}');
      debugPrint('[AGORA REMOTE USER]\ncallId: ${call?.id}\nlocalAgoraUid: ${_currentSession.localUid}\nremoteAgoraUid: $remoteUid\nchannelName: ${call?.channelName}');

      if (AgoraDebugConfig.useTemporaryToken ||
          expectedRemoteUid == null ||
          remoteUid == expectedRemoteUid) {
        _ringingTimeoutTimer?.cancel();
        _connectionTimeoutTimer?.cancel();
        _reconnectTimer?.cancel();
        _updateSession(_currentSession.copyWith(
          remoteUid: remoteUid,
          isRemoteStreamReady: true,
          status: CallStatus.connected,
          clearError: true,
        ));
        _transitionToInCall();
      } else {
        debugPrint('[CallingService] Notice: Participant $remoteUid joined (expected: $expectedRemoteUid).');
      }
    };

    agoraService.onRemoteVideoStateChanged = (remoteUid, state) {
      debugPrint('[CallingService] onRemoteVideoStateChanged: remoteUid=$remoteUid, state=$state');
      if (state == RemoteVideoState.remoteVideoStateDecoding ||
          state == RemoteVideoState.remoteVideoStateStarting) {
        if (_currentSession.remoteUid == remoteUid || _currentSession.remoteUid == null) {
          _updateSession(_currentSession.copyWith(
            remoteUid: remoteUid,
            isRemoteCameraOff: false,
            isRemoteStreamReady: true,
            status: CallStatus.inCall,
          ));
        }
      } else if (state == RemoteVideoState.remoteVideoStateStopped) {
        if (_currentSession.remoteUid == remoteUid) {
          _updateSession(_currentSession.copyWith(
            isRemoteCameraOff: true,
          ));
        }
      }
    };

    agoraService.onUserOffline = (remoteUid, reason) {
      debugPrint('[CallingService] Remote user left Agora: $remoteUid (reason: $reason)');
      _updateSession(_currentSession.copyWith(
        isRemoteStreamReady: false,
        status: CallStatus.disconnected,
        errorMessage: 'The other user has disconnected.',
      ));
      _handleCallTermination(
        historyStatus: CallHistoryStatus.completed,
        reason: 'The other user has disconnected.',
        source: 'remote_user',
      );
    };

    agoraService.onConnectionStateChanged = (state, reason) {
      _lastConnectionState = state;
      debugPrint('[CallingService] Agora connection: $state, reason: $reason');
      if (state == ConnectionStateType.connectionStateConnecting) {
        if (_currentSession.status != CallStatus.inCall) {
          _updateSession(_currentSession.copyWith(
            status: CallStatus.connecting,
          ));
        }
      } else if (state == ConnectionStateType.connectionStateConnected) {
        _connectionTimeoutTimer?.cancel();
        _reconnectTimer?.cancel();
        _updateSession(_currentSession.copyWith(
          status: _currentSession.remoteUid != null ? CallStatus.inCall : CallStatus.connected,
          clearError: true,
        ));
      } else if (state == ConnectionStateType.connectionStateReconnecting) {
        _updateSession(_currentSession.copyWith(
          status: CallStatus.reconnecting,
          errorMessage: 'Reconnecting...',
        ));
        _startReconnectTimeoutTimer();
      } else if (state == ConnectionStateType.connectionStateFailed) {
        // Phase 4: Do not treat temporary connection states as immediate fatal errors.
        // Only fail immediately for genuine unrecoverable errors.
        final isUnrecoverable = reason == ConnectionChangedReasonType.connectionChangedInvalidToken ||
            reason == ConnectionChangedReasonType.connectionChangedTokenExpired ||
            reason == ConnectionChangedReasonType.connectionChangedInvalidAppId ||
            reason == ConnectionChangedReasonType.connectionChangedBannedByServer ||
            reason == ConnectionChangedReasonType.connectionChangedRejectedByServer;

        if (isUnrecoverable) {
          _connectionTimeoutTimer?.cancel();
          _reconnectTimer?.cancel();
          _updateSession(_currentSession.copyWith(
            status: CallStatus.failed,
            errorMessage: 'Call authentication failed. Please check your credentials.',
          ));
          debugPrint('[FAIL SOURCE] method=onConnectionStateChanged\n[FAIL SOURCE] status=${CallHistoryStatus.failed.name}\n[FAIL SOURCE] reason=Call authentication failed ($reason).\n[FAIL SOURCE] callId=${_currentSession.call?.id}');
          debugPrint('[CALL TERMINATION TRIGGER] location: ConnectionStateType.connectionStateFailed (unrecoverable: $reason)');
          _handleCallTermination(
            historyStatus: CallHistoryStatus.failed,
            reason: 'Call authentication failed ($reason).',
            source: 'agora_error',
          );
        } else {
          debugPrint('[CallingService] Notice: Temporary Agora connectionStateFailed (reason: $reason). Awaiting reconnection or scoped connection timeout.');
        }
      }
    };

    agoraService.onTokenPrivilegeWillExpire = (token) async {
      debugPrint('[CallingService] Agora RTC token expiring soon. Requesting renewal...');
      final call = _currentSession.call;
      final localUid = _currentSession.localUid;
      if (call != null && localUid != null) {
        try {
          final res = await requestAgoraToken(
            channelName: call.channelName,
            uid: localUid,
          );
          await agoraService.renewToken(res.token);
          debugPrint('[CallingService] Agora token renewed successfully.');
        } catch (e) {
          debugPrint('[CallingService] Failed to renew Agora token: $e');
          _updateSession(_currentSession.copyWith(
            errorMessage: 'Your call session expired.',
          ));
          debugPrint('[FAIL SOURCE] method=onTokenPrivilegeWillExpire\n[FAIL SOURCE] status=${CallHistoryStatus.failed.name}\n[FAIL SOURCE] reason=Your call session expired.\n[FAIL SOURCE] callId=${call.id}');
          debugPrint('[CALL TERMINATION TRIGGER] location: onTokenPrivilegeWillExpire renew exception: $e');
          await _handleCallTermination(
            historyStatus: CallHistoryStatus.failed,
            reason: 'Your call session expired.',
          );
        }
      }
    };

    agoraService.onError = (err, msg) {
      debugPrint('[CallingService] Agora error: $err, $msg');
      if (err == ErrorCodeType.errTokenExpired || err == ErrorCodeType.errInvalidToken) {
        _updateSession(_currentSession.copyWith(
          errorMessage: 'Your call session expired.',
        ));
        debugPrint('[FAIL SOURCE] method=onError\n[FAIL SOURCE] status=${CallHistoryStatus.failed.name}\n[FAIL SOURCE] reason=Your call session expired.\n[FAIL SOURCE] callId=${_currentSession.call?.id}');
        debugPrint('[CALL TERMINATION TRIGGER] location: onError ($err, $msg)');
        _handleCallTermination(
          historyStatus: CallHistoryStatus.failed,
          reason: 'Your call session expired.',
        );
      }
    };
  }

  void _startConnectionTimeoutTimer(String callId) {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(const Duration(seconds: connectionTimeoutSeconds), () async {
      if (_currentSession.call?.id == callId &&
          (_currentSession.status == CallStatus.connecting ||
           _currentSession.status == CallStatus.accepted ||
           _currentSession.status == CallStatus.calling ||
           _currentSession.status == CallStatus.ringing)) {
        debugPrint('[CallingService] Call $callId connection timed out after $connectionTimeoutSeconds seconds.');
        debugPrint('[FAIL SOURCE] method=_startConnectionTimeoutTimer\n[FAIL SOURCE] status=${CallHistoryStatus.failed.name}\n[FAIL SOURCE] reason=Call connection timed out.\n[FAIL SOURCE] callId=$callId');
        debugPrint('[CALL TERMINATION TRIGGER] location: _startConnectionTimeoutTimer');
        await _handleCallTermination(
          historyStatus: CallHistoryStatus.failed,
          reason: 'Call connection timed out.',
          source: 'timeout',
        );
      }
    });
  }

  void _startReconnectTimeoutTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: reconnectTimeoutSeconds), () async {
      if (_currentSession.status == CallStatus.reconnecting) {
        debugPrint('[CallingService] Reconnection timed out after $reconnectTimeoutSeconds seconds.');
        debugPrint('[FAIL SOURCE] method=_startReconnectTimeoutTimer\n[FAIL SOURCE] status=${CallHistoryStatus.failed.name}\n[FAIL SOURCE] reason=Call disconnected due to network failure.\n[FAIL SOURCE] callId=${_currentSession.call?.id}');
        debugPrint('[CALL TERMINATION TRIGGER] location: _startReconnectTimeoutTimer');
        await _handleCallTermination(
          historyStatus: CallHistoryStatus.failed,
          reason: 'Call disconnected due to network failure.',
        );
      }
    });
  }

  void _updateSession(CallSession session) {
    if (_isDisposed) return;
    _currentSession = session;
    onSessionChanged?.call(_currentSession);
  }

  /// Deterministically derives a stable positive 32-bit integer Agora UID for any Firebase UID.
  /// Section 7: Same user always uses the exact same numeric UID across calls.
  static int getDeterministicAgoraUid(String userId) {
    if (userId.isEmpty) return 10001;
    int hash = 2166136261;
    for (final unit in userId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7FFFFFFF;
    }
    return 10000 + (hash % 2147400000);
  }

  /// Request a short-lived Agora RTC token from backend
  Future<AgoraTokenResponse> requestAgoraToken({
    required String channelName,
    required int uid,
    String? firebaseIdToken,
  }) async {
    // Isolated Debug Mode: Bypass backend token fetch if temporary token testing is enabled
    if (AgoraDebugConfig.useTemporaryToken) {
      final effectiveChannel = (AgoraDebugConfig.temporaryChannelName.isNotEmpty &&
              AgoraDebugConfig.temporaryChannelName != 'PASTE_CHANNEL_NAME_HERE')
          ? AgoraDebugConfig.temporaryChannelName
          : channelName;
      final effectiveUid = AgoraDebugConfig.temporaryUid ?? uid;
      final cleanToken = AgoraDebugConfig.temporaryToken.trim();
      final bool tokenLoaded = cleanToken.isNotEmpty &&
          cleanToken != 'PASTE_TEMP_TOKEN_HERE';

      debugPrint('[TEMP AGORA] Temporary token mode ENABLED');
      debugPrint('[TEMP AGORA] channel=$effectiveChannel');
      debugPrint('[TEMP AGORA] uid=$effectiveUid');
      debugPrint('[TEMP AGORA] token loaded=$tokenLoaded');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] token source: AgoraDebugConfig (temporary)');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] channel used by app: $effectiveChannel');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] numeric UID used by app: $effectiveUid');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] whether token is present: $tokenLoaded');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] token string length: ${cleanToken.length}');
      debugPrint('[AGORA TOKEN DIAGNOSTIC] token configuration: channel="${AgoraDebugConfig.temporaryChannelName}", uid=${AgoraDebugConfig.temporaryUid ?? "wildcard (any)"}');

      if (!tokenLoaded) {
        throw const CallingServiceException(
          'Temporary token mode is enabled but no temporary token was configured. Please set temporaryToken in agora_debug_config.dart.',
          statusCode: 500,
        );
      }

      final effectiveAppId = (AgoraDebugConfig.temporaryAppId.isNotEmpty &&
              AgoraDebugConfig.temporaryAppId != 'PASTE_APP_ID_HERE')
          ? AgoraDebugConfig.temporaryAppId
          : AppConfig.agoraAppId;

      return AgoraTokenResponse(
        token: cleanToken,
        appId: effectiveAppId,
        channelName: effectiveChannel,
        uid: effectiveUid,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        httpStatus: 200,
      );
    }

    final fbUser = FirebaseAuth.instance.currentUser;
    final bool hasFbUser = fbUser != null;
    final String? userUid = fbUser?.uid;

    debugPrint('[Identity E] Agora token request authenticated Firebase UID: $userUid');

    String? token = firebaseIdToken;
    if (token == null && hasFbUser) {
      try {
        token = await fbUser.getIdToken(false).timeout(const Duration(seconds: 15));
      } catch (cachedErr) {
        debugPrint('[CallingService] Error obtaining cached Firebase ID token: $cachedErr');
        try {
          token = await fbUser.getIdToken(true).timeout(const Duration(seconds: 15));
        } catch (forceErr) {
          debugPrint('[CallingService] Fallback forced refresh failed: $forceErr');
        }
      }
    }

    final bool tokenObtained = token != null && token.isNotEmpty;
    debugPrint('[CallingService] Requesting token - Endpoint: /api/agora/token | currentUser exists: $hasFbUser | UID: $userUid | ID token obtained: $tokenObtained');

    if (token == null || token.isEmpty) {
      throw const CallingServiceException(
        'Authentication required. Please sign in to make calls.',
        statusCode: 401,
      );
    }

    try {
      return await _tokenClient.fetchToken(
        channelName: channelName,
        uid: uid,
        firebaseIdToken: token,
      );
    } on CallingServiceException catch (e) {
      if (e.statusCode == 401 && hasFbUser) {
        debugPrint('[CallingService] Backend returned 401. Performing ONE forced token refresh and single retry...');
        try {
          final refreshedToken = await fbUser.getIdToken(true).timeout(const Duration(seconds: 15));
          if (refreshedToken != null && refreshedToken.isNotEmpty) {
            return await _tokenClient.fetchToken(
              channelName: channelName,
              uid: uid,
              firebaseIdToken: refreshedToken,
            );
          }
        } catch (retryErr) {
          debugPrint('[CallingService] Token retry after 401 failed: $retryErr');
        }
      }
      rethrow;
    }
  }

  /// Start an outgoing 1-to-1 audio call
  Future<bool> startAudioCall(CallModel call, {String? firebaseIdToken}) {
    return startCall(
      call.copyWith(callType: CallType.audio),
      firebaseIdToken: firebaseIdToken,
    );
  }

  /// Start an outgoing call (Audio or Video).
  /// Enforces Sections 7, 15, 16, 21, 22:
  /// 1. Network check
  /// 2. Active call / busy checks
  /// 3. Firestore call document creation FIRST
  /// 4. Backend Agora token fetch
  /// 5. Agora channel join
  Future<bool> startCall(CallModel call, {String? firebaseIdToken}) async {
    debugPrint('[CALL TRACE] START (callId: ${call.id}, caller: ${call.callerId}, receiver: ${call.receiverId})');
    try {
      final fbAuthUser = FirebaseAuth.instance.currentUser;
      debugPrint('[Identity A] FirebaseAuth.currentUser.uid: ${fbAuthUser?.uid}');
      debugPrint('[Identity B] CallSignalingService callerId: ${call.callerId}');
      debugPrint('[Identity C] calls/${call.id}.callerId: ${call.callerId}');
      debugPrint('[Identity D] calls/${call.id}.receiverId: ${call.receiverId}');

      // Prevent calling self
      if (call.callerId == call.receiverId) {
        debugPrint('[CALL TRACE] startCall blocked: attempted to call self (${call.callerId})');
        _updateSession(_currentSession.copyWith(
          status: CallStatus.failed,
          errorMessage: 'You cannot call yourself.',
        ));
        return false;
      }

      // 1. Section 7: Network connectivity pre-flight check
      debugPrint('[CALL TRACE] network check START');
      final hasNet = await _networkService.hasInternetConnection();
      debugPrint('[CALL TRACE] network check END: hasNet=$hasNet');
      if (!hasNet) {
        debugPrint('[CALL TRACE] startCall failed at network check');
        _updateSession(_currentSession.copyWith(
          status: CallStatus.failed,
          errorMessage: NetworkService.noInternetMessage,
        ));
        return false;
      }

      // Blocked User Check: verify caller has not blocked the receiver and receiver has not blocked caller
      final blockService = BlockService();
      final isBlockedByCaller = await blockService.isUserBlocked(
        currentUserId: call.callerId,
        targetUserId: call.receiverId,
      );
      if (isBlockedByCaller) {
        debugPrint('[CALL TRACE] startCall blocked: caller has blocked receiver');
        _updateSession(_currentSession.copyWith(
          status: CallStatus.failed,
          errorMessage: 'You have blocked this user.',
        ));
        return false;
      }

      final isBlockedByReceiver = await blockService.isBlockedByTarget(
        currentUserId: call.callerId,
        targetUserId: call.receiverId,
      );
      if (isBlockedByReceiver) {
        debugPrint('[CALL TRACE] startCall blocked: receiver has blocked caller');
        _updateSession(_currentSession.copyWith(
          status: CallStatus.failed,
          errorMessage: 'User is unavailable.',
        ));
        return false;
      }

      // 2. Section 16: Check if caller already has an active call
      debugPrint('[CALL TRACE] 04 active call check START (caller: ${call.callerId})');
      final callerActive = await _signalingService.getActiveCallForUser(call.callerId);
      debugPrint('[CALL TRACE] 05 active call check END result=${callerActive?.id}');
      if (callerActive != null && callerActive.id != call.id) {
        debugPrint('[CALL TRACE] startCall blocked: caller already in active call ${callerActive.id}');
        _updateSession(_currentSession.copyWith(
          status: CallStatus.failed,
          errorMessage: 'You already have an active call.',
        ));
        return false;
      }

      // 3. Section 16: Check if callee is busy on another call
      debugPrint('[CALL TRACE] busy check START (receiver: ${call.receiverId})');
      final isReceiverBusy = await _signalingService.isUserBusy(call.receiverId);
      debugPrint('[CALL TRACE] busy check END (isReceiverBusy: $isReceiverBusy)');
      if (isReceiverBusy) {
        debugPrint('[CALL TRACE] startCall blocked: receiver is busy');
        _updateSession(_currentSession.copyWith(
          status: CallStatus.busy,
          errorMessage: 'This user is currently on another call.',
        ));
        return false;
      }

      final uid = getDeterministicAgoraUid(call.callerId);

      debugPrint('[CALL FLOW] callId=${call.id} role=caller step=START_CALL timestamp=${DateTime.now().toIso8601String()}');
      _updateSession(CallSession(
        call: call,
        status: CallStatus.calling,
        isFrontCamera: true,
        isMuted: false,
        isCameraOff: call.callType == CallType.audio,
        isSpeakerOn: false,
        localUid: uid,
      ));

      // 4. Create Firestore call document FIRST before joining Agora
      try {
        debugPrint('[CALL OUTGOING]\ncallerUid: ${call.callerId}\nreceiverUid: ${call.receiverId}\ncallId: ${call.id}\ncallType: ${call.callType.name}\nchannelName: ${call.channelName}');
        debugPrint('[CALL TRACE] 06 create call START');
        await _signalingService.createCall(call);
        debugPrint('[CALL FLOW] callId=${call.id} role=caller step=CALL_DOC_CREATED timestamp=${DateTime.now().toIso8601String()}');
        debugPrint('[CALL TRACE] 07 create call END callId=${call.id}');
        _updateSession(_currentSession.copyWith(status: CallStatus.ringing));

        // Dispatch background/push notification to callee via secure backend flow
        NotificationService().sendCallPushNotification(
          callerId: call.callerId,
          callerName: call.callerName,
          receiverId: call.receiverId,
          callId: call.id,
          callType: call.callType,
          channelName: call.channelName,
        );
      } catch (firestoreError) {
        debugPrint('[CALL TRACE] create call EXCEPTION: $firestoreError');
        debugPrint('[CallingService] Firestore call creation failed: $firestoreError');
        final errMessage = firestoreError is CallingServiceException
            ? firestoreError.message
            : 'Unable to start the call. Please check your connection and try again.';
        _updateSession(_currentSession.copyWith(
          status: CallStatus.failed,
          errorMessage: errMessage,
        ));
        await _cleanupMedia();
        return false;
      }

      // 5. Subscribe to Firestore call signaling updates
      debugPrint('[CALL TRACE] subscribe call signaling START');
      _listenToCallSignaling(call.id);
      debugPrint('[CALL TRACE] subscribe call signaling END');

      // 6. 30-Second Ringing Timeout
      _startRingingTimeoutTimer(call.id);

      // 7. Note: Agora connection will be started after navigation to the CallScreen via connectAgoraForCaller()
      debugPrint('[CALL FLOW] callId=${call.id} role=caller step=CALLING_SCREEN_OPENED timestamp=${DateTime.now().toIso8601String()}');
      debugPrint('[CALL TRACE] startCall document created and ringing timer started; awaiting CallScreen mount for Agora connection');

      return true;
    } catch (e) {
      debugPrint('[CALL TRACE] startCall outer EXCEPTION: $e');
      debugPrint('[CallingService] startCall error: $e');
      final String userMessage;
      if (e is CallingServiceException) {
        userMessage = e.message;
      } else {
        final errStr = e.toString();
        if (errStr.contains('Authentication required') || errStr.contains('session has expired')) {
          userMessage = 'Your session has expired. Please sign in again.';
        } else if (errStr.contains('No internet') || errStr.contains('network')) {
          userMessage = NetworkService.noInternetMessage;
        } else {
          userMessage = 'Unable to reach calling service. Check your connection and try again.';
        }
      }

      // Pre-flight setup aborted: clear session and media without logging fake call history
      _updateSession(_currentSession.copyWith(
        status: CallStatus.failed,
        errorMessage: userMessage,
      ));
      await _cleanupMedia();
      return false;
    }
  }

  Future<void> _connectAgoraForCall(
    CallModel call,
    int uid, {
    String? firebaseIdToken,
    bool isIncoming = false,
  }) async {
    if (_isConnectingAgora || agoraService.isJoined || agoraService.isJoining) {
      debugPrint('[CallingService] _connectAgoraForCall skipped: already connecting or joined (isIncoming: $isIncoming)');
      return;
    }
    _isConnectingAgora = true;
    _connectingCallId = call.id;

    final tracePrefix = isIncoming ? '[INCOMING TRACE]' : '[CALL TRACE]';
    debugPrint('$tracePrefix _connectAgoraForCall START (callId: ${call.id}, agoraUid: $uid, isIncoming: $isIncoming)');
    int httpStatus = 0;
    bool tokenReceived = false;
    bool engineInitialized = false;
    bool joinChannelCalled = false;
    bool joinResultSuccess = false;

    // Start Phase 4 scoped connection timeout
    _startConnectionTimeoutTimer(call.id);

    try {
      // Task 13: Microphone permission check prior to joinChannel
      debugPrint('$tracePrefix mic permission check START');
      final micGranted = await Permission.microphone.isGranted;
      debugPrint('$tracePrefix mic permission check END: micGranted=$micGranted');
      debugPrint('[AGORA PERMISSION]\nmicrophonePermission: ${micGranted ? "granted" : "denied"}');
      if (!micGranted) {
        throw CallingServiceException(
          isIncoming
              ? 'Microphone permission is required to accept calls. Please enable it in Settings.'
              : 'Microphone permission is required to make calls. Please enable it in Settings.',
          statusCode: 403,
        );
      }

      if (isIncoming) {
        _updateSession(_currentSession.copyWith(
          status: CallStatus.connecting,
          localUid: uid,
        ));
      }

      final role = isIncoming ? 'receiver' : 'caller';
      debugPrint('[CALL FLOW] callId=${call.id} role=$role step=TOKEN_REQUEST_START timestamp=${DateTime.now().toIso8601String()}');
      debugPrint('$tracePrefix token request START');
      final tokenResponse = await requestAgoraToken(
        channelName: call.channelName,
        uid: uid,
        firebaseIdToken: firebaseIdToken,
      );
      httpStatus = tokenResponse.httpStatus;
      tokenReceived = tokenResponse.token.isNotEmpty;
      debugPrint('[CALL FLOW] callId=${call.id} role=$role step=TOKEN_RECEIVED timestamp=${DateTime.now().toIso8601String()}');
      debugPrint('[AGORA FLOW]\ncallId=${call.id}\nchannel=${call.channelName}\nuid=$uid\ntokenPresent=$tokenReceived\ntokenLength=${tokenResponse.token.length}\ntokenExpiry=${tokenResponse.expiresAt.toIso8601String()}\nrole=$role');
      debugPrint('$tracePrefix token request END success=$tokenReceived (status: $httpStatus)');

      if (!tokenReceived) {
        throw const CallingServiceException(
          'Failed to generate Agora token. Please ensure AGORA_APP_CERTIFICATE is configured with your 32-character Primary Certificate in backend/.env.',
          statusCode: 500,
        );
      }

      final effectiveAppId = tokenResponse.appId.isNotEmpty &&
              !tokenResponse.appId.contains('<') &&
              tokenResponse.appId.trim().length == 32
          ? tokenResponse.appId.trim()
          : (AgoraDebugConfig.temporaryAppId.isNotEmpty && AgoraDebugConfig.temporaryAppId.length == 32
              ? AgoraDebugConfig.temporaryAppId
              : AppConfig.agoraAppId);

      // Task 8: Verify App ID
      debugPrint('[AGORA APP ID]\nappId present: ${effectiveAppId.isNotEmpty}\nappId format valid: ${effectiveAppId.length == 32}');

      if (effectiveAppId.isNotEmpty) {
        debugPrint('[CALL FLOW] callId=${call.id} role=$role step=AGORA_INIT_START timestamp=${DateTime.now().toIso8601String()}');
        debugPrint('$tracePrefix Agora initialize START');
        engineInitialized = await agoraService.initialize(appId: effectiveAppId);
        debugPrint('$tracePrefix Agora initialize END: initialized=$engineInitialized');
        if (!engineInitialized) {
          final errMsg = agoraService.lastErrorMessage ?? 'Engine failed to initialize.';
          throw Exception('Agora engine initialization failed: $errMsg');
        }
        debugPrint('[CALL FLOW] callId=${call.id} role=$role step=AGORA_INIT_SUCCESS timestamp=${DateTime.now().toIso8601String()}');

        debugPrint('$tracePrefix Agora event handlers registered');
        joinChannelCalled = true;
        debugPrint('[AGORA JOIN]\ncallId: ${call.id}\nchannelName: ${call.channelName}\nlocalAgoraUid: $uid');
        debugPrint('[CALL FLOW] callId=${call.id} role=$role step=JOIN_CHANNEL_START timestamp=${DateTime.now().toIso8601String()}');
        debugPrint('$tracePrefix joinChannel START');
        final cleanToken = tokenResponse.token.trim();
        debugPrint('[AGORA TOKEN DIAGNOSTIC] token source: ${AgoraDebugConfig.useTemporaryToken ? "AgoraDebugConfig (temporary)" : "Backend Service"}');
        debugPrint('[AGORA TOKEN DIAGNOSTIC] channel used by app: ${call.channelName}');
        debugPrint('[AGORA TOKEN DIAGNOSTIC] numeric UID used by app: $uid');
        debugPrint('[AGORA TOKEN DIAGNOSTIC] whether token is present: ${cleanToken.isNotEmpty}');
        debugPrint('[AGORA TOKEN DIAGNOSTIC] token string length: ${cleanToken.length}');
        debugPrint('[AGORA TOKEN DIAGNOSTIC] token expiry: ${tokenResponse.expiresAt.toIso8601String()}');
        final joinResult = await agoraService.joinChannel(
          token: cleanToken,
          channelName: call.channelName,
          uid: uid,
          callType: call.callType,
          callId: call.id,
          tokenExpiry: tokenResponse.expiresAt,
        );
        joinResultSuccess = joinResult.success;
        debugPrint('$tracePrefix joinChannel END: success=$joinResultSuccess');
        if (joinResultSuccess) {
          debugPrint('[CALL FLOW] callId=${call.id} role=$role step=JOIN_CHANNEL_SUCCESS timestamp=${DateTime.now().toIso8601String()}');
          debugPrint('$tracePrefix waiting for remote user');
        }

        final debugTag = isIncoming ? '[AGORA DEBUG B]' : '[AGORA DEBUG A]';
        debugPrint('$debugTag\ncallId: ${call.id}\nchannelName: ${call.channelName}\nfirebaseUid: ${FirebaseAuth.instance.currentUser?.uid}\nagoraUid: $uid\ntokenRequestHttpStatus: $httpStatus\ntokenReceived: $tokenReceived\nengineInitialized: $engineInitialized\njoinChannelCalled: $joinChannelCalled\njoinResult: $joinResultSuccess\nonJoinChannelSuccess: false (pending)');

        if (!joinResult.success) {
          final errInfo = joinResult.errorCode != null
              ? 'Error code: ${joinResult.errorCode} (${joinResult.errorMessage})'
              : (joinResult.errorMessage ?? 'Unknown Agora join failure');
          throw Exception('Agora joinChannel failed: $errInfo');
        }
      } else {
        throw Exception('Calling configuration is incomplete. Agora App ID missing.');
      }
    } catch (e) {
      debugPrint('$tracePrefix _connectAgoraForCall EXCEPTION: $e');
      debugPrint('[CallingService] _connectAgoraForCall error: $e');
      final debugTag = isIncoming ? '[AGORA DEBUG B]' : '[AGORA DEBUG A]';
      if (!joinResultSuccess) {
        debugPrint('$debugTag\ncallId: ${call.id}\nchannelName: ${call.channelName}\nfirebaseUid: ${FirebaseAuth.instance.currentUser?.uid}\nagoraUid: $uid\ntokenRequestHttpStatus: $httpStatus\ntokenReceived: $tokenReceived\nengineInitialized: $engineInitialized\njoinChannelCalled: $joinChannelCalled\njoinResult: $joinResultSuccess\nonJoinChannelSuccess: false');
      }

      final String userMessage;
      if (e is CallingServiceException) {
        userMessage = e.message;
      } else {
        final errStr = e.toString();
        if (errStr.contains('Authentication required') || errStr.contains('session has expired')) {
          userMessage = 'Your session has expired. Please sign in again.';
        } else if (errStr.contains('No internet') || errStr.contains('network')) {
          userMessage = NetworkService.noInternetMessage;
        } else {
          userMessage = 'Unable to connect to call. Please try again.';
        }
      }

      debugPrint('[FAIL SOURCE] method=_connectAgoraForCall\n[FAIL SOURCE] status=${CallHistoryStatus.failed.name}\n[FAIL SOURCE] reason=$userMessage\n[FAIL SOURCE] callId=${call.id}');
      debugPrint('[CALL TERMINATION TRIGGER] location: _connectAgoraForCall catch: $e (isIncoming: $isIncoming)');
      await _handleCallTermination(
        historyStatus: CallHistoryStatus.failed,
        reason: userMessage,
        source: 'agora_error',
      );
    } finally {
      _isConnectingAgora = false;
    }
  }

  void _startRingingTimeoutTimer(String callId) {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(const Duration(seconds: ringingTimeoutSeconds), () async {
      if (_currentSession.status == CallStatus.calling ||
          _currentSession.status == CallStatus.ringing) {
        debugPrint('[CallingService] Call $callId timed out after $ringingTimeoutSeconds seconds.');
        debugPrint('[FAIL SOURCE] method=_startRingingTimeoutTimer\n[FAIL SOURCE] status=${CallHistoryStatus.missed.name}\n[FAIL SOURCE] reason=No answer. Call missed.\n[FAIL SOURCE] callId=$callId');
        debugPrint('[CALL TERMINATION TRIGGER] location: _startRingingTimeoutTimer (ringing timeout after $ringingTimeoutSeconds s)');
        await _handleCallTermination(
          historyStatus: CallHistoryStatus.missed,
          reason: 'No answer. Call missed.',
          source: 'timeout',
        );
      }
    });
  }

  /// Receive an incoming call (notified by Firestore listener)
  void receiveIncomingCall(CallModel call) async {
    // Prevent duplicate triggers if already ringing for this call
    if (_currentSession.call?.id == call.id && _currentSession.status == CallStatus.ringing) {
      return;
    }

    // Check if caller is blocked by the receiver
    final blockService = BlockService();
    final isBlocked = await blockService.isUserBlocked(
      currentUserId: call.receiverId,
      targetUserId: call.callerId,
    );
    if (isBlocked) {
      debugPrint('[BLOCK DEBUG] receiveIncomingCall rejected: caller ${call.callerId} is blocked by receiver ${call.receiverId}');
      await _signalingService.updateCallStatus(call.id, CallStatus.rejected);
      return;
    }

    debugPrint('[CALL INCOMING]\nreceiverUid: ${call.receiverId}\ncallId: ${call.id}\nstatus: ${call.status.name}');
    debugPrint('[CALL FLOW] callId=${call.id} role=receiver step=INCOMING_CALL_RECEIVED timestamp=${DateTime.now().toIso8601String()}');

    _updateSession(CallSession(
      call: call.copyWith(direction: CallDirection.incoming),
      status: CallStatus.ringing,
      isSpeakerOn: false,
    ));
    _listenToCallSignaling(call.id);
  }

  /// Receiver accepts an incoming call (Section 15 Atomic Transaction)
  Future<bool> acceptCall({String? firebaseIdToken}) async {
    final call = _currentSession.call;
    if (call == null) return false;

    debugPrint('[CALL FLOW] callId=${call.id} role=receiver step=ACCEPT_PRESSED timestamp=${DateTime.now().toIso8601String()}');

    // Check network connectivity
    final hasNet = await _networkService.hasInternetConnection();
    if (!hasNet) {
      _updateSession(_currentSession.copyWith(
        status: CallStatus.failed,
        errorMessage: NetworkService.noInternetMessage,
      ));
      return false;
    }

    _ringingTimeoutTimer?.cancel();

    // 1. Transactional check: ensures call is still ringing and hasn't been ended or expired
    debugPrint('[CALL FLOW] callId=${call.id} role=receiver step=STATUS_UPDATE_START timestamp=${DateTime.now().toIso8601String()}');
    final canAccept = await _signalingService.acceptCallSafely(call.id);
    if (!canAccept) {
      debugPrint('[CallingService] acceptCall rejected: Call is no longer available.');
      _updateSession(_currentSession.copyWith(
        status: CallStatus.ended,
        errorMessage: 'This call is no longer available.',
      ));
      await _cleanupMedia();
      return false;
    }

    final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
    final uid = getDeterministicAgoraUid(currentAuthUid ?? call.calleeId);

    // Task 2: Trace Phone B incoming call accept metadata
    debugPrint('[CALL ACCEPT]\ncallId: ${call.id}\ncallerId: ${call.callerId}\nreceiverId: ${call.receiverId}\nchannelName: ${call.channelName}\nfirebaseUid: $currentAuthUid\nagoraUid: $uid');
    debugPrint('[CALL FLOW] callId=${call.id} role=receiver step=STATUS_ACCEPTED timestamp=${DateTime.now().toIso8601String()}');

    _updateSession(_currentSession.copyWith(
      status: CallStatus.accepted,
      localUid: uid,
    ));

    return true;
  }

  /// Asynchronously connect Agora media after caller has navigated to the call screen
  void connectAgoraForCaller({String? firebaseIdToken}) {
    final call = _currentSession.call;
    final uid = _currentSession.localUid ?? getDeterministicAgoraUid(FirebaseAuth.instance.currentUser?.uid ?? '');
    if (call != null &&
        _connectingCallId != call.id &&
        !_isConnectingAgora &&
        !agoraService.isJoined &&
        !agoraService.isJoining) {
      debugPrint('[CALL TRACE] connectAgoraForCaller connecting Agora (callId: ${call.id})');
      _connectingCallId = call.id;
      unawaited(_connectAgoraForCall(call, uid, firebaseIdToken: firebaseIdToken, isIncoming: false));
    } else {
      debugPrint('[CALL TRACE] connectAgoraForCaller skipped: already connected or connecting (callId: ${call?.id})');
    }
  }

  /// Asynchronously connect Agora media after receiver has navigated to the call screen
  void connectAgoraForReceiver({String? firebaseIdToken}) {
    final call = _currentSession.call;
    final uid = _currentSession.localUid ?? getDeterministicAgoraUid(FirebaseAuth.instance.currentUser?.uid ?? '');
    if (call != null &&
        _connectingCallId != call.id &&
        !_isConnectingAgora &&
        !agoraService.isJoined &&
        !agoraService.isJoining) {
      debugPrint('[CALL TRACE] connectAgoraForReceiver connecting Agora (callId: ${call.id}, uid: $uid)');
      _connectingCallId = call.id;
      unawaited(_connectAgoraForCall(call, uid, firebaseIdToken: firebaseIdToken, isIncoming: true));
    } else {
      debugPrint('[CALL TRACE] connectAgoraForReceiver skipped: already connected or connecting (callId: ${call?.id})');
    }
  }

  /// Receiver rejects incoming call (Section 16)
  Future<void> rejectCall() async {
    final call = _currentSession.call;
    if (call != null) {
      await _signalingService.rejectCallSafely(call.id);
    }
    debugPrint('[FAIL SOURCE] method=rejectCall\n[FAIL SOURCE] status=${CallHistoryStatus.rejected.name}\n[FAIL SOURCE] reason=Call declined.\n[FAIL SOURCE] callId=${call?.id}');
    debugPrint('[CALL TERMINATION TRIGGER] location: rejectCall');
    await _handleCallTermination(
      historyStatus: CallHistoryStatus.rejected,
      reason: 'Call declined.',
      source: 'local_user',
    );
  }

  /// Listen to real-time Firestore updates for the active call document
  void _listenToCallSignaling(String callId) {
    _callDocSubscription?.cancel();
    _callDocSubscription = _signalingService.streamCall(callId).listen((remoteCall) {
      if (remoteCall == null) return;
      // Phase 6: CallId-scoped state - Ignore stale snapshots from previous calls
      if (_currentSession.call?.id != callId || remoteCall.id != callId) {
        debugPrint('[CallingService] Stale signaling update ignored for callId: ${remoteCall.id} (current: ${_currentSession.call?.id})');
        return;
      }

      debugPrint('[CallingService] Firestore signaling update: ${remoteCall.status}');
      if (remoteCall.status == CallStatus.accepted &&
          (_currentSession.status == CallStatus.calling || _currentSession.status == CallStatus.ringing)) {
        _ringingTimeoutTimer?.cancel();
        // Caller transitions to connecting until Agora confirms remote user joined
        _updateSession(_currentSession.copyWith(status: CallStatus.accepted));
      } else if (remoteCall.status == CallStatus.rejected) {
        debugPrint('[FAIL SOURCE] method=_listenToCallSignaling(rejected)\n[FAIL SOURCE] status=${CallHistoryStatus.rejected.name}\n[FAIL SOURCE] reason=Call rejected by user.\n[FAIL SOURCE] callId=$callId');
        debugPrint('[CALL TERMINATION TRIGGER] location: _listenToCallSignaling (remoteCall.status == CallStatus.rejected)');
        _handleCallTermination(
          historyStatus: CallHistoryStatus.rejected,
          reason: 'Call rejected by user.',
          source: 'remote_user',
        );
      } else if (remoteCall.status == CallStatus.ended) {
        final isConnected = _currentSession.status == CallStatus.inCall ||
            _currentSession.status == CallStatus.connected;
        final termStatus = isConnected ? CallHistoryStatus.completed : CallHistoryStatus.missed;
        debugPrint('[FAIL SOURCE] method=_listenToCallSignaling(ended)\n[FAIL SOURCE] status=${termStatus.name}\n[FAIL SOURCE] reason=Call ended.\n[FAIL SOURCE] callId=$callId');
        debugPrint('[CALL TERMINATION TRIGGER] location: _listenToCallSignaling (remoteCall.status == CallStatus.ended)');
        _handleCallTermination(
          historyStatus: termStatus,
          reason: 'Call ended.',
          source: 'remote_user',
        );
      } else if (remoteCall.status == CallStatus.missed) {
        debugPrint('[FAIL SOURCE] method=_listenToCallSignaling(missed)\n[FAIL SOURCE] status=${CallHistoryStatus.missed.name}\n[FAIL SOURCE] reason=No answer. Call missed.\n[FAIL SOURCE] callId=$callId');
        debugPrint('[CALL TERMINATION TRIGGER] location: _listenToCallSignaling (remoteCall.status == CallStatus.missed)');
        _handleCallTermination(
          historyStatus: CallHistoryStatus.missed,
          reason: 'No answer. Call missed.',
          source: 'timeout',
        );
      } else if (remoteCall.status == CallStatus.failed) {
        debugPrint('[FAIL SOURCE] method=_listenToCallSignaling(failed)\n[FAIL SOURCE] status=${CallHistoryStatus.failed.name}\n[FAIL SOURCE] reason=Call connection failed on remote device.\n[FAIL SOURCE] callId=$callId');
        debugPrint('[CALL TERMINATION TRIGGER] location: _listenToCallSignaling (remoteCall.status == CallStatus.failed)');
        _handleCallTermination(
          historyStatus: CallHistoryStatus.failed,
          reason: 'Call connection failed on remote device.',
          source: 'remote_user',
        );
      }
    });
  }

  void _transitionToInCall() {
    _durationTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _updateSession(_currentSession.copyWith(status: CallStatus.inCall));
    _startDurationTimer();
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
    await agoraService.muteLocalAudio(nextMuted);
    _updateSession(_currentSession.copyWith(isMuted: nextMuted));
  }

  /// Toggle Speakerphone / Earpiece
  Future<void> toggleSpeaker([bool? forceState]) async {
    final nextSpeaker = forceState ?? !_currentSession.isSpeakerOn;
    await agoraService.enableSpeakerphone(nextSpeaker);
    _updateSession(_currentSession.copyWith(isSpeakerOn: nextSpeaker));
  }

  /// Toggle Camera On / Off (Section 11)
  Future<void> toggleCamera() async {
    final nextCameraOff = !_currentSession.isCameraOff;
    await agoraService.enableLocalVideo(!nextCameraOff);
    _updateSession(_currentSession.copyWith(isCameraOff: nextCameraOff));
  }

  /// Switch Camera Front / Rear (Section 12)
  Future<void> switchCamera() async {
    await agoraService.switchCamera();
    _updateSession(_currentSession.copyWith(
      isFrontCamera: !_currentSession.isFrontCamera,
    ));
  }

  /// End Call (Section 17 & 25)
  Future<void> endCall() async {
    final isConnected = _currentSession.status == CallStatus.inCall ||
        _currentSession.status == CallStatus.connected;
    final status = isConnected
        ? CallHistoryStatus.completed
        : CallHistoryStatus.missed;
    debugPrint('[FAIL SOURCE] method=endCall\n[FAIL SOURCE] status=${status.name}\n[FAIL SOURCE] reason=Call ended.\n[FAIL SOURCE] callId=${_currentSession.call?.id}');
    debugPrint('[CALL TERMINATION TRIGGER] location: endCall');
    await _handleCallTermination(
      historyStatus: status,
      reason: 'Call ended.',
      source: 'local_user',
    );
  }

  /// Centralized terminal call handling:
  /// - Determines terminal state (completed, missed, rejected, failed)
  /// - Idempotently logs to CallHistoryService with actual connected duration
  /// - Updates Firestore signaling status
  /// - Cancels timers and tears down Agora RTC media
  Future<void> _handleCallTermination({
    required CallHistoryStatus historyStatus,
    String? reason,
    String source = 'local_user',
  }) async {
    final call = _currentSession.call;
    if (call == null) {
      await _cleanupMedia();
      return;
    }

    final isCaller = call.callerId == FirebaseAuth.instance.currentUser?.uid;
    final role = isCaller ? 'caller' : 'receiver';
    final remUid = _currentSession.remoteUid?.toString() ?? 'none';
    final endedAt = DateTime.now();

    final firestoreStatus = historyStatus == CallHistoryStatus.completed
        ? CallStatus.ended
        : (historyStatus == CallHistoryStatus.rejected
            ? CallStatus.rejected
            : (historyStatus == CallHistoryStatus.missed
                ? CallStatus.missed
                : CallStatus.failed));

    // Phase 2 structured termination log
    debugPrint('[CALL TERMINATION]\ncallId=${call.id}\nrole=$role\nreason=${reason ?? "Unknown"}\nsource=$source\nfirestoreStatus=${firestoreStatus.name}\nagoraState=${_lastConnectionState.name}\nremoteUid=$remUid\ntimestamp=${endedAt.toIso8601String()}');

    final isAlreadyRecorded = _recordedCallIds.contains(call.id);
    _recordedCallIds.add(call.id);

    _durationTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _callDocSubscription?.cancel();

    // Actual connected duration only for completed calls; 0 for missed/rejected/failed
    final actualDuration = historyStatus == CallHistoryStatus.completed
        ? _currentSession.durationSeconds
        : 0;

    debugPrint('[CALL END]\ncallId: ${call.id}\nduration: $actualDuration');

    debugPrint('[FAIL SOURCE] method=_handleCallTermination\n[FAIL SOURCE] status=${historyStatus.name}\n[FAIL SOURCE] reason=$reason\n[FAIL SOURCE] callId=${call.id}');
    debugPrint('[CALL TRACE] _handleCallTermination START (callId: ${call.id}, status: ${historyStatus.name}, reason: $reason)');
    debugPrint('[CALL TRACE] _handleCallTermination TRIGGER STACK:\n${StackTrace.current}');

    try {
      debugPrint('[CALL TRACE] Firestore call status update START (status: ${firestoreStatus.name})');
      await _signalingService.updateCallStatus(
        call.id,
        firestoreStatus,
        duration: actualDuration,
      );
      debugPrint('[CALL TRACE] Firestore call status update END');
    } catch (e) {
      debugPrint('[CALL TRACE] Firestore call status update EXCEPTION: $e');
      debugPrint('[CallingService] updateCallStatus notice on termination: $e');
    }

    if (!isAlreadyRecorded) {
      try {
        debugPrint('[CALL TRACE] callHistory create START');
        await _callHistoryService.createFromCall(
          call,
          status: historyStatus,
          durationSeconds: actualDuration,
          endedAt: endedAt,
        );
        debugPrint('[CALL TRACE] callHistory create END');
      } catch (e) {
        debugPrint('[CALL TRACE] callHistory create EXCEPTION: $e');
        debugPrint('[CallingService] createFromCall error: $e');
      }
    } else {
      debugPrint('[CALL TRACE] callHistory create SKIPPED (already recorded: ${call.id})');
    }

    _updateSession(_currentSession.copyWith(
      status: firestoreStatus,
      errorMessage: reason,
    ));

    await _cleanupMedia();
    debugPrint('[CALL TRACE] _handleCallTermination END');
  }

  Future<void> _cleanupMedia() async {
    _isConnectingAgora = false;
    _connectingCallId = null;
    _durationTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _callDocSubscription?.cancel();
    await agoraService.leaveChannel();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _cleanupMedia();
    await agoraService.dispose();
  }
}
