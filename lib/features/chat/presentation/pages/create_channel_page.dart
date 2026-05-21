import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/providers/chat_provider.dart';
import 'package:jagt_app/models/chat_channel.dart';
import 'package:jagt_app/features/chat/presentation/pages/chat_page.dart';

class CreateChannelPage extends ConsumerStatefulWidget {
  const CreateChannelPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateChannelPage> createState() => _CreateChannelPageState();
}

class _CreateChannelPageState extends ConsumerState<CreateChannelPage> {
  final _nameController = TextEditingController();
  ChannelType _type = ChannelType.private;
  final Set<String> _selectedMembers = {};
  final Map<String, String> _memberNames = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isGroup => _type == ChannelType.group;

  String _autoName() {
    if (_selectedMembers.isEmpty) return '';
    final names = _selectedMembers
        .map((id) => _memberNames[id] ?? 'Ukendt')
        .toList();
    return names.join(', ');
  }

  Future<void> _create() async {
    if (_selectedMembers.isEmpty) return;

    final name = _isGroup
        ? _nameController.text.trim()
        : _autoName();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final channel =
          await ref.read(chatChannelsProvider.notifier).createChannel(
                name,
                _type,
                _selectedMembers.toList(),
              );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              channelId: channel.id,
              channelName: channel.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ny samtale'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ChannelType>(
            segments: const [
              ButtonSegment(
                value: ChannelType.private,
                label: Text('Privat'),
                icon: Icon(Icons.person),
              ),
              ButtonSegment(
                value: ChannelType.group,
                label: Text('Gruppe'),
                icon: Icon(Icons.group),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          if (_isGroup) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Gruppenavn *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            _isGroup ? 'Vælg medlemmer' : 'Vælg person',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Fejl: $e'),
            data: (members) {
              final filtered = members
                  .where((m) => m['id'] != currentUserId)
                  .toList();

              for (final m in filtered) {
                _memberNames[m['id'] as String] =
                    m['display_name'] as String? ?? m['email'] as String;
              }

              return Column(
                children: filtered.map((m) {
                  final id = m['id'] as String;
                  final name =
                      m['display_name'] as String? ?? m['email'] as String;

                  if (_isGroup) {
                    return CheckboxListTile(
                      title: Text(name),
                      subtitle: Text(m['email'] as String),
                      value: _selectedMembers.contains(id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedMembers.add(id);
                          } else {
                            _selectedMembers.remove(id);
                          }
                        });
                      },
                    );
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(m['email'] as String),
                    selected: _selectedMembers.contains(id),
                    selectedTileColor: Colors.blue.shade50,
                    enabled: !_isLoading,
                    onTap: () {
                      setState(() {
                        _selectedMembers.clear();
                        _selectedMembers.add(id);
                      });
                      _create();
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _isGroup
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed:
                    _isLoading || _selectedMembers.isEmpty ? null : _create,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Opret gruppe'),
              ),
            )
          : null,
    );
  }
}
