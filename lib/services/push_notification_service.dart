import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/features/notifications/presentation/pages/notifications_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _localInitialized = false;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!_localInitialized) {
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      _localInitialized = true;
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _saveToken();
      _messaging.onTokenRefresh.listen(_updateToken);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        Future.delayed(const Duration(seconds: 1), () {
          _handleMessageTap(initial);
        });
      }
    }
  }

  Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _updateToken(token);
    } catch (_) {
      // APNs token not available on simulator — skip
    }
  }

  Future<void> _updateToken(String token) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client.from('fcm_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<void> removeToken() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client.from('fcm_tokens').delete().eq('user_id', userId);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final channelId = message.data['channel_id'] as String?;
    final type = message.data['type'] as String? ?? 'notification';

    String payload;
    if (channelId != null && type == 'chat') {
      payload = 'chat|$channelId|${notification.title}';
    } else {
      payload = 'notification';
    }

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fcm_push',
          'Push notifikationer',
          channelDescription: 'Notifikationer fra server',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    final channelId = message.data['channel_id'] as String?;
    final type = message.data['type'] as String?;
    final channelName = message.notification?.title;

    if (type == 'chat' && channelId != null) {
      _navigateToChat(channelId, channelName ?? 'Chat');
    } else {
      _navigateToNotifications();
    }
  }

  static void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length >= 2 && parts[0] == 'chat') {
      final channelId = parts[1];
      final channelName = parts.length >= 3 ? parts[2] : 'Chat';
      PushNotificationService()._navigateToChat(channelId, channelName);
    } else {
      PushNotificationService()._navigateToNotifications();
    }
  }

  void _navigateToChat(String channelId, String channelName) {
    Future.delayed(const Duration(milliseconds: 500), () {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      GoRouter.of(ctx).push(
        '/chat/$channelId?name=${Uri.encodeComponent(channelName)}',
      );
    });
  }

  void _navigateToNotifications() {
    Future.delayed(const Duration(milliseconds: 500), () {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => const NotificationsPage(),
        ),
      );
    });
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
