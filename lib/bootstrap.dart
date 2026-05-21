import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:jagt_app/services/notification_service.dart';
import 'package:jagt_app/services/push_notification_service.dart';

Future<ProviderContainer> bootstrapApp() async {
  String supabaseUrl;
  String supabaseAnonKey;

  if (kIsWeb) {
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL',
        defaultValue: 'https://zbmpptfddowmchuyrrea.supabase.co');
    supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_pEJ8OVs9W7iK4abQngIq9A_--XKG5iK');
  } else {
    await dotenv.load(fileName: '.env');
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('Missing Supabase credentials');
  }

  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  if (!kIsWeb) {
    await PushNotificationService().initialize();
    await NotificationService().initialize();
  }

  timeago.setLocaleMessages('da', timeago.DaMessages());
  timeago.setDefaultLocale('da');

  return ProviderContainer();
}

final supabaseProvider = Provider((ref) => Supabase.instance.client);
