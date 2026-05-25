import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/hunt_event.dart';

final eventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<HuntEvent>>(EventsNotifier.new);

class EventsNotifier extends AsyncNotifier<List<HuntEvent>> {
  RealtimeChannel? _channel;

  @override
  Future<List<HuntEvent>> build() async {
    final data = await _fetchEvents();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return data;
  }

  void _subscribeRealtime() {
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('hunt_events_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hunt_events',
          callback: (_) async {
            state = AsyncData(await _fetchEvents());
          },
        )
        .subscribe();
  }

  Future<List<HuntEvent>> _fetchEvents() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('hunt_events')
        .select('*, hunt_areas(name)')
        .order('date', ascending: true);
    return (data as List).map((e) => HuntEvent.fromJson(e)).toList();
  }

  Future<HuntEvent> createEvent(HuntEvent event) async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('hunt_events')
        .insert(event.toJson())
        .select('*, hunt_areas(name)')
        .single();
    state = AsyncData(await _fetchEvents());
    return HuntEvent.fromJson(data);
  }

  Future<void> updateEvent(String id, Map<String, dynamic> updates) async {
    final client = ref.read(supabaseProvider);
    await client.from('hunt_events').update(updates).eq('id', id);
    state = AsyncData(await _fetchEvents());
  }

  Future<void> deleteEvent(String id) async {
    final client = ref.read(supabaseProvider);
    await client.from('hunt_events').delete().eq('id', id);
    state = AsyncData(await _fetchEvents());
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetchEvents());
  }
}

final eventsForDateProvider =
    Provider.family<List<HuntEvent>, DateTime>((ref, date) {
  final events = ref.watch(eventsProvider).value ?? [];
  return events.where((e) {
    return e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day;
  }).toList();
});

final upcomingEventsProvider = Provider<List<HuntEvent>>((ref) {
  final events = ref.watch(eventsProvider).value ?? [];
  final now = DateTime.now();
  return events.where((e) => !_isEventEnded(e, now)).toList();
});

bool _isEventEnded(HuntEvent event, DateTime now) {
  if (event.endTime != null) {
    final parts = event.endTime!.split(':');
    if (parts.length >= 2) {
      final endDateTime = DateTime(
        event.date.year, event.date.month, event.date.day,
        int.tryParse(parts[0]) ?? 23,
        int.tryParse(parts[1]) ?? 59,
      );
      return now.isAfter(endDateTime);
    }
  }
  final endOfDay = DateTime(event.date.year, event.date.month, event.date.day, 23, 59);
  return now.isAfter(endOfDay);
}
