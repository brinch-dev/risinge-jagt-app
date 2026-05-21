import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:jagt_app/bootstrap.dart';

class EventBoundary {
  final String eventId;
  final List<LatLng> points;

  const EventBoundary({required this.eventId, required this.points});
}

final eventBoundariesProvider =
    AsyncNotifierProvider<EventBoundariesNotifier, Map<String, List<LatLng>>>(
  EventBoundariesNotifier.new,
);

class EventBoundariesNotifier extends AsyncNotifier<Map<String, List<LatLng>>> {
  @override
  Future<Map<String, List<LatLng>>> build() => _fetch();

  Future<Map<String, List<LatLng>>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('event_boundaries')
        .select()
        .order('event_id')
        .order('point_order');

    final Map<String, List<LatLng>> result = {};
    for (final row in data as List) {
      final eventId = row['event_id'] as String;
      result.putIfAbsent(eventId, () => []);
      result[eventId]!.add(LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ));
    }
    return result;
  }

  Future<void> saveBoundary(String eventId, List<LatLng> points) async {
    final client = ref.read(supabaseProvider);

    await client.from('event_boundaries').delete().eq('event_id', eventId);

    final rows = points
        .asMap()
        .entries
        .map((e) => {
              'event_id': eventId,
              'point_order': e.key,
              'latitude': e.value.latitude,
              'longitude': e.value.longitude,
            })
        .toList();

    if (rows.isNotEmpty) {
      await client.from('event_boundaries').insert(rows);
    }

    state = AsyncData(await _fetch());
  }
}
