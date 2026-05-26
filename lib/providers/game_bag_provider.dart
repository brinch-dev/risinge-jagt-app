import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/game_bag_entry.dart';

class GameBagState {
  final List<GameBagEntry> entries;
  final int? totalShots;

  const GameBagState({this.entries = const [], this.totalShots});
}

class GameBagNotifier extends AsyncNotifier<GameBagState> {
  late final String eventId;
  RealtimeChannel? _channel;

  GameBagNotifier(this.eventId);

  @override
  Future<GameBagState> build() async {
    ref.onDispose(() => _channel?.unsubscribe());
    _subscribe();
    return _fetch();
  }

  Future<GameBagState> _fetch() async {
    final client = ref.read(supabaseProvider);
    final entries = await client
        .from('game_bag_entries')
        .select()
        .eq('event_id', eventId)
        .order('species', ascending: true);
    final totals = await client
        .from('game_bag_totals')
        .select()
        .eq('event_id', eventId)
        .maybeSingle();
    return GameBagState(
      entries: (entries as List).map((e) => GameBagEntry.fromJson(e)).toList(),
      totalShots: totals != null ? totals['total_shots'] as int? : null,
    );
  }

  void _subscribe() {
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('game-bag:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_bag_entries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_bag_totals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .subscribe();
  }

  Future<void> addOrUpdateEntry(String species, int count, {int? shots}) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    await client.from('game_bag_entries').upsert(
      {
        'event_id': eventId,
        'species': species,
        'count': count,
        if (shots != null) 'shots': shots,
        'created_by': userId,
      },
      onConflict: 'event_id,species',
    );
    state = AsyncData(await _fetch());
  }

  Future<void> deleteEntry(String id) async {
    final client = ref.read(supabaseProvider);
    await client.from('game_bag_entries').delete().eq('id', id);
    state = AsyncData(await _fetch());
  }

  Future<void> setTotalShots(int shots) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    await client.from('game_bag_totals').upsert(
      {
        'event_id': eventId,
        'total_shots': shots,
        'updated_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'event_id',
    );
    state = AsyncData(await _fetch());
  }
}

final gameBagProviderFamily =
    AsyncNotifierProvider.family<GameBagNotifier, GameBagState, String>(
  (eventId) => GameBagNotifier(eventId),
);
