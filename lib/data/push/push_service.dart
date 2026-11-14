import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push notifications through Firebase Cloud Messaging.
///
/// Firebase only starts if the app was set up with `flutterfire configure`
/// (google-services.json / GoogleService-Info.plist). Without those files the
/// app keeps working, just without push.
abstract final class PushService {
  static var _ready = false;
  static StreamSubscription<String>? _refresh;

  static Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (error) {
      debugPrint('Push disabled: Firebase is not configured ($error).');
    }
  }

  /// Asks for permission and tells the backend this phone can get pushes.
  /// Call after sign-in and on app start when already signed in.
  static Future<void> register(Dio dio) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) {
        // iOS needs the APNs token before FCM can issue one.
        await messaging.getAPNSToken();
      }
      final token = await messaging.getToken();
      if (token != null) await _send(dio, token);
      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen((token) => _send(dio, token));
    } catch (error) {
      debugPrint('Push registration failed: $error');
    }
  }

  /// Stops pushes to this phone (on sign-out).
  static Future<void> unregister(Dio dio) async {
    if (!_ready) return;
    try {
      await _refresh?.cancel();
      _refresh = null;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await dio.delete<void>('/devices', data: {'token': token});
      }
    } catch (error) {
      debugPrint('Push unregister failed: $error');
    }
  }

  static Future<void> _send(Dio dio, String token) async {
    try {
      await dio.post<void>(
        '/devices',
        data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
    } on DioException catch (error) {
      debugPrint('Could not register device: ${error.message}');
    }
  }
}
