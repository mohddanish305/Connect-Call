import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/config/agora_debug_config.dart';
import '../core/config/app_config.dart';
import '../core/models/call_history_model.dart';
import '../core/services/agora_token_client.dart';
import '../core/services/call_history_service.dart';
import '../models/group_call_model.dart';
import '../models/user_model.dart';
import 'calling_service.dart';
import 'permission_service.dart';

class GroupCallSession {
  final GroupCallModel? call;
  final bool isJoined;
  final bool isMuted;
  final bool isCameraOff;
  final bool isFrontCamera;
  final bool isSpeakerOn;
  final int? localUid;
  final Set<int> remoteUids;
  final Map<int, bool> remoteMutedVideos;
  final Map<int, QualityType> networkQualities;
  final ConnectionStateType connectionState;
  final String? errorMessage;

  const GroupCallSession({
    this.call,
    this.isJoined = false,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
    this.isSpeakerOn = true,
    this.localUid,
    this.remoteUids = const {},
    this.remoteMutedVideos = const {},
    this.networkQualities = const {},
    this.connectionState = ConnectionStateType.connectionStateDisconnected,
    this.errorMessage,
  });

  GroupCallSession copyWith({
    GroupCallModel? call,
    bool? isJoined,
    bool? isMuted,
    bool? isCameraOff,
    bool? isFrontCamera,
    bool? isSpeakerOn,
    int? localUid,
    Set<int>? remoteUids,
    Map<int, bool>? remoteMutedVideos,
    Map<int, QualityType>? networkQualities,
    ConnectionStateType? connectionState,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GroupCallSession(
      call: call ?? this.call,
      isJoined: isJoined ?? this.isJoined,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      localUid: localUid ?? this.localUid,
      remoteUids: remoteUids ?? this.remoteUids,
      remoteMutedVideos: remoteMutedVideos ?? this.remoteMutedVideos,
      networkQualities: networkQualities ?? this.networkQualities,
      connectionState: connectionState ?? this.connectionState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

typedef GroupCallSessionCallback = void Function(GroupCallSession session);

/// Dedicated multi-user group calling service (3+ participants).
/// Kept strictly isolated from 1-to-1 CallingService to prevent regressions.
class GroupCallService {
  final FirebaseFirestore? _firestore;
  final AgoraTokenClient _tokenClient;

  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  GroupCallSession _session = const GroupCallSession();
  GroupCallSession get session => _session;

  GroupCallSessionCallback? onSessionChanged;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  static FirebaseFirestore? _safeGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[GroupCallService] Firestore not initialized: $e');
      return null;
    }
  }

  GroupCallService({
    FirebaseFirestore? firestore,
    AgoraTokenClient? tokenClient,
  })  : _firestore = firestore ?? _safeGetFirestore(),
        _tokenClient = tokenClient ?? AgoraTokenClient();

  void _updateSession(GroupCallSession newSession) {
    _session = newSession;
    onSessionChanged?.call(_session);
  }

  /// Create a new group call document in Firestore
  Future<GroupCallModel> createGroupCall({
    required String title,
    required UserModel host,
    required List<UserModel> selectedContacts,
    required CallType callType,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw Exception('Firestore database is unavailable.');
    }

    final hostAgoraUid = CallingService.getDeterministicAgoraUid(host.id);
    final participants = <String, GroupParticipant>{
      host.id: GroupParticipant(
        userId: host.id,
        name: host.name,
        avatar: host.photoUrl,
        agoraUid: hostAgoraUid,
        isCameraOff: callType == CallType.audio,
        status: 'joined',
        hasLeft: false,
      ),
    };

    final participantIds = [host.id];

    for (final contact in selectedContacts) {
      final contactUid = CallingService.getDeterministicAgoraUid(contact.id);
      participantIds.add(contact.id);
      participants[contact.id] = GroupParticipant(
        userId: contact.id,
        name: contact.name,
        avatar: contact.photoUrl,
        agoraUid: contactUid,
        isCameraOff: callType == CallType.audio,
        status: 'ringing',
        hasLeft: false,
      );
    }

    final channelName = 'group_${DateTime.now().millisecondsSinceEpoch}';

    final docRef = await firestore.collection('groupCalls').add({
      'title': title.isNotEmpty ? title : 'Group Call (${selectedContacts.length + 1})',
      'hostId': host.id,
      'hostName': host.name,
      'participantIds': participantIds,
      'participants': participants.map((k, v) => MapEntry(k, v.toMap())),
      'callType': callType == CallType.audio ? 'audio' : 'video',
      'channelName': channelName,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[GROUP VIDEO] groupCallId=${docRef.id} role=host firebaseUid=${host.id} agoraUid=$hostAgoraUid channel=$channelName step=CREATE_CALL');
    debugPrint('[GROUP VIDEO] groupCallId=${docRef.id} role=host firebaseUid=${host.id} agoraUid=$hostAgoraUid channel=$channelName step=INVITE_SENT invitedCount=${selectedContacts.length}');

    final docSnap = await docRef.get();
    return GroupCallModel.fromFirestore(docSnap);
  }

  /// Stream of active incoming group calls where current user is invited and status is ringing
  Stream<List<GroupCallModel>> streamIncomingGroupCalls(String userId) {
    final firestore = _firestore;
    if (firestore == null) return const Stream.empty();

    return firestore
        .collection('groupCalls')
        .where('isActive', isEqualTo: true)
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupCallModel.fromFirestore(doc))
          .where((call) {
            // Don't show incoming call dialog to the host themselves
            if (call.hostId == userId) return false;
            final participant = call.participants[userId];
            // Only trigger for users whose invitation status is ringing/invited
            return participant != null && participant.isRinging && !participant.hasLeft;
          })
          .toList();
    });
  }

  /// Accept an incoming group call invitation
  Future<bool> acceptGroupCallInvitation(GroupCallModel groupCall, String currentUserId) async {
    final agoraUid = CallingService.getDeterministicAgoraUid(currentUserId);
    debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=participant firebaseUid=$currentUserId agoraUid=$agoraUid channel=${groupCall.channelName} step=ACCEPT');

    try {
      if (_firestore != null) {
        await _firestore.collection('groupCalls').doc(groupCall.id).set({
          'participants': {
            currentUserId: {
              'status': 'accepted',
              'hasLeft': false,
            },
          },
        }, SetOptions(merge: true));
      }

      return await joinGroupCall(groupCall, currentUserId);
    } catch (e) {
      debugPrint('[GroupCallService] Error accepting group call invitation: $e');
      return false;
    }
  }

  /// Decline an incoming group call invitation
  Future<void> declineGroupCallInvitation(GroupCallModel groupCall, String currentUserId) async {
    try {
      if (_firestore != null) {
        await _firestore.collection('groupCalls').doc(groupCall.id).set({
          'participants': {
            currentUserId: {
              'status': 'declined',
              'hasLeft': true,
            },
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[GroupCallService] Error declining group call invitation: $e');
    }
  }

  /// Join a group call with Agora RTC Engine and listen to group document
  Future<bool> joinGroupCall(GroupCallModel groupCall, String currentUserId) async {
    final localAgoraUid = CallingService.getDeterministicAgoraUid(currentUserId);
    final isVideo = groupCall.callType == CallType.video;
    final role = (groupCall.hostId == currentUserId) ? 'host' : 'participant';

    _updateSession(_session.copyWith(
      call: groupCall,
      localUid: localAgoraUid,
      isCameraOff: !isVideo,
      connectionState: ConnectionStateType.connectionStateConnecting,
      clearError: true,
    ));

    try {
      // 1. Pre-flight Permission Verification
      final permService = PermissionService();
      if (isVideo) {
        final permStatus = await permService.requestVideoPermissions();
        if (permStatus != CallPermissionStatus.granted) {
          final errorMsg = permStatus == CallPermissionStatus.permanentlyDenied
              ? 'Camera and Microphone permissions are permanently denied. Please enable them in App Settings.'
              : 'Camera and Microphone permissions are required for group video calls.';
          _updateSession(_session.copyWith(
            errorMessage: errorMsg,
            connectionState: ConnectionStateType.connectionStateFailed,
          ));
          debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=PERMISSIONS_DENIED status=$permStatus');
          return false;
        }
      } else {
        final permStatus = await permService.requestAudioPermissions();
        if (permStatus != CallPermissionStatus.granted) {
          final errorMsg = permStatus == CallPermissionStatus.permanentlyDenied
              ? 'Microphone permission is permanently denied. Please enable it in App Settings.'
              : 'Microphone permission is required for group audio calls.';
          _updateSession(_session.copyWith(
            errorMessage: errorMsg,
            connectionState: ConnectionStateType.connectionStateFailed,
          ));
          debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=PERMISSIONS_DENIED status=$permStatus');
          return false;
        }
      }

      // 2. Request Agora Token to obtain valid credentials and effective App ID
      String token = '';
      String effectiveAppId = AppConfig.agoraAppId;

      if (AgoraDebugConfig.useTemporaryToken && AgoraDebugConfig.temporaryToken.isNotEmpty) {
        token = AgoraDebugConfig.temporaryToken.trim();
        debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=USE_TEMPORARY_TOKEN');
      } else {
        User? fbUser;
        try {
          fbUser = FirebaseAuth.instance.currentUser;
        } catch (_) {}

        if (fbUser != null) {
          final idToken = await fbUser.getIdToken();
          if (idToken != null && idToken.isNotEmpty) {
            debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=REQUEST_TOKEN');
            final res = await _tokenClient.fetchToken(
              channelName: groupCall.channelName,
              uid: localAgoraUid,
              firebaseIdToken: idToken,
            );
            token = res.token;
            if (res.appId.isNotEmpty && !res.appId.contains('<') && res.appId.trim().length == 32) {
              effectiveAppId = res.appId.trim();
            } else if (AgoraDebugConfig.temporaryAppId.isNotEmpty && AgoraDebugConfig.temporaryAppId.length == 32) {
              effectiveAppId = AgoraDebugConfig.temporaryAppId;
            }
            debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=TOKEN_RECEIVED');
          }
        }
      }

      if (effectiveAppId.isEmpty) {
        throw Exception('Agora App ID is missing for group call.');
      }

      // 3. Initialize Agora Engine for group calling
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: effectiveAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=ENGINE_INITIALIZED');

      // 4. Register event handlers BEFORE joinChannel
      _registerAgoraHandlers(
        groupCallId: groupCall.id,
        role: role,
        firebaseUid: currentUserId,
        localAgoraUid: localAgoraUid,
        channelName: groupCall.channelName,
      );

      // 5. Media & Preview setup
      await _engine!.enableAudio();
      if (isVideo) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      }
      try {
        await _engine!.setEnableSpeakerphone(true);
        _updateSession(_session.copyWith(isSpeakerOn: true));
      } catch (e) {
        debugPrint('[GROUP VIDEO] Pre-join setEnableSpeakerphone notice (will retry on join): $e');
      }

      // 6. Join Channel
      final channelMediaOptions = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: isVideo,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: isVideo,
      );

      debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=JOIN_CHANNEL');
      await _engine!.joinChannel(
        token: token,
        channelId: groupCall.channelName,
        uid: localAgoraUid,
        options: channelMediaOptions,
      );

      // 7. Update Firestore participant status to 'joined'
      if (_firestore != null) {
        await _firestore.collection('groupCalls').doc(groupCall.id).set({
          'participants': {
            currentUserId: {
              'status': 'joined',
              'hasLeft': false,
              'agoraUid': localAgoraUid,
              'isCameraOff': !isVideo,
            },
          },
        }, SetOptions(merge: true));
      }

      // 8. Subscribe to group call document
      _listenToGroupDoc(groupCall.id);

      _updateSession(_session.copyWith(
        isJoined: true,
        connectionState: ConnectionStateType.connectionStateConnected,
      ));
      return true;
    } catch (e) {
      debugPrint('[GROUP VIDEO] groupCallId=${groupCall.id} role=$role firebaseUid=$currentUserId agoraUid=$localAgoraUid channel=${groupCall.channelName} step=JOIN_FAILED error=$e');
      _updateSession(_session.copyWith(
        errorMessage: 'Unable to connect to group call: $e',
        connectionState: ConnectionStateType.connectionStateFailed,
      ));
      return false;
    }
  }

  void _registerAgoraHandlers({
    required String groupCallId,
    required String role,
    required String firebaseUid,
    required int localAgoraUid,
    required String channelName,
  }) {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[GROUP VIDEO] groupCallId=$groupCallId role=$role firebaseUid=$firebaseUid agoraUid=$localAgoraUid channel=${connection.channelId} step=LOCAL_JOINED');
          try {
            _engine?.setEnableSpeakerphone(true);
          } catch (e) {
            debugPrint('[GROUP VIDEO] onJoinChannelSuccess setEnableSpeakerphone notice: $e');
          }
          _updateSession(_session.copyWith(
            connectionState: ConnectionStateType.connectionStateConnected,
            isSpeakerOn: true,
          ));
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[GROUP VIDEO] groupCallId=$groupCallId role=$role firebaseUid=$firebaseUid agoraUid=$localAgoraUid channel=${connection.channelId} step=REMOTE_JOINED uid=$remoteUid');
          final updatedUids = Set<int>.from(_session.remoteUids)..add(remoteUid);
          _updateSession(_session.copyWith(remoteUids: updatedUids));
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('[GROUP VIDEO] groupCallId=$groupCallId role=$role firebaseUid=$firebaseUid agoraUid=$localAgoraUid channel=${connection.channelId} step=REMOTE_LEFT uid=$remoteUid (reason: $reason)');
          // Keep call active for remaining participants; remove only the disconnected participant
          final updatedUids = Set<int>.from(_session.remoteUids)..remove(remoteUid);
          final updatedMuted = Map<int, bool>.from(_session.remoteMutedVideos)..remove(remoteUid);
          final updatedQualities = Map<int, QualityType>.from(_session.networkQualities)..remove(remoteUid);
          _updateSession(_session.copyWith(
            remoteUids: updatedUids,
            remoteMutedVideos: updatedMuted,
            networkQualities: updatedQualities,
          ));
        },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          debugPrint('[GROUP VIDEO] groupCallId=$groupCallId role=$role firebaseUid=$firebaseUid agoraUid=$localAgoraUid channel=${connection.channelId} step=REMOTE_VIDEO_STATE_CHANGED uid=$remoteUid state=$state');
          final isStopped = (state == RemoteVideoState.remoteVideoStateStopped);
          final mutedMap = Map<int, bool>.from(_session.remoteMutedVideos);
          mutedMap[remoteUid] = isStopped;
          _updateSession(_session.copyWith(remoteMutedVideos: mutedMap));
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[GROUP VIDEO] groupCallId=$groupCallId role=$role firebaseUid=$firebaseUid agoraUid=$localAgoraUid channel=${connection.channelId} step=CONNECTION_STATE_CHANGED state=$state reason=$reason');
          _updateSession(_session.copyWith(connectionState: state));
        },
        onNetworkQuality: (RtcConnection connection, int uid, QualityType txQuality, QualityType rxQuality) {
          final effectiveUid = uid == 0 ? localAgoraUid : uid;
          final qualities = Map<int, QualityType>.from(_session.networkQualities);
          qualities[effectiveUid] = rxQuality;
          _updateSession(_session.copyWith(networkQualities: qualities));
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('[GROUP VIDEO] groupCallId=$groupCallId role=$role firebaseUid=$firebaseUid agoraUid=$localAgoraUid channel=${connection.channelId} step=LEAVE');
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[GROUP VIDEO] groupCallId=$groupCallId role=$role firebaseUid=$firebaseUid agoraUid=$localAgoraUid channel=$channelName step=ERROR err=$err msg=$msg');
        },
      ),
    );
  }

  void _listenToGroupDoc(String callId) {
    final firestore = _firestore;
    if (firestore == null) return;

    _docSub?.cancel();
    _docSub = firestore.collection('groupCalls').doc(callId).snapshots().listen((snap) {
      if (snap.exists && snap.data() != null) {
        final updatedModel = GroupCallModel.fromFirestore(snap);
        if (!updatedModel.isActive) {
          // Call was ended by the host
          leaveGroupCall();
          return;
        }
        _updateSession(_session.copyWith(call: updatedModel));
      }
    });
  }

  Future<void> toggleMute() async {
    final nextMuted = !_session.isMuted;
    await _engine?.muteLocalAudioStream(nextMuted);
    _updateSession(_session.copyWith(isMuted: nextMuted));

    final call = _session.call;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (call != null && uid != null && _firestore != null) {
      _firestore.collection('groupCalls').doc(call.id).set({
        'participants': {
          uid: {
            'isMuted': nextMuted,
          },
        },
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('[GroupCallService] Failed to sync mute status: $e');
      });
    }
  }

  Future<void> toggleCamera() async {
    final nextCameraOff = !_session.isCameraOff;
    await _engine?.muteLocalVideoStream(nextCameraOff);
    if (!nextCameraOff) {
      await _engine?.enableVideo();
      await _engine?.startPreview();
    }
    _updateSession(_session.copyWith(isCameraOff: nextCameraOff));

    final call = _session.call;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (call != null && uid != null && _firestore != null) {
      _firestore.collection('groupCalls').doc(call.id).set({
        'participants': {
          uid: {
            'isCameraOff': nextCameraOff,
          },
        },
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('[GroupCallService] Failed to sync camera status: $e');
      });
    }
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
    _updateSession(_session.copyWith(isFrontCamera: !_session.isFrontCamera));
  }

  Future<void> toggleSpeaker() async {
    final nextSpeaker = !_session.isSpeakerOn;
    try {
      await _engine?.setEnableSpeakerphone(nextSpeaker);
      _updateSession(_session.copyWith(isSpeakerOn: nextSpeaker));
    } catch (e) {
      debugPrint('[GROUP VIDEO] toggleSpeaker error: $e');
    }
  }

  /// Leave the group call and cleanup resources
  Future<void> leaveGroupCall() async {
    try {
      _docSub?.cancel();
      _docSub = null;

      final call = _session.call;
      String? currentUid;
      try {
        currentUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}

      if (call != null && currentUid != null && _firestore != null) {
        final isHost = call.hostId == currentUid;

        // If host leaves, mark entire call as inactive; otherwise mark only current participant as left
        final updateData = <String, dynamic>{
          'participants': {
            currentUid: {
              'status': 'left',
              'hasLeft': true,
            },
          },
        };

        if (isHost) {
          updateData['isActive'] = false;
        }

        await _firestore.collection('groupCalls').doc(call.id).set(updateData, SetOptions(merge: true));

        // Idempotently record Call History
        try {
          final historyService = CallHistoryService();
          if (historyService.isAvailable) {
            final now = DateTime.now();
            final durationSeconds = now.difference(call.createdAt).inSeconds;
            await historyService.createHistory(
              CallHistoryModel(
                id: 'gh_${call.id}_$currentUid',
                callerId: call.hostId,
                callerName: call.hostName,
                callerAvatar: null,
                receiverId: 'group_${call.id}',
                receiverName: call.title,
                receiverAvatar: null,
                otherUserId: call.hostId == currentUid ? 'group' : call.hostId,
                otherUserName: call.title,
                otherUserAvatar: null,
                callType: call.callType,
                direction: call.hostId == currentUid ? CallDirection.outgoing : CallDirection.incoming,
                status: CallHistoryStatus.completed,
                startedAt: call.createdAt,
                acceptedAt: call.createdAt,
                endedAt: now,
                durationSeconds: durationSeconds > 0 ? durationSeconds : 0,
                channelName: call.channelName,
              ),
            );
          }
        } catch (e) {
          debugPrint('[GroupCallService] Failed to record call history: $e');
        }
      }

      await _engine?.stopPreview();
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;

      _updateSession(const GroupCallSession());
    } catch (e) {
      debugPrint('[GroupCallService] Error leaving group call: $e');
    }
  }
}
