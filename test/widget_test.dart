import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectcall/core/utils/date_formatter.dart';
import 'package:connectcall/models/call_model.dart';
import 'package:connectcall/models/user_model.dart';
import 'package:connectcall/models/call_session.dart';
import 'package:connectcall/services/onboarding_service.dart';
import 'package:connectcall/screens/onboarding/onboarding_screen.dart';

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
      );
      expect(updated.isMuted, isTrue);
      expect(updated.status, CallStatus.inCall);
      expect(updated.durationSeconds, 45);
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
}
