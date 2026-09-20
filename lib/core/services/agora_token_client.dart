import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class CallingServiceException implements Exception {
  final String message;
  final int? statusCode;
  final bool canRetry;

  const CallingServiceException(
    this.message, {
    this.statusCode,
    this.canRetry = false,
  });

  @override
  String toString() => message;
}

class AgoraTokenResponse {
  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final DateTime expiresAt;
  final int httpStatus;

  const AgoraTokenResponse({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.expiresAt,
    this.httpStatus = 200,
  });

  factory AgoraTokenResponse.fromJson(Map<String, dynamic> json, {int httpStatus = 200}) {
    return AgoraTokenResponse(
      token: json['token'] ?? '',
      appId: json['appId'] ?? '',
      channelName: json['channelName'] ?? '',
      uid: json['uid'] is int ? json['uid'] : int.tryParse(json['uid'].toString()) ?? 0,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt']) ?? DateTime.now().add(const Duration(hours: 1))
          : DateTime.now().add(const Duration(hours: 1)),
      httpStatus: httpStatus,
    );
  }
}

class AgoraTokenClient {
  final http.Client _httpClient;

  AgoraTokenClient([http.Client? httpClient]) : _httpClient = httpClient ?? http.Client();

  /// Request a short-lived Agora RTC token from the backend
  Future<AgoraTokenResponse> fetchToken({
    required String channelName,
    required int uid,
    required String firebaseIdToken,
  }) async {
    if (firebaseIdToken.isEmpty) {
      throw const CallingServiceException(
        'Authentication required. No valid Firebase token available.',
        statusCode: 401,
      );
    }

    final baseUrl = AppConfig.backendBaseUrl;
    final url = Uri.parse('$baseUrl/api/agora/token');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $firebaseIdToken',
    };

    final body = jsonEncode({
      'channelName': channelName,
      'uid': uid,
    });

    final stopwatch = Stopwatch()..start();
    try {
      // Security: log only safe diagnostic metadata; NEVER log Authorization header or token
      debugPrint('[CALL TRACE] POST $url START | Authorization header present: ${firebaseIdToken.isNotEmpty} | channelName: $channelName | numeric uid: $uid');
      final response = await _httpClient
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      debugPrint('[CALL TRACE] POST $url END | status: ${response.statusCode} | elapsed: ${stopwatch.elapsedMilliseconds}ms');

      final int statusCode = response.statusCode;
      debugPrint('[AGORA TOKEN]\nchannelName: $channelName\nHTTP status: $statusCode\nelapsed: ${stopwatch.elapsedMilliseconds}ms');

      if (statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tokenData = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
        final res = AgoraTokenResponse.fromJson(tokenData, httpStatus: statusCode);

        // Task 7: Report structured backend response without printing raw token
        debugPrint('[AGORA BACKEND RESPONSE]\nHTTP status: $statusCode\nsuccess: ${json['success'] == true}\nappId present: ${res.appId.isNotEmpty}\ntoken present: ${res.token.isNotEmpty}\nchannelName: ${res.channelName}\nuid: ${res.uid}\nexpiresAt: ${res.expiresAt.toIso8601String()}');
        return res;
      }

      // Parse server message if available
      String serverMessage = '';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson['message'] != null) {
          serverMessage = errJson['message'].toString();
        }
      } catch (_) {}

      if (statusCode == 401) {
        throw CallingServiceException(
          serverMessage.isNotEmpty ? serverMessage : 'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      } else if (statusCode == 403) {
        throw CallingServiceException(
          serverMessage.isNotEmpty ? serverMessage : 'You do not have permission to join this call.',
          statusCode: 403,
        );
      } else if (statusCode == 400) {
        throw CallingServiceException(
          serverMessage.isNotEmpty ? serverMessage : 'Unable to start the call. Invalid request parameters.',
          statusCode: 400,
        );
      } else if (statusCode == 404) {
        throw const CallingServiceException(
          'Calling service endpoint not found.',
          statusCode: 404,
        );
      } else if (statusCode == 429) {
        throw const CallingServiceException(
          'Too many requests. Please try again shortly.',
          statusCode: 429,
          canRetry: true,
        );
      } else if (statusCode >= 500) {
        throw CallingServiceException(
          serverMessage.isNotEmpty ? serverMessage : 'Calling service is temporarily unavailable (HTTP $statusCode).',
          statusCode: statusCode,
          canRetry: true,
        );
      } else {
        throw CallingServiceException(
          serverMessage.isNotEmpty ? serverMessage : 'Unable to start the call (HTTP $statusCode).',
          statusCode: statusCode,
          canRetry: true,
        );
      }
    } on TimeoutException {
      throw const CallingServiceException(
        'Unable to connect to calling service. Request timed out.',
        canRetry: true,
      );
    } on SocketException {
      throw const CallingServiceException(
        'Unable to connect to calling service. Please check your internet connection.',
        canRetry: true,
      );
    } on CallingServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[AgoraTokenClient] Token request error: $e');
      throw const CallingServiceException(
        'Unable to connect to calling service.',
        canRetry: true,
      );
    }
  }
}
