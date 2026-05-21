import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/app_notification.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/models/user_profile.dart';

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AppNotification>> build() async {
    final data = await _fetch();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return data;
  }

  Future<List<AppNotification>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await client
        .from('app_notifications')
        .select('*, profiles(display_name, full_name)')
        .order('created_at', ascending: false)
        .limit(50);

    final readData = await client
        .from('notification_reads')
        .select('notification_id')
        .eq('user_id', userId);

    final readIds =
        (readData as List).map((e) => e['notification_id'] as String).toSet();

    final profile = ref.read(userProfileProvider).value;
    final userRole = profile?.role.dbValue ?? 'gaest';

    return (data as List)
        .map((e) =>
            AppNotification.fromJson(e, isRead: readIds.contains(e['id'])))
        .where((n) => n.targetRole == 'all' || n.targetRole == userRole)
        .toList();
  }

  void _subscribeRealtime() {
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('notifications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(String notificationId) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await client.from('notification_reads').upsert({
      'user_id': userId,
      'notification_id': notificationId,
    });
    state = AsyncData(await _fetch());
  }

  Future<void> markAllAsRead() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final unread = (state.value ?? []).where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    final inserts = unread
        .map((n) => {'user_id': userId, 'notification_id': n.id})
        .toList();
    await client.from('notification_reads').upsert(inserts);
    state = AsyncData(await _fetch());
  }

  Future<void> sendBroadcast(String title, String body,
      {String? referenceId}) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    await client.from('app_notifications').insert({
      'type': 'broadcast',
      'title': title,
      'body': body,
      'sender_id': userId,
      'target_role': 'all',
      if (referenceId != null) 'reference_id': referenceId,
    });
  }

  Future<void> sendEventNotification(String eventTitle, String eventId) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    await client.from('app_notifications').insert({
      'type': 'new_event',
      'title': 'Ny event: $eventTitle',
      'body': 'En ny jagt-event er oprettet.',
      'sender_id': userId,
      'reference_id': eventId,
      'target_role': 'all',
    });
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});
