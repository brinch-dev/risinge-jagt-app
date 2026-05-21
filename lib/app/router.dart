import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/features/auth/presentation/pages/login_page.dart';
import 'package:jagt_app/features/home/home_shell.dart';
import 'package:jagt_app/features/admin/presentation/pages/admin_panel_page.dart';
import 'package:jagt_app/features/chat/presentation/pages/chat_page.dart';
import 'package:jagt_app/services/push_notification_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isOnLogin = state.matchedLocation == '/login';

      if (user == null && !isOnLogin) return '/login';
      if (user != null && isOnLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPanelPage(),
      ),
      GoRoute(
        path: '/chat/:channelId',
        name: 'chat',
        builder: (context, state) => ChatPage(
          channelId: state.pathParameters['channelId']!,
          channelName: state.uri.queryParameters['name'] ?? 'Chat',
        ),
      ),
    ],
  );
});
