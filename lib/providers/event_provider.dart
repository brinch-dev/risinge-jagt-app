import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/hunt_event.dart';

final eventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<HuntEvent>>(EventsNotifier.new);

class EventsNotifier extends AsyncNotifier<List<HuntEvent>> {
  @override
  Future<List<HuntEvent>> build() async {
    return _fetchEvents();
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
  return events.where((e) => e.date.isAfter(now.subtract(const Duration(days: 1)))).toList();
});
