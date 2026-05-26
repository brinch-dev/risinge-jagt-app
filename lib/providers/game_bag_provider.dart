import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/game_bag_entry.dart';

class MemberShots {
  final String userId;
  final String? displayName;
  final int shots;

  const MemberShots({required this.userId, this.displayName, required this.shots});
}

class GameBagState {
  final List<GameBagEntry> entries;
  final List<MemberShots> memberShots;
  final int? myShots;

  const GameBagState({this.entries = const [], this.memberShots = const [], this.myShots});

  int get totalShots => memberShots.fold<int>(0, (s, m) => s + m.shots);
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
    final userId = client.auth.currentUser?.id;

    final entries = await client
        .from('game_bag_entries')
        .select()
        .eq('event_id', eventId)
        .order('species', ascending: true);

    final shotsRows = await client
        .from('game_bag_totals')
        .select('user_id, total_shots, updated_by')
        .eq('event_id', eventId);

    final memberShots = <MemberShots>[];
    int? myShots;
    for (final row in shotsRows) {
      final uid = (row['user_id'] ?? row['updated_by']) as String?;
      final shots = row['total_shots'] as int?;
      if (uid != null && shots != null) {
        memberShots.add(MemberShots(userId: uid, shots: shots));
        if (uid == userId) myShots = shots;
      }
    }

    return GameBagState(
      entries: (entries as List).map((e) => GameBagEntry.fromJson(e)).toList(),
      memberShots: memberShots,
      myShots: myShots,
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

  Future<void> addOrUpdateEntry(String species, int count) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    await client.from('game_bag_entries').upsert(
      {
        'event_id': eventId,
        'species': species,
        'count': count,
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

  Future<void> setMyShots(int shots) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    await client.from('game_bag_totals').upsert(
      {
        'event_id': eventId,
        'user_id': userId,
        'total_shots': shots,
        'updated_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'event_id,user_id',
    );
    state = AsyncData(await _fetch());
  }
}

final gameBagProviderFamily =
    AsyncNotifierProvider.family<GameBagNotifier, GameBagState, String>(
  (eventId) => GameBagNotifier(eventId),
);
