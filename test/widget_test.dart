import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectcall/core/utils/date_formatter.dart';
import 'package:connectcall/models/call_model.dart';
import 'package:connectcall/models/user_model.dart';
import 'package:connectcall/models/call_session.dart';
import 'package:connectcall/core/models/call_history_model.dart';
import 'package:connectcall/core/services/call_history_service.dart';
import 'package:connectcall/services/onboarding_service.dart';
import 'package:connectcall/screens/onboarding/onboarding_screen.dart';
import 'package:connectcall/core/services/agora_token_client.dart';
import 'package:connectcall/core/services/network_service.dart';
import 'package:connectcall/core/services/permission_service.dart';
import 'package:connectcall/providers/auth_provider.dart';
import 'package:connectcall/screens/home/home_screen.dart';
import 'package:connectcall/screens/splash/splash_screen.dart';
import 'package:connectcall/widgets/user_avatar.dart';

void main() {
  group('DateFormatter Tests', () {
    test('formatDuration formats seconds to mm:ss correctly', () {
      expect(DateFormatter.formatDuration(0), '00:00');
      expect(DateFormatter.formatDuration(5), '00:05');
      expect(DateFormatter.formatDuration(59), '00:59');
      expect(DateFormatter.formatDuration(60), '01:00');
      expect(DateFormatter.formatDuration(155), '02:35');
      expect(DateFormatter.formatDuration(3600), '60:00');
    });

    test('formatCallTime outputs time for today correctly', () {
      final now = DateTime.now();
      final formatted = DateFormatter.formatCallTime(now);
      expect(formatted.startsWith('Today,'), isTrue);
    });
  });

  group('UserModel Tests', () {
    test('toMap and fromMap serialize properly', () {
      final user = UserModel(
        id: 'user_123',
        name: 'Sarah Johnson',
        email: 'sarah@connectcall.io',
        phone: '+1 555-0192',
        photoUrl: 'https://example.com/sarah.png',
        isOnline: true,
        lastSeen: DateTime(2026, 9, 10, 12, 0),
      );

      final map = user.toMap();
      expect(map['id'], 'user_123');
      expect(map['name'], 'Sarah Johnson');
      expect(map['isOnline'], true);

      final restored = UserModel.fromMap(map);
      expect(restored.id, user.id);
      expect(restored.name, user.name);
      expect(restored.email, user.email);
      expect(restored.phone, user.phone);
      expect(restored.isOnline, user.isOnline);
    });

    test('copyWith updates specific properties', () {
      final user = UserModel(
        id: '1',
        name: 'John',
        email: 'john@example.com',
        lastSeen: DateTime.now(),
      );

      final updated = user.copyWith(name: 'John Smith', isOnline: true);
      expect(updated.name, 'John Smith');
      expect(updated.isOnline, true);
      expect(updated.id, '1');
      expect(updated.email, 'john@example.com');
    });
  });

  group('CallModel Tests', () {
    test('toMap and fromMap preserve call properties', () {
      final call = CallModel(
        id: 'call_123',
        callerId: 'user_1',
        callerName: 'Sarah Johnson',
        calleeId: 'user_2',
        calleeName: 'John Smith',
        callType: CallType.video,
        status: CallStatus.inCall,
        startedAt: DateTime(2026, 9, 10, 14, 0),
        duration: 120,
        direction: CallDirection.outgoing,
      );

      final map = call.toMap();
      expect(map['callType'], 'video');
      expect(map['status'], 'inCall');
      expect(map['duration'], 120);

      final restored = CallModel.fromMap(map);
      expect(restored.id, call.id);
      expect(restored.callerName, 'Sarah Johnson');
      expect(restored.callType, CallType.video);
      expect(restored.status, CallStatus.inCall);
      expect(restored.duration, 120);
    });

    test('CallSession copyWith works as expected', () {
      const session = CallSession();
      expect(session.isMuted, isFalse);
      expect(session.isCameraOff, isFalse);
      expect(session.status, CallStatus.ended);

      final updated = session.copyWith(
        isMuted: true,
        status: CallStatus.inCall,
        durationSeconds: 45,
        localUid: 1001,
        remoteUid: 2002,
      );
      expect(updated.isMuted, isTrue);
      expect(updated.status, CallStatus.inCall);
      expect(updated.durationSeconds, 45);
      expect(updated.localUid, 1001);
      expect(updated.remoteUid, 2002);
    });

    test('CallModel correctly serializes channelName and Firestore keys', () {
      final call = CallModel(
        id: 'call_abc_123',
        callerId: 'user_a',
        callerName: 'Alice',
        calleeId: 'user_b',
        calleeName: 'Bob',
        callType: CallType.audio,
        status: CallStatus.calling,
        channelName: 'call_channel_special',
        startedAt: DateTime(2026, 9, 11, 10, 0),
        direction: CallDirection.outgoing,
      );

      final map = call.toMap();
      expect(map['channelName'], 'call_channel_special');
      expect(map['receiverId'], 'user_b');
      expect(map['status'], 'calling');

      final restored = CallModel.fromMap(map);
      expect(restored.channelName, 'call_channel_special');
      expect(restored.calleeId, 'user_b');
      expect(restored.status, CallStatus.calling);
    });
  });

  group('Onboarding Tests', () {
    test('OnboardingService completes and resets properly', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OnboardingService();

      expect(await service.isOnboardingCompleted(), isFalse);

      await service.completeOnboarding();
      expect(await service.isOnboardingCompleted(), isTrue);

      await service.resetOnboarding();
      expect(await service.isOnboardingCompleted(), isFalse);
    });

    testWidgets('OnboardingScreen renders first page and allows advancing', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      // Verify Screen 1
      expect(find.text('Connect with anyone'), findsOneWidget);
      expect(find.text('Find your people and stay connected wherever you are.'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next -> Screen 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Crystal-clear calling'), findsOneWidget);
      expect(find.text('Make seamless audio and video calls with the people who matter.'), findsOneWidget);

      // Tap Next -> Screen 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Always stay connected'), findsOneWidget);
      expect(find.text('Call, chat and keep track of your conversations in one simple place.'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });

  group('CallHistoryModel & Service Tests', () {
    test('CallHistoryModel resolves relative direction and other party correctly', () {
      final now = DateTime.now();
      final historyMap = {
        'id': 'call_hist_1',
        'callerId': 'user_alice',
        'callerName': 'Alice',
        'callerPhoto': 'https://example.com/alice.jpg',
        'receiverId': 'user_bob',
        'receiverName': 'Bob',
        'receiverPhoto': 'https://example.com/bob.jpg',
        'callType': 'audio',
        'status': 'completed',
        'startedAt': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'endedAt': now.toIso8601String(),
        'durationSeconds': 165,
        'channelName': 'call_test_channel',
      };

      // Alice views history -> Outgoing, other is Bob
      final aliceView = CallHistoryModel.fromMap(historyMap, currentUserId: 'user_alice');
      expect(aliceView.direction, CallDirection.outgoing);
      expect(aliceView.otherUserId, 'user_bob');
      expect(aliceView.otherUserName, 'Bob');
      expect(aliceView.formattedDurationOrStatus, '02:45');

      // Bob views history -> Incoming, other is Alice
      final bobView = CallHistoryModel.fromMap(historyMap, currentUserId: 'user_bob');
      expect(bobView.direction, CallDirection.incoming);
      expect(bobView.otherUserId, 'user_alice');
      expect(bobView.otherUserName, 'Alice');
      expect(bobView.formattedDurationOrStatus, '02:45');
    });

    test('CallHistoryModel formats status correctly for missed, rejected, failed, and long duration', () {
      final now = DateTime.now();

      final missedCall = CallHistoryModel(
        id: '1',
        callerId: 'u1',
        callerName: 'User 1',
        receiverId: 'u2',
        receiverName: 'User 2',
        otherUserId: 'u2',
        otherUserName: 'User 2',
        callType: CallType.audio,
        direction: CallDirection.incoming,
        status: CallHistoryStatus.missed,
        startedAt: now,
        endedAt: now,
        durationSeconds: 0,
        channelName: 'c1',
      );
      expect(missedCall.formattedDurationOrStatus, 'Missed');
      expect(missedCall.isMissed, isTrue);

      final rejectedCall = missedCall.copyWith(status: CallHistoryStatus.rejected);
      expect(rejectedCall.formattedDurationOrStatus, 'Rejected');

      final failedCall = missedCall.copyWith(status: CallHistoryStatus.failed);
      expect(failedCall.formattedDurationOrStatus, 'Failed');

      final longCall = missedCall.copyWith(
        status: CallHistoryStatus.completed,
        durationSeconds: 4355, // 01:12:35
      );
      expect(longCall.formattedDurationOrStatus, '01:12:35');
    });

    test('CallHistoryService stores and retrieves records idempotently', () async {
      SharedPreferences.setMockInitialValues({});
      final service = CallHistoryService();

      final now = DateTime.now();
      final history = CallHistoryModel(
        id: 'call_id_repeat',
        callerId: 'alice',
        callerName: 'Alice',
        receiverId: 'bob',
        receiverName: 'Bob',
        otherUserId: 'bob',
        otherUserName: 'Bob',
        callType: CallType.audio,
        direction: CallDirection.outgoing,
        status: CallHistoryStatus.completed,
        startedAt: now.subtract(const Duration(minutes: 2)),
        endedAt: now,
        durationSeconds: 120,
        channelName: 'c_repeat',
      );

      // Create history twice with same ID
      await service.createHistory(history);
      await service.createHistory(history);

      final records = await service.getLocalHistory('alice');
      expect(records.length, 1);
      expect(records.first.id, 'call_id_repeat');
      expect(records.first.durationSeconds, 120);
    });
  });

  group('Calling Reliability & Error Handling Tests', () {
    test('CallingServiceException maps status codes and retry flags', () {
      const exp401 = CallingServiceException('Your session has expired. Please sign in again.', statusCode: 401);
      expect(exp401.statusCode, 401);
      expect(exp401.canRetry, isFalse);
      expect(exp401.toString(), 'Your session has expired. Please sign in again.');

      const exp503 = CallingServiceException('Calling service is temporarily unavailable.', statusCode: 503, canRetry: true);
      expect(exp503.statusCode, 503);
      expect(exp503.canRetry, isTrue);

      const exp429 = CallingServiceException('Too many requests. Please try again shortly.', statusCode: 429, canRetry: true);
      expect(exp429.canRetry, isTrue);
    });

    test('PermissionService provides correct error messages for audio and video', () {
      final permService = PermissionService();

      expect(
        permService.getPermissionErrorMessage(CallType.audio, CallPermissionStatus.denied),
        'Microphone permission is required to make calls.',
      );

      expect(
        permService.getPermissionErrorMessage(CallType.audio, CallPermissionStatus.permanentlyDenied),
        'Microphone permission is required to make calls. Please enable it in App Settings.',
      );

      expect(
        permService.getPermissionErrorMessage(CallType.video, CallPermissionStatus.denied),
        'Camera permission is required for video calls.',
      );

      expect(
        permService.getPermissionErrorMessage(CallType.video, CallPermissionStatus.permanentlyDenied),
        'Camera and microphone permissions are required. Please enable them in App Settings.',
      );
    });

    test('NetworkService static error message is clear and actionable', () {
      expect(
        NetworkService.noInternetMessage,
        'No internet connection. Please check your connection and try again.',
      );
    });

    test('CallSession copyWith and clearError works correctly', () {
      final session = const CallSession().copyWith(
        status: CallStatus.reconnecting,
        errorMessage: 'Reconnecting...',
      );
      expect(session.status, CallStatus.reconnecting);
      expect(session.errorMessage, 'Reconnecting...');

      final clearedSession = session.copyWith(
        status: CallStatus.inCall,
        clearError: true,
      );
      expect(clearedSession.status, CallStatus.inCall);
      expect(clearedSession.errorMessage, isNull);
    });

    test('UserModel supports uid/displayName aliases and lastSeenFormatted', () {
      final user = UserModel.fromMap({
        'uid': 'user_abc',
        'displayName': 'Alice Wonderland',
        'email': 'alice@connectcall.io',
        'isOnline': true,
      });

      expect(user.id, 'user_abc');
      expect(user.uid, 'user_abc');
      expect(user.name, 'Alice Wonderland');
      expect(user.displayName, 'Alice Wonderland');
      expect(user.lastSeenFormatted, 'Online');

      final offlineUser = user.copyWith(
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(offlineUser.lastSeenFormatted, 'Last seen 5m ago');
    });

    testWidgets('HomeScreen renders with navigation tabs and home dashboard', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              UserModel(
                id: 'user_test',
                name: 'Sarah Johnson',
                email: 'sarah@connectcall.io',
                isOnline: true,
                lastSeen: DateTime.now(),
              ),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verify Bottom Navigation Bar tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Calls'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Verify Dashboard greeting and search
      expect(find.textContaining('Sarah'), findsOneWidget);
      expect(find.text('Search people...'), findsOneWidget);
    });

    testWidgets('SplashScreen renders with logo and ConnectCall text', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );
      // Pump initial frame to start animations
      await tester.pump();
      expect(find.text('Connect with anyone, anywhere.'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);

      // Advance past the 1700ms startup timer to avoid pending timers
      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('UserAvatar renders correctly with various edge-case names', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  UserAvatar(name: 'Sarah Johnson'),
                  UserAvatar(name: 'Muhammad  Hamza'), // double space
                  UserAvatar(name: 'Single'),
                  UserAvatar(name: ''),
                  UserAvatar(name: '   '),
                  UserAvatar(name: 'A   B   C'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(UserAvatar), findsNWidgets(6));
    });

    testWidgets('HomeScreen renders fallback greeting when currentUser is null', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Fallback greeting is displayed
      expect(find.textContaining('there'), findsOneWidget);
      expect(find.text('Search people...'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('HomeScreen renders properly when user name has double spaces', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              UserModel(
                id: 'u_test_double_space',
                name: 'Muhammad  Hamza',
                email: 'muhammad@connectcall.io',
                isOnline: true,
                lastSeen: DateTime.now(),
              ),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Muhammad'), findsOneWidget);
      expect(find.text('Search people...'), findsOneWidget);
    });
  });
}


