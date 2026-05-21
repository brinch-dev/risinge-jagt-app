import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:jagt_app/bootstrap.dart';

final areaBoundariesProvider =
    AsyncNotifierProvider<AreaBoundariesNotifier, Map<String, List<LatLng>>>(
  AreaBoundariesNotifier.new,
);

class AreaBoundariesNotifier extends AsyncNotifier<Map<String, List<LatLng>>> {
  @override
  Future<Map<String, List<LatLng>>> build() => _fetch();

  Future<Map<String, List<LatLng>>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('area_boundaries')
        .select()
        .order('area_id')
        .order('point_order');

    final Map<String, List<LatLng>> result = {};
    for (final row in data as List) {
      final areaId = row['area_id'] as String;
      result.putIfAbsent(areaId, () => []);
      result[areaId]!.add(LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      ));
    }
    return result;
  }

  Future<void> saveBoundary(String areaId, List<LatLng> points) async {
    final client = ref.read(supabaseProvider);

    await client.from('area_boundaries').delete().eq('area_id', areaId);

    final rows = points
        .asMap()
        .entries
        .map((e) => {
              'area_id': areaId,
              'point_order': e.key,
              'latitude': e.value.latitude,
              'longitude': e.value.longitude,
            })
        .toList();

    if (rows.isNotEmpty) {
      await client.from('area_boundaries').insert(rows);
    }

    state = AsyncData(await _fetch());
  }
}
