import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/hunt_area.dart';
import 'package:jagt_app/models/tower.dart';
import 'package:jagt_app/models/tower_reservation.dart';

final huntAreasProvider =
    AsyncNotifierProvider<HuntAreasNotifier, List<HuntArea>>(
  HuntAreasNotifier.new,
);

class HuntAreasNotifier extends AsyncNotifier<List<HuntArea>> {
  @override
  Future<List<HuntArea>> build() => _fetch();

  Future<List<HuntArea>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data =
        await client.from('hunt_areas').select().order('created_at');
    return (data as List).map((e) => HuntArea.fromJson(e)).toList();
  }

  Future<void> createArea(HuntArea area) async {
    final client = ref.read(supabaseProvider);
    await client.from('hunt_areas').insert(area.toJson());
    state = AsyncData(await _fetch());
  }

  Future<void> updateArea(String id, Map<String, dynamic> updates) async {
    final client = ref.read(supabaseProvider);
    await client.from('hunt_areas').update(updates).eq('id', id);
    state = AsyncData(await _fetch());
  }

  Future<void> deleteArea(String id) async {
    final client = ref.read(supabaseProvider);
    await client.from('hunt_areas').delete().eq('id', id);
    state = AsyncData(await _fetch());
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }
}

final towersProvider =
    AsyncNotifierProvider<TowersNotifier, List<Tower>>(TowersNotifier.new);

class TowersNotifier extends AsyncNotifier<List<Tower>> {
  @override
  Future<List<Tower>> build() => _fetch();

  Future<List<Tower>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data = await client.from('towers').select().order('created_at');
    return (data as List).map((e) => Tower.fromJson(e)).toList();
  }

  Future<void> createTower(Tower tower) async {
    final client = ref.read(supabaseProvider);
    await client.from('towers').insert({
      'name': tower.name,
      'lat': tower.lat,
      'lng': tower.lng,
      'area_id': tower.areaId,
      'description': tower.description,
      'tower_type': tower.towerType.dbValue,
    });
    state = AsyncData(await _fetch());
  }

  Future<void> createTowerWithImages({
    required String name,
    required double lat,
    required double lng,
    required String? areaId,
    String? description,
    required TowerType towerType,
    List<String> imageUrls = const [],
  }) async {
    final client = ref.read(supabaseProvider);
    final data = {
      'name': name,
      'lat': lat,
      'lng': lng,
      'area_id': areaId,
      'description': description,
      'tower_type': towerType.dbValue,
    };
    if (imageUrls.isNotEmpty) {
      data['image_urls'] = imageUrls;
    }
    await client.from('towers').insert(data);
    state = AsyncData(await _fetch());
  }

  Future<void> updateTower(String id, Map<String, dynamic> updates) async {
    final client = ref.read(supabaseProvider);
    await client.from('towers').update(updates).eq('id', id);
    state = AsyncData(await _fetch());
  }

  Future<void> deleteTower(String id) async {
    final client = ref.read(supabaseProvider);
    await client.from('towers').delete().eq('id', id);
    state = AsyncData(await _fetch());
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }
}

class TowerReservationsNotifier extends AsyncNotifier<List<TowerReservation>> {
  RealtimeChannel? _channel;

  @override
  Future<List<TowerReservation>> build() async {
    final data = await _fetch();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return data;
  }

  Future<List<TowerReservation>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('tower_reservations')
        .select('*, profiles(display_name, full_name)')
        .order('reserved_at');
    return (data as List).map((e) => TowerReservation.fromJson(e)).toList();
  }

  void _subscribeRealtime() {
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('tower_reservations_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tower_reservations',
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .subscribe();
  }

  Future<void> reserve(String towerId, String eventId) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;
    await client.from('tower_reservations').insert({
      'tower_id': towerId,
      'event_id': eventId,
      'user_id': userId,
    });
    state = AsyncData(await _fetch());
  }

  Future<void> cancelReservation(String towerId, String eventId) async {
    final client = ref.read(supabaseProvider);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await client
        .from('tower_reservations')
        .delete()
        .eq('tower_id', towerId)
        .eq('event_id', eventId)
        .eq('user_id', userId);
    state = AsyncData(await _fetch());
  }

  TowerReservation? getReservation(String towerId, String eventId) {
    final reservations = state.value ?? [];
    try {
      return reservations.firstWhere(
        (r) => r.towerId == towerId && r.eventId == eventId,
      );
    } catch (_) {
      return null;
    }
  }

  List<TowerReservation> getForEvent(String eventId) {
    return (state.value ?? []).where((r) => r.eventId == eventId).toList();
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }
}

final towerReservationsProvider =
    AsyncNotifierProvider<TowerReservationsNotifier, List<TowerReservation>>(
  TowerReservationsNotifier.new,
);
