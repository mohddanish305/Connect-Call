import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/block_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/group_call_provider.dart';
import '../../services/notification_service.dart';
import '../call/incoming_call_screen.dart';
import '../contacts/contacts_screen.dart';
import '../group_call/incoming_group_call_dialog.dart';
import '../history/call_history_screen.dart';
import '../profile/profile_screen.dart';
import 'home_dashboard_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  String? _currentlyDisplayedIncomingCallId;
  String? _currentlyDisplayedIncomingGroupCallId;

  @override
  void initState() {
    super.initState();
    // Connect background / push notification click to the incoming call flow
    NotificationService().onNotificationCallTapped = (callId, callerId, callerName, callType, channelName) async {
      if (!mounted) return;
      String? currentAuthUid;
      try {
        currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
      currentAuthUid ??= ref.read(currentUserProvider)?.id;

      if (currentAuthUid != null) {
        final blockService = ref.read(blockServiceProvider);
        final isBlocked = await blockService.isUserBlocked(
          currentUserId: currentAuthUid,
          targetUserId: callerId,
        );
        if (isBlocked) {
          debugPrint('[BLOCK DEBUG] Notification tap from blocked user $callerId ignored');
          return;
        }
      }

      final currentSession = ref.read(callControllerProvider);
      if (currentSession.status == CallStatus.ended ||
          currentSession.status == CallStatus.rejected ||
          currentSession.status == CallStatus.failed ||
          currentSession.status == CallStatus.missed) {
        final incomingCall = CallModel(
          id: callId,
          callerId: callerId,
          callerName: callerName,
          calleeId: currentAuthUid ?? '',
          calleeName: ref.read(currentUserProvider)?.name ?? 'Me',
          callType: callType,
          status: CallStatus.ringing,
          channelName: channelName,
          startedAt: DateTime.now(),
          direction: CallDirection.incoming,
        );
        _currentlyDisplayedIncomingCallId = callId;
        ref.read(callControllerProvider.notifier).handleIncomingCall(incomingCall);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Section 6 & 7: Listen for real Firestore incoming call signaling with deduplication
    ref.listen(incomingCallsStreamProvider, (previous, next) {
      next.whenData((incomingCalls) async {
        if (incomingCalls.isNotEmpty) {
          debugPrint('[INCOMING TRACE] 01 ringing listener fired (count: ${incomingCalls.length})');
          final activeCall = incomingCalls.first;
          String? currentAuthUid;
          try {
            currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
          } catch (_) {}
          currentAuthUid ??= ref.read(currentUserProvider)?.id;
          if (currentAuthUid == null) return;

          // Check if caller is blocked by the receiver
          final blockService = ref.read(blockServiceProvider);
          final isBlocked = await blockService.isUserBlocked(
            currentUserId: currentAuthUid,
            targetUserId: activeCall.callerId,
          );

          if (isBlocked) {
            debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentAuthUid\ntargetUid=${activeCall.callerId}\naction=incoming_call_rejected\nresult=blocked_user');
            // Reject call in Firestore so caller ends without ringing callee
            ref.read(callSignalingServiceProvider).updateCallStatus(activeCall.id, CallStatus.rejected);
            return;
          }

          debugPrint('[INCOMING TRACE] 02 incoming call data parsed (callId: ${activeCall.id}, caller: ${activeCall.callerName}, status: ${activeCall.status.name})');
          final currentSession = ref.read(callControllerProvider);

          // Prevent duplicate incoming screens or re-triggering for same callId
          if (_currentlyDisplayedIncomingCallId == activeCall.id) {
            return;
          }

          if (currentSession.status == CallStatus.ended ||
              currentSession.status == CallStatus.rejected ||
              currentSession.status == CallStatus.failed ||
              currentSession.status == CallStatus.missed) {
            _currentlyDisplayedIncomingCallId = activeCall.id;
            ref.read(callControllerProvider.notifier).handleIncomingCall(activeCall);
          }
        }
      });
    });

    // Listen for incoming call events to show IncomingCallScreen
    ref.listen(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.missed ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.failed) {
        _currentlyDisplayedIncomingCallId = null;
      }

      if (next.status == CallStatus.ringing &&
          next.call?.direction == CallDirection.incoming &&
          (previous == null || previous.status != CallStatus.ringing)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const IncomingCallScreen(),
            fullscreenDialog: true,
          ),
        ).then((_) {
          final s = ref.read(callControllerProvider);
          if (s.status == CallStatus.ringing) {
            _currentlyDisplayedIncomingCallId = null;
          }
        });
      }
    });

    // Listen for incoming group calls targeting the current user
    ref.listen(incomingGroupCallsStreamProvider, (previous, next) {
      next.whenData((incomingGroupCalls) async {
        if (incomingGroupCalls.isNotEmpty) {
          final activeGroupCall = incomingGroupCalls.first;

          // Prevent duplicate dialogs for the same group call synchronously
          if (_currentlyDisplayedIncomingGroupCallId == activeGroupCall.id) {
            return;
          }
          _currentlyDisplayedIncomingGroupCallId = activeGroupCall.id;

          String? currentAuthUid;
          try {
            currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
          } catch (_) {}
          currentAuthUid ??= ref.read(currentUserProvider)?.id;
          if (currentAuthUid == null) {
            _currentlyDisplayedIncomingGroupCallId = null;
            return;
          }

          // Check if host is blocked
          final blockService = ref.read(blockServiceProvider);
          final isBlocked = await blockService.isUserBlocked(
            currentUserId: currentAuthUid,
            targetUserId: activeGroupCall.hostId,
          );
          if (isBlocked) {
            debugPrint('[BLOCK DEBUG] Incoming group call from blocked host ${activeGroupCall.hostId} ignored');
            _currentlyDisplayedIncomingGroupCallId = null;
            return;
          }

          // Ensure not already in an active 1-to-1 call
          final callSession = ref.read(callControllerProvider);
          final is1to1Active = callSession.status == CallStatus.calling ||
              callSession.status == CallStatus.ringing ||
              callSession.status == CallStatus.connected ||
              callSession.status == CallStatus.inCall;
          if (is1to1Active) {
            _currentlyDisplayedIncomingGroupCallId = null;
            return;
          }

          // Ensure not already in an active group call
          final groupSession = ref.read(groupCallNotifierProvider);
          if (groupSession.isJoined) {
            _currentlyDisplayedIncomingGroupCallId = null;
            return;
          }

          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => IncomingGroupCallDialog(groupCall: activeGroupCall),
            ).then((_) {
              _currentlyDisplayedIncomingGroupCallId = null;
            });
          }
        } else {
          // When no active incoming group call is targeting this user, clear active dialog tracker
          _currentlyDisplayedIncomingGroupCallId = null;
        }
      });
    });

    final tabs = [
      HomeDashboardTab(
        onNavigateToContacts: () => setState(() => _currentIndex = 1),
        onNavigateToCalls: () => setState(() => _currentIndex = 2),
        onNavigateToProfile: () => setState(() => _currentIndex = 3),
      ),
      const ContactsScreen(),
      const CallHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue,
          unselectedItemColor: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_outlined),
              activeIcon: Icon(Icons.phone_rounded),
              label: 'Calls',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
