import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/event_checkin.dart';

final checkinProviderFamily =
    AsyncNotifierProvider.family<CheckinNotifier, EventCheckin?, String>(
  (eventId) => CheckinNotifier(eventId),
);

class CheckinNotifier extends AsyncNotifier<EventCheckin?> {
  final String eventId;
  CheckinNotifier(this.eventId);

  @override
  Future<EventCheckin?> build() => _fetch();

  Future<EventCheckin?> _fetch() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await client
        .from('event_checkins')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return EventCheckin.fromJson(data as Map<String, dynamic>);
  }

  Future<void> checkIn() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('event_checkins').upsert(
      {
        'event_id': eventId,
        'user_id': userId,
        'checked_in_at': DateTime.now().toIso8601String(),
        'checked_out_at': null,
      },
      onConflict: 'event_id,user_id',
    );
    state = AsyncData(await _fetch());
  }

  Future<void> checkOut() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final now = DateTime.now().toIso8601String();
    await client.from('event_checkins').upsert(
      {
        'event_id': eventId,
        'user_id': userId,
        'checked_out_at': now,
      },
      onConflict: 'event_id,user_id',
    );
    // Cancel all tower/ladder reservations for this user+event on check-out
    await client
        .from('tower_reservations')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
    state = AsyncData(await _fetch());
  }
}

final allCheckinsProviderFamily =
    FutureProvider.family<List<EventCheckin>, String>((ref, eventId) async {
  final client = ref.read(supabaseProvider);
  final data = await client
      .from('event_checkins')
      .select()
      .eq('event_id', eventId)
      .not('checked_in_at', 'is', null);
  return (data as List).map((e) => EventCheckin.fromJson(e)).toList();
});
