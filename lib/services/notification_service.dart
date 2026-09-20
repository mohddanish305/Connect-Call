import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/call_model.dart';

/// Top-level background message handler for Firebase Messaging.
/// Must be annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] Background message received: ${message.messageId}');
  // Background incoming call payload is processed by the platform
}

typedef IncomingCallNotificationTapCallback = void Function(
  String callId,
  String callerId,
  String callerName,
  CallType callType,
  String channelName,
);

/// Comprehensive Push Notification & Background Call Service.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  FirebaseMessaging? get _fcm {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _cachedFcmToken;
  String? get cachedFcmToken => _cachedFcmToken;

  IncomingCallNotificationTapCallback? onNotificationCallTapped;

  static const String callNotificationChannelId = 'connectcall_incoming_calls';
  static const String callNotificationChannelName = 'Incoming Calls';
  static const String callNotificationChannelDescription =
      'High-priority notifications for incoming audio and video calls';

  /// Initialize FCM, local notification channels, and message listeners.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final fcm = _fcm;
      if (fcm == null) {
        debugPrint('[NotificationService] FirebaseMessaging not available.');
        return;
      }

      // 1. Request notification permissions (Android 13+ and iOS)
      final settings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[NotificationService] AuthorizationStatus: ${settings.authorizationStatus}');

      // 2. Initialize Android notification channels
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Create high-importance notification channel for Android
      if (!kIsWeb && Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          callNotificationChannelId,
          callNotificationChannelName,
          description: callNotificationChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }

      // 3. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground message received: ${message.data}');
        _showLocalCallNotification(message);
      });

      // 5. Handle app opened from background state via notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] onMessageOpenedApp tapped: ${message.data}');
        _processCallPayload(message.data);
      });

      // 6. Check if app was opened from terminated state by notification tap
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] getInitialMessage tapped: ${initialMessage.data}');
        _processCallPayload(initialMessage.data);
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully.');
    } catch (e) {
      debugPrint('[NotificationService] Notice during initialization: $e');
    }
  }

  /// Synchronize the device FCM registration token with Firestore users/{userId}.
  Future<String?> syncTokenToFirestore(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final fcm = _fcm;
      if (fcm == null) return null;

      final token = await fcm.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedFcmToken = token;
        debugPrint('[NotificationService] Acquired FCM token for $userId');

        final firestore = FirebaseFirestore.instance;
        await firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('[NotificationService] Synced FCM token to users/$userId');
      }

      // Listen for token refreshes and automatically update Firestore
      fcm.onTokenRefresh.listen((newToken) async {
        _cachedFcmToken = newToken;
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'fcmToken': newToken,
            'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('[NotificationService] Refreshed FCM token synced for $userId');
        } catch (_) {}
      });

      return token;
    } catch (e) {
      debugPrint('[NotificationService] Error syncing FCM token: $e');
      return null;
    }
  }

  /// Delete FCM token upon user sign out
  Future<void> clearToken(String userId) async {
    try {
      if (userId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'fcmToken': FieldValue.delete(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      await _fcm?.deleteToken();
      _cachedFcmToken = null;
      debugPrint('[NotificationService] FCM token cleared on sign out.');
    } catch (e) {
      debugPrint('[NotificationService] Notice clearing token: $e');
    }
  }

  /// Request backend to send a push notification to callee
  Future<void> sendCallPushNotification({
    required String callerId,
    required String callerName,
    required String receiverId,
    required String callId,
    required CallType callType,
    required String channelName,
  }) async {
    final baseUrl = AppConfig.backendBaseUrl;
    if (baseUrl.isEmpty) return;

    final url = Uri.parse('$baseUrl/api/notifications/call');
    final isVideo = callType == CallType.video;

    try {
      final body = jsonEncode({
        'callerId': callerId,
        'callerName': callerName,
        'receiverId': receiverId,
        'callId': callId,
        'callType': isVideo ? 'video' : 'audio',
        'channelName': channelName,
        'title': isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
        'body': '$callerName is calling you',
      });

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 4));

      debugPrint('[NotificationService] Backend notification response status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[NotificationService] Backend call push notification notice: $e');
    }
  }

  void _showLocalCallNotification(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? data['title'] ?? 'Incoming Call';
    final body = message.notification?.body ?? data['body'] ?? 'You have an incoming call';

    const androidDetails = AndroidNotificationDetails(
      callNotificationChannelId,
      callNotificationChannelName,
      channelDescription: callNotificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _processCallPayload(data);
      } catch (e) {
        debugPrint('[NotificationService] Error parsing notification payload: $e');
      }
    }
  }

  void _processCallPayload(Map<String, dynamic> data) {
    final callId = data['callId']?.toString() ?? '';
    final callerId = data['callerId']?.toString() ?? '';
    final callerName = data['callerName']?.toString() ?? 'Caller';
    final callTypeStr = data['callType']?.toString() ?? 'audio';
    final channelName = data['channelName']?.toString() ?? '';

    if (callId.isNotEmpty && onNotificationCallTapped != null) {
      final callType = callTypeStr == 'video' ? CallType.video : CallType.audio;
      onNotificationCallTapped!(callId, callerId, callerName, callType, channelName);
    }
  }
}
