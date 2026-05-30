import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/journal_entry.dart';

final journalProvider =
    AsyncNotifierProvider<JournalNotifier, List<JournalEntry>>(
  JournalNotifier.new,
);

class JournalNotifier extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() => _fetch();

  Future<List<JournalEntry>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await client
        .from('personal_journal_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => JournalEntry.fromJson(e)).toList();
  }

  Future<void> addEntry(int kreds, String species, int count) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('personal_journal_entries').insert({
      'user_id': userId,
      'kreds': kreds,
      'species': species,
      'count': count,
    });
    state = AsyncData(await _fetch());
  }

  Future<void> deleteEntry(String id) async {
    final client = ref.read(supabaseProvider);
    await client.from('personal_journal_entries').delete().eq('id', id);
    state = AsyncData(await _fetch());
  }
}
