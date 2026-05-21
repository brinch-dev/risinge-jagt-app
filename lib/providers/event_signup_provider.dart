import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/event_signup.dart';

class EventSignupsNotifier extends AsyncNotifier<List<EventSignup>> {
  RealtimeChannel? _channel;

  @override
  Future<List<EventSignup>> build() async {
    final data = await _fetch();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return data;
  }

  Future<List<EventSignup>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('event_signups')
        .select('*, profiles(display_name, full_name)')
        .order('signed_up_at');
    return (data as List).map((e) => EventSignup.fromJson(e)).toList();
  }

  void _subscribeRealtime() {
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('event_signups_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_signups',
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .subscribe();
  }

  Future<void> signup(String eventId) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;
    await client.from('event_signups').upsert({
      'event_id': eventId,
      'user_id': userId,
      'status': 'attending',
    }, onConflict: 'event_id,user_id');
    state = AsyncData(await _fetch());
  }

  Future<void> decline(String eventId) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;
    await client.from('event_signups').upsert({
      'event_id': eventId,
      'user_id': userId,
      'status': 'not_attending',
    }, onConflict: 'event_id,user_id');
    state = AsyncData(await _fetch());
  }

  Future<void> unsignup(String eventId) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;
    await client
        .from('event_signups')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
    state = AsyncData(await _fetch());
  }

  bool isSignedUp(String eventId, String userId) {
    return (state.value ?? [])
        .any((s) => s.eventId == eventId && s.userId == userId && s.isAttending);
  }

  SignupStatus? getStatus(String eventId, String userId) {
    final signup = (state.value ?? [])
        .where((s) => s.eventId == eventId && s.userId == userId)
        .firstOrNull;
    return signup?.status;
  }

  List<EventSignup> getForEvent(String eventId) {
    return (state.value ?? []).where((s) => s.eventId == eventId).toList();
  }

  List<String> getMyEventIds(String userId) {
    return (state.value ?? [])
        .where((s) => s.userId == userId && s.isAttending)
        .map((s) => s.eventId)
        .toList();
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }
}

final eventSignupsProvider =
    AsyncNotifierProvider<EventSignupsNotifier, List<EventSignup>>(
  EventSignupsNotifier.new,
);
