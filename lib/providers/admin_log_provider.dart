import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/admin_log_entry.dart';

class AdminLogNotifier extends AsyncNotifier<List<AdminLogEntry>> {
  @override
  Future<List<AdminLogEntry>> build() => _fetch();

  Future<List<AdminLogEntry>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('admin_log')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return (data as List).map((e) => AdminLogEntry.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }
}

final adminLogProvider =
    AsyncNotifierProvider<AdminLogNotifier, List<AdminLogEntry>>(
  AdminLogNotifier.new,
);

Future<void> writeAdminLog(
  WidgetRef ref, {
  required String type,
  required String message,
  String? userId,
  String? userName,
  String? referenceId,
  Map<String, dynamic>? metadata,
}) async {
  try {
    final client = ref.read(supabaseProvider);
    await client.from('admin_log').insert({
      'type': type,
      'message': message,
      'user_id': userId,
      'user_name': userName,
      'reference_id': referenceId,
      'metadata': metadata,
    });
  } catch (_) {}
}
