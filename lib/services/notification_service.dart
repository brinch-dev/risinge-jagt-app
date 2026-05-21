import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:jagt_app/models/hunt_event.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
  }

  Future<void> showBoundaryWarning(double distanceMeters, {String? customText}) async {
    final distance = distanceMeters.round();
    await _plugin.show(
      1,
      customText ?? 'Advarsel: Nærmer dig jagtgrænsen!',
      'Du er $distance meter fra jagtområdets grænse.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'boundary_warning',
          'Grænse advarsler',
          channelDescription: 'Advarsler når du nærmer dig jagtområdets grænse',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showOutsideBoundary({String? customText}) async {
    await _plugin.show(
      2,
      customText ?? 'ADVARSEL: Uden for jagtområdet!',
      'Du har forladt det tilladte jagtområde.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'boundary_warning',
          'Grænse advarsler',
          channelDescription: 'Advarsler når du forlader jagtområdet',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> scheduleEventReminder(HuntEvent event) async {
    final reminderDate = event.date.subtract(const Duration(days: 1));
    final now = DateTime.now();
    if (reminderDate.isBefore(now)) return;

    final scheduledTime = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      10,
      0,
    );

    await _plugin.zonedSchedule(
      event.id.hashCode,
      'Jagt i morgen: ${event.title}',
      event.description ?? 'Husk jagt event i morgen!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_reminders',
          'Event påmindelser',
          channelDescription: 'Påmindelser om kommende jagt events',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleLocalBroadcast({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _plugin.zonedSchedule(
      title.hashCode,
      title,
      body.isNotEmpty ? body : 'Broadcast fra admin',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'broadcasts',
          'Broadcasts',
          channelDescription: 'Broadcast beskeder fra admin',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
