import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/tech_api_service.dart';

/// Top-level handler for background / terminated messages.
///
/// MUST be a top-level function with @pragma('vm:entry-point'): Flutter spawns a
/// separate isolate for it in release builds, and a class method or closure is
/// not addressable from that isolate. No work is needed here — Android shows the
/// tray notification itself from the `notification` block of the payload.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications for the field-technician app: order assignments, status
/// changes, comments and cube-test reminders.
///
/// Tap routing is exposed as a stream of order codes rather than calling
/// GoRouter directly — the service has no BuildContext, and a notification can
/// arrive before the router exists (cold start from a terminated app).
class NotificationService {
  NotificationService(this._apiService);

  final TechApiService _apiService;

  static const _channelId = 'shivesh_field_high_importance';
  static const _channelName = 'Order Notifications';
  static const _channelDesc =
      'Order assignments, status changes and site updates.';

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.max,
  );

  bool _initialized = false;
  String? _currentToken;

  /// Order codes (ORD-2025-0001) from tapped notifications, in arrival order.
  /// The app router listens and navigates to /orders/<code>.
  final _tapController = StreamController<String>.broadcast();
  Stream<String> get onOrderTapped => _tapController.stream;

  Future<void> initialize() async {
    // Already wired up — but do NOT stop here. [unregister] deletes the FCM
    // token on logout, so when the next technician signs in on this phone the
    // device owns no push slot. Re-registering here is what gets THEM their
    // notifications; returning early left them with none until a reinstall.
    // The listeners below must not be attached twice, hence the early return.
    if (_initialized) {
      await _registerCurrentDevice();
      return;
    }
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // iOS + Android 13+ runtime permission.
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      // Tapping a notification the app itself rendered while in the foreground.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleTapData(data.cast<String, dynamic>());
        } catch (_) {
          // Malformed payload — nothing to route to.
        }
      },
    );

    // Foreground: FCM does NOT draw a tray notification, so render it locally.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Background -> tapped (app alive but not focused).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleTapData(message.data),
    );

    // Cold start: the app was terminated and launched BY the notification.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTapData(initialMessage.data);
    }

    await _registerCurrentDevice();

    messaging.onTokenRefresh.listen(_registerToken);
  }

  /// Claim a push slot for whoever is signed in right now.
  ///
  /// Safe to call repeatedly: after a logout deleted the old token, `getToken`
  /// mints a fresh one, so the new technician is registered under their own
  /// account rather than inheriting the previous user's device row.
  Future<void> _registerCurrentDevice() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (_) {
      // Non-fatal: retried on the next login / cold start.
    }
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await _apiService.registerFcmToken(token, platform);
    } catch (_) {
      // Non-fatal: retried on the next token refresh / app start.
    }
  }

  /// Release this device's push slot on logout.
  ///
  /// Deletes the token from FCM too, so a signed-out phone stops receiving
  /// anything even if the server call failed.
  Future<void> unregister() async {
    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token != null) {
      try {
        await _apiService.unregisterFcmToken(token);
      } catch (_) {
        // Best effort — deleting the FCM token below still stops delivery.
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _currentToken = null;
  }

  void _handleTapData(Map<String, dynamic> data) {
    final orderId = data['orderCode'] ?? data['orderId'];
    if (orderId is String && orderId.isNotEmpty) {
      _tapController.add(orderId);
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Carried through so a foreground tap can route like a tray tap.
      payload: jsonEncode(message.data),
    );
  }

  void dispose() {
    _tapController.close();
  }
}
