import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/providers/role_provider.dart';

final adminChannelsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseProvider);
  final data = await client
      .from('chat_channels')
      .select()
      .eq('type', 'general')
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});

class ManageChannelsPage extends ConsumerWidget {
  const ManageChannelsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(adminChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat-kanaler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditChannelPage(channel: null),
              ),
            ),
          ),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (channels) {
          if (channels.isEmpty) {
            return const Center(child: Text('Ingen kanaler'));
          }
          return ReorderableListView.builder(
            itemCount: channels.length,
            padding: const EdgeInsets.all(8),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              if (oldIndex == newIndex) return;
              final reordered = List<Map<String, dynamic>>.from(channels);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              final client = ref.read(supabaseProvider);
              for (var i = 0; i < reordered.length; i++) {
                await client
                    .from('chat_channels')
                    .update({'sort_order': i})
                    .eq('id', reordered[i]['id']);
              }
              ref.invalidate(adminChannelsProvider);
            },
            itemBuilder: (context, index) {
              final ch = channels[index];
              final roles = List<String>.from(ch['required_roles'] ?? []);
              return Card(
                key: ValueKey(ch['id']),
                child: ListTile(
                  leading: Icon(
                    Icons.chat,
                    color: roles.isEmpty
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                  title: Text(ch['name'] as String),
                  subtitle: Row(
                    children: [
                      if (roles.isEmpty)
                        Text('Alle roller',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade700))
                      else
                        Text('${roles.length} roller',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue.shade700)),
                      if (ch['is_predefined'] == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Standard',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_right),
                      const SizedBox(width: 4),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditChannelPage(channel: ch),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EditChannelPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? channel;

  const EditChannelPage({Key? key, required this.channel}) : super(key: key);

  @override
  ConsumerState<EditChannelPage> createState() => _EditChannelPageState();
}

class _EditChannelPageState extends ConsumerState<EditChannelPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late List<String> _selectedRoles;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.channel == null;
    _nameCtrl = TextEditingController(
        text: widget.channel?['name'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: widget.channel?['description'] as String? ?? '');
    _selectedRoles = List<String>.from(
        widget.channel?['required_roles'] as List? ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Ny kanal' : 'Rediger kanal'),
        actions: [
          if (!_isNew && widget.channel?['is_predefined'] != true)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDelete,
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
                  Text('Kanal-navn',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Navn',
                      border: OutlineInputBorder(),
                      hintText: 'F.eks. Jagt-snak',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Beskrivelse (valgfrit)',
                      border: OutlineInputBorder(),
                      hintText: 'Hvad bruges denne kanal til?',
                    ),
                    maxLines: 2,
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
                  Row(
                    children: [
                      const Icon(Icons.visibility, size: 20),
                      const SizedBox(width: 8),
                      Text('Rolle-adgang',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedRoles.isEmpty
                        ? 'Alle roller har adgang'
                        : 'Kun valgte roller har adgang',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  rolesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Fejl: $e'),
                    data: (roles) => Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('Alle roller'),
                          subtitle: const Text('Synlig for alle'),
                          value: _selectedRoles.isEmpty,
                          onChanged: (v) {
                            if (v == true) {
                              setState(() => _selectedRoles.clear());
                            }
                          },
                        ),
                        const Divider(),
                        ...roles.map((role) => CheckboxListTile(
                              title: Text(role.label),
                              subtitle: Text(role.id),
                              value: _selectedRoles.contains(role.id),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedRoles.add(role.id);
                                  } else {
                                    _selectedRoles.remove(role.id);
                                  }
                                });
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(_isNew ? 'Opret' : 'Gem'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navn er påkrævet')),
      );
      return;
    }

    final client = ref.read(supabaseProvider);

    final desc = _descCtrl.text.trim();

    if (_isNew) {
      final userId = client.auth.currentUser!.id;
      await client.from('chat_channels').insert({
        'name': name,
        'type': 'general',
        'created_by': userId,
        'required_roles': _selectedRoles,
        'description': desc.isEmpty ? null : desc,
      });
    } else {
      await client.from('chat_channels').update({
        'name': name,
        'required_roles': _selectedRoles,
        'description': desc.isEmpty ? null : desc,
      }).eq('id', widget.channel!['id']);
    }

    ref.invalidate(adminChannelsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isNew ? 'Kanal oprettet' : 'Kanal opdateret')),
      );
      Navigator.pop(context);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet kanal'),
        content: Text(
            'Slet "${_nameCtrl.text}"? Alle beskeder i kanalen slettes også.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final client = ref.read(supabaseProvider);
              final id = widget.channel!['id'] as String;
              await client
                  .from('chat_messages')
                  .delete()
                  .eq('channel_id', id);
              await client
                  .from('channel_members')
                  .delete()
                  .eq('channel_id', id);
              await client.from('chat_channels').delete().eq('id', id);
              ref.invalidate(adminChannelsProvider);
              if (mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }
}
