import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/event_comment.dart';

class EventCommentsNotifier extends AsyncNotifier<List<EventComment>> {
  late final String eventId;
  RealtimeChannel? _channel;

  EventCommentsNotifier(this.eventId);

  @override
  Future<List<EventComment>> build() async {
    ref.onDispose(() => _channel?.unsubscribe());
    _subscribe();
    return _fetch();
  }

  Future<List<EventComment>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('event_comments')
        .select('*, profiles(display_name, full_name)')
        .eq('event_id', eventId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => EventComment.fromJson(e)).toList();
  }

  void _subscribe() {
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('event-comments:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_comments',
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

  Future<void> addComment(String body) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;
    await client.from('event_comments').insert({
      'event_id': eventId,
      'user_id': userId,
      'body': body,
    });
    state = AsyncData(await _fetch());
  }

  Future<void> deleteComment(String commentId) async {
    final client = ref.read(supabaseProvider);
    await client.from('event_comments').delete().eq('id', commentId);
    state = AsyncData(await _fetch());
  }
}

final eventCommentsProviderFamily =
    AsyncNotifierProvider.family<EventCommentsNotifier, List<EventComment>, String>(
  (eventId) => EventCommentsNotifier(eventId),
);
