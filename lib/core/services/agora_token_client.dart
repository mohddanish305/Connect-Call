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

    var baseUrl = AppConfig.backendBaseUrl;
    var url = Uri.parse('$baseUrl/api/agora/token');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $firebaseIdToken',
    };

    final body = jsonEncode({
      'channelName': channelName,
      'uid': uid,
    });

    debugPrint(
      '[AGORA API DEBUG]\n'
      'backendUrl=$baseUrl\n'
      'channelName=$channelName\n'
      'agoraUid=$uid',
    );

    final stopwatch = Stopwatch()..start();
    try {
      debugPrint('[CALL TRACE 06] POST /api/agora/token START (url: $url, channel: $channelName, uid: $uid)');
      debugPrint('[CALL TRACE] POST $url START | Authorization header present: ${firebaseIdToken.isNotEmpty} | channelName: $channelName | numeric uid: $uid');
      var response = await _httpClient
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      stopwatch.stop();
      debugPrint('[CALL TRACE] POST $url END | status: ${response.statusCode} | elapsed: ${stopwatch.elapsedMilliseconds}ms');

      // Failover: If preview URL returned 302 redirect or 401 Protected Deployment, retry with canonical production domain
      if ((response.statusCode == 302 ||
              (response.statusCode == 401 && response.body.contains('Protected deployment'))) &&
          baseUrl != AppConfig.productionBackendUrl) {
        debugPrint('[CALL TRACE] Preview URL protected by SSO. Retrying on canonical production domain: ${AppConfig.productionBackendUrl}');
        baseUrl = AppConfig.productionBackendUrl;
        url = Uri.parse('$baseUrl/api/agora/token');
        response = await _httpClient
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
      }

      final int statusCode = response.statusCode;

      // Parse server message if available (support both root and nested error.message)
      String serverMessage = '';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map) {
          if (errJson['message'] != null) {
            serverMessage = errJson['message'].toString();
          } else if (errJson['error'] is Map && errJson['error']['message'] != null) {
            serverMessage = errJson['error']['message'].toString();
          }
        }
      } catch (_) {}

      bool tokenPresent = false;
      bool appIdPresent = false;
      AgoraTokenResponse? tokenRes;

      if (statusCode == 200) {
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final tokenData = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
          tokenRes = AgoraTokenResponse.fromJson(tokenData, httpStatus: statusCode);
          tokenPresent = tokenRes.token.isNotEmpty;
          appIdPresent = tokenRes.appId.isNotEmpty;
        } catch (_) {}
      }

      debugPrint('[CALL TRACE 07] POST /api/agora/token RESPONSE (status: $statusCode, elapsed: ${stopwatch.elapsedMilliseconds}ms)');
      debugPrint(
        '[AGORA API]\n'
        'status=$statusCode\n'
        'success=${statusCode == 200}\n'
        'message=${serverMessage.isNotEmpty ? serverMessage : (statusCode == 200 ? "OK" : "No server message")}\n'
        'tokenPresent=$tokenPresent\n'
        'appIdPresent=$appIdPresent',
      );
      debugPrint('[AGORA TOKEN]\nchannelName: $channelName\nHTTP status: $statusCode\nelapsed: ${stopwatch.elapsedMilliseconds}ms');

      if (statusCode == 200 && tokenRes != null) {
        debugPrint('[AGORA BACKEND RESPONSE]\nHTTP status: $statusCode\nsuccess: true\nappId present: ${tokenRes.appId.isNotEmpty}\ntoken present: ${tokenRes.token.isNotEmpty}\nchannelName: ${tokenRes.channelName}\nuid: ${tokenRes.uid}\nexpiresAt: ${tokenRes.expiresAt.toIso8601String()}');
        return tokenRes;
      }

      debugPrint(
        '[CALL FAILURE]\n'
        'step=CALL_TRACE_07_TOKEN_RESPONSE\n'
        'exceptionType=CallingServiceException\n'
        'errorCode=$statusCode\n'
        'httpStatus=$statusCode\n'
        'message=$serverMessage',
      );

      if (statusCode == 401) {
        if (serverMessage.toLowerCase().contains('protected deployment')) {
          throw const CallingServiceException(
            'Vercel preview deployment is protected by SSO. Please use production domain or disable Deployment Protection.',
            statusCode: 401,
          );
        }
        if (serverMessage.toLowerCase().contains('id-token-expired') ||
            serverMessage.toLowerCase().contains('session has expired')) {
          throw const CallingServiceException(
            'Your session has expired. Please sign in again.',
            statusCode: 401,
          );
        }
        throw CallingServiceException(
          serverMessage.isNotEmpty
              ? 'Calling authentication failed: $serverMessage'
              : 'Calling authentication failed (HTTP 401).',
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
      } else if (statusCode == 408) {
        throw const CallingServiceException(
          'Request timed out while connecting to calling service.',
          statusCode: 408,
          canRetry: true,
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
