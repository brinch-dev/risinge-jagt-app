import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/role_provider.dart';

final allUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final client = ref.read(supabaseProvider);
  final data = await client.from('profiles').select().order('created_at');
  return (data as List).map((e) => UserProfile.fromJson(e)).toList();
});

class ManageUsersPage extends ConsumerWidget {
  const ManageUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Brugere'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (users) {
          final currentUserId =
              Supabase.instance.client.auth.currentUser?.id;
          return ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _roleColor(user.role),
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(user.displayName.isEmpty
                      ? user.email
                      : user.displayName),
                  subtitle: Text('${user.email}\n${user.role.label}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RoleMenuButton(
                        user: user,
                        currentUserId: currentUserId,
                        ref: ref,
                      ),
                      if (user.id != currentUserId)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                          onPressed: () => _confirmDeleteUser(context, ref, user),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _roleColor(UserRole role) {
    return _roleColorFromId(role.dbValue);
  }

  void _confirmDeleteUser(BuildContext context, WidgetRef ref, UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet bruger'),
        content: Text('Er du sikker på at du vil slette "${user.displayName.isEmpty ? user.email : user.displayName}"?\n\nDette sletter brugerens profil. Brugeren vil ikke længere kunne logge ind.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final client = ref.read(supabaseProvider);
              await client.from('profiles').delete().eq('id', user.id);
              await writeAdminLog(ref,
                  type: 'user_delete',
                  message: '${user.displayName.isEmpty ? user.email : user.displayName} slettet',
                  userId: user.id,
                  userName: user.displayName.isEmpty ? user.email : user.displayName);
              ref.invalidate(allUsersProvider);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }
}

Color _roleColorFromId(String roleId) {
  switch (roleId) {
    case 'admin':
      return Colors.amber.shade200;
    case 'jaeger_medlem':
      return Colors.green.shade200;
    case 'ejer':
      return Colors.purple.shade200;
    case 'forvalter':
      return Colors.blue.shade200;
    case 'bb_direktoer':
      return Colors.orange.shade200;
    case 'jagt_gaest':
      return Colors.teal.shade200;
    case 'gaest':
      return Colors.grey.shade300;
    default:
      return Colors.indigo.shade200;
  }
}

class _RoleMenuButton extends ConsumerWidget {
  final UserProfile user;
  final String? currentUserId;
  final WidgetRef ref;

  const _RoleMenuButton({
    required this.user,
    required this.currentUserId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(rolesProvider);

    return rolesAsync.when(
      loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => PopupMenuButton<UserRole>(
        icon: const Icon(Icons.edit),
        itemBuilder: (_) => UserRole.values.map((r) => PopupMenuItem(value: r, child: Text(r.label))).toList(),
        onSelected: (r) => _changeRole(context, r.dbValue, r.label),
      ),
      data: (roles) => PopupMenuButton<String>(
        icon: const Icon(Icons.edit),
        onSelected: (newRoleId) {
          final role = roles.firstWhere((r) => r.id == newRoleId);
          _changeRole(context, newRoleId, role.label);
        },
        itemBuilder: (_) => roles.map((r) {
          return PopupMenuItem(
            value: r.id,
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: _roleColorFromId(r.id)),
                const SizedBox(width: 8),
                Text(r.label),
                if (r.id == user.role.dbValue) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _changeRole(BuildContext context, String newRoleId, String newLabel) async {
    if (newRoleId == user.role.dbValue) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skift rolle'),
        content: Text(
            'Skift ${user.displayName} fra ${user.role.label} til $newLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Skift'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final client = ref.read(supabaseProvider);
    await client.from('profiles').update({'role': newRoleId}).eq('id', user.id);
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    await writeAdminLog(ref,
        type: 'role_change',
        message: '${user.displayName} rolle ændret fra ${user.role.label} til $newLabel',
        userId: user.id,
        userName: user.displayName,
        metadata: {
          'old_role': user.role.dbValue,
          'new_role': newRoleId,
          'changed_by': adminId,
        });
    ref.invalidate(allUsersProvider);
    if (user.id == currentUserId) {
      ref.invalidate(userProfileProvider);
    }
  }
}
