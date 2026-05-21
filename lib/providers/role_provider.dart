import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/bootstrap.dart';

class AppRole {
  final String id;
  final String label;
  final int sortOrder;
  final bool isSystem;

  const AppRole({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.isSystem = false,
  });

  factory AppRole.fromJson(Map<String, dynamic> json) {
    return AppRole(
      id: json['id'] as String,
      label: json['label'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isSystem: json['is_system'] as bool? ?? false,
    );
  }
}

class RolesNotifier extends AsyncNotifier<List<AppRole>> {
  @override
  Future<List<AppRole>> build() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('roles')
        .select()
        .order('sort_order', ascending: true);
    return (data as List).map((e) => AppRole.fromJson(e)).toList();
  }

  Future<void> createRole(String id, String label) async {
    final client = ref.read(supabaseProvider);
    final current = state.value ?? [];
    final maxSort = current.isEmpty
        ? 0
        : current.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b);
    await client.from('roles').insert({
      'id': id,
      'label': label,
      'sort_order': maxSort + 1,
      'is_system': false,
    });
    ref.invalidateSelf();
  }

  Future<void> updateRole(String id, String label) async {
    final client = ref.read(supabaseProvider);
    await client.from('roles').update({'label': label}).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteRole(String id) async {
    final client = ref.read(supabaseProvider);
    await client.from('profiles').update({'role': 'gaest'}).eq('role', id);
    await _removeRoleFromAllChannels(id);
    await client.from('roles').delete().eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> _removeRoleFromAllChannels(String roleId) async {
    final client = ref.read(supabaseProvider);
    final channels = await client
        .from('chat_channels')
        .select('id, required_roles')
        .eq('type', 'general');
    for (final ch in channels) {
      final roles = List<String>.from(ch['required_roles'] ?? []);
      if (roles.contains(roleId)) {
        roles.remove(roleId);
        await client
            .from('chat_channels')
            .update({'required_roles': roles}).eq('id', ch['id']);
      }
    }
  }

  Future<void> setChannelAccess(
      String roleId, String channelId, bool hasAccess) async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('chat_channels')
        .select('required_roles')
        .eq('id', channelId)
        .single();
    final roles = List<String>.from(data['required_roles'] ?? []);
    if (hasAccess && !roles.contains(roleId)) {
      roles.add(roleId);
    } else if (!hasAccess && roles.contains(roleId)) {
      roles.remove(roleId);
    }
    await client
        .from('chat_channels')
        .update({'required_roles': roles}).eq('id', channelId);
  }
}

final rolesProvider =
    AsyncNotifierProvider<RolesNotifier, List<AppRole>>(RolesNotifier.new);

final generalChannelsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseProvider);
  final data = await client
      .from('chat_channels')
      .select('id, name, required_roles')
      .eq('type', 'general')
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});
