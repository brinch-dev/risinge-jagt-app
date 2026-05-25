import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/providers/role_provider.dart';

class ManageRolesPage extends ConsumerWidget {
  const ManageRolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(rolesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (roles) => ListView.builder(
          itemCount: roles.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final role = roles[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(role.id),
                  child: Text(
                    role.label.isNotEmpty ? role.label[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(role.label),
                subtitle: Text(role.id + (role.isSystem ? ' (system)' : '')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditRolePage(role: role),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final idCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opret ny rolle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Rolle ID *',
                hintText: 'f.eks. jagt_leder',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Visningsnavn *',
                hintText: 'f.eks. Jagt Leder',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              final id = idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
              final label = labelCtrl.text.trim();
              if (id.isEmpty || label.isEmpty) return;
              await ref.read(rolesProvider.notifier).createRole(id, label);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Opret'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String roleId) {
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
}

class EditRolePage extends ConsumerStatefulWidget {
  final AppRole role;
  const EditRolePage({super.key, required this.role});

  @override
  ConsumerState<EditRolePage> createState() => _EditRolePageState();
}

class _EditRolePageState extends ConsumerState<EditRolePage> {
  late final TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.role.label);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(generalChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Rediger: ${widget.role.label}'),
        actions: [
          if (!widget.role.isSystem)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rolle info',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Visningsnavn',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('ID: ${widget.role.id}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (widget.role.isSystem)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Systemrolle — kan ikke slettes',
                          style: TextStyle(
                              color: Colors.orange.shade700, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final label = _labelCtrl.text.trim();
                        if (label.isEmpty) return;
                        await ref
                            .read(rolesProvider.notifier)
                            .updateRole(widget.role.id, label);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rolle opdateret')),
                          );
                        }
                      },
                      child: const Text('Gem navn'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat adgang',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Vælg hvilke chatkanaler denne rolle har adgang til',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  channelsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Fejl: $e'),
                    data: (channels) => Column(
                      children: channels.map((ch) {
                        final requiredRoles =
                            List<String>.from(ch['required_roles'] ?? []);
                        final hasAccess =
                            requiredRoles.contains(widget.role.id);
                        return CheckboxListTile(
                          title: Text(ch['name'] as String),
                          subtitle: Text(
                            '${requiredRoles.length} roller har adgang',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: hasAccess,
                          onChanged: (value) async {
                            await ref
                                .read(rolesProvider.notifier)
                                .setChannelAccess(
                                  widget.role.id,
                                  ch['id'] as String,
                                  value ?? false,
                                );
                            ref.invalidate(generalChannelsProvider);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet rolle'),
        content: Text(
            'Er du sikker? Alle brugere med rollen "${widget.role.label}" bliver sat til Gæst.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(rolesProvider.notifier)
                  .deleteRole(widget.role.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }
}
