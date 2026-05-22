import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/providers/homepage_provider.dart';
import 'package:jagt_app/providers/role_provider.dart';

const _blockTypeLabels = {
  'hero': 'Hero billede',
  'welcome': 'Velkomsttekst',
  'text': 'Tekst',
  'announcement': 'Meddelelse',
  'image': 'Billede',
  'next_event': 'Næste event',
  'event_stats': 'Event-statistik',
  'weather': 'Vejrudsigt',
  'my_reservations': 'Mine reservationer',
  'recent_chat': 'Seneste chat',
  'countdown': 'Nedtælling',
};

const _blockTypeIcons = {
  'hero': Icons.image,
  'welcome': Icons.waving_hand,
  'text': Icons.article,
  'announcement': Icons.campaign,
  'image': Icons.photo,
  'next_event': Icons.event,
  'event_stats': Icons.bar_chart,
  'weather': Icons.wb_sunny,
  'my_reservations': Icons.bookmark,
  'recent_chat': Icons.forum,
  'countdown': Icons.timer,
};

class ManageHomepagePage extends ConsumerWidget {
  const ManageHomepagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(homeBlocksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rediger forside'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (blocks) {
          if (blocks.isEmpty) {
            return const Center(child: Text('Ingen blokke endnu'));
          }
          return ReorderableListView.builder(
            itemCount: blocks.length,
            padding: const EdgeInsets.all(8),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final block = blocks[oldIndex];
              final targetOrder = blocks[newIndex].sortOrder;
              await ref
                  .read(homeBlocksProvider.notifier)
                  .reorder(block.id, targetOrder);
            },
            itemBuilder: (context, index) {
              final block = blocks[index];
              final typeLabel =
                  _blockTypeLabels[block.blockType] ?? block.blockType;
              final typeIcon =
                  _blockTypeIcons[block.blockType] ?? Icons.extension;

              return Card(
                key: ValueKey(block.id),
                child: ListTile(
                  leading: Icon(
                    typeIcon,
                    color: block.isActive ? Colors.green.shade700 : Colors.grey,
                  ),
                  title: Text(
                    block.title ?? typeLabel,
                    style: TextStyle(
                      color: block.isActive ? null : Colors.grey,
                      decoration:
                          block.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(typeLabel,
                            style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      if (block.visibleRoles.isNotEmpty)
                        Icon(Icons.lock, size: 14, color: Colors.orange.shade700)
                      else
                        Icon(Icons.public, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 2),
                      Text(
                        block.visibleRoles.isEmpty
                            ? 'Alle'
                            : '${block.visibleRoles.length} roller',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: block.isActive,
                        onChanged: (v) => ref
                            .read(homeBlocksProvider.notifier)
                            .toggleActive(block.id, v),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditBlockPage(block: block),
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

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tilføj blok'),
        children: _blockTypeLabels.entries
            .where((e) => e.key != 'hero')
            .map((e) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditBlockPage(block: null, newType: e.key),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(_blockTypeIcons[e.key], size: 20),
                      const SizedBox(width: 12),
                      Text(e.value),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class EditBlockPage extends ConsumerStatefulWidget {
  final HomeBlock? block;
  final String? newType;

  const EditBlockPage({Key? key, this.block, this.newType}) : super(key: key);

  @override
  ConsumerState<EditBlockPage> createState() => _EditBlockPageState();
}

class _EditBlockPageState extends ConsumerState<EditBlockPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _imageUrlCtrl;
  late List<String> _selectedRoles;
  late String _blockType;
  bool _isNew = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.block == null;
    _blockType = widget.block?.blockType ?? widget.newType ?? 'text';
    _titleCtrl = TextEditingController(text: widget.block?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.block?.content ?? '');
    _imageUrlCtrl = TextEditingController(text: widget.block?.imageUrl ?? '');
    _selectedRoles = List<String>.from(widget.block?.visibleRoles ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  static const _dynamicTypes = {
    'next_event', 'event_stats', 'weather', 'my_reservations',
    'recent_chat', 'countdown',
  };

  bool get _hasTitle =>
      !_dynamicTypes.contains(_blockType);

  bool get _hasContent =>
      ['welcome', 'text', 'announcement', 'hero'].contains(_blockType);

  bool get _hasImageUrl => ['image', 'hero'].contains(_blockType);

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);
    final typeLabel = _blockTypeLabels[_blockType] ?? _blockType;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Ny $typeLabel' : 'Rediger $typeLabel'),
        actions: [
          if (!_isNew && _blockType != 'hero')
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
                  Row(
                    children: [
                      Icon(_blockTypeIcons[_blockType] ?? Icons.extension,
                          size: 20),
                      const SizedBox(width: 8),
                      Text('Type: $typeLabel',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_dynamicTypes.contains(_blockType)) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Denne blok genereres automatisk fra app-data. Brug synlighed nedenfor til at styre hvem der ser den.',
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_hasTitle) ...[
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Titel',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_hasContent) ...[
                    TextField(
                      controller: _contentCtrl,
                      decoration: InputDecoration(
                        labelText: _blockType == 'welcome'
                            ? 'Undertitel'
                            : 'Indhold',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: _blockType == 'welcome' ? 2 : 6,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_hasImageUrl) ...[
                    if (_imageUrlCtrl.text.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrlCtrl.text,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: Text('Kan ikke vise billede')),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickAndUpload,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.upload),
                            label: Text(
                                _uploading ? 'Uploader...' : 'Upload billede'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showUrlDialog(),
                            icon: const Icon(Icons.link),
                            label: const Text('Indsæt URL'),
                          ),
                        ),
                      ],
                    ),
                    if (_imageUrlCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _imageUrlCtrl.text,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _imageUrlCtrl.clear()),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
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
                      Text('Synlighed',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedRoles.isEmpty
                        ? 'Synlig for alle roller'
                        : 'Kun synlig for valgte roller',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
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

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final client = ref.read(supabaseProvider);
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final fileName =
          'block_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await client.storage.from('homepage').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );

      final publicUrl =
          client.storage.from('homepage').getPublicUrl(fileName);

      setState(() {
        _imageUrlCtrl.text = publicUrl;
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl ved upload: $e')),
        );
      }
    }
  }

  void _showUrlDialog() {
    final urlCtrl = TextEditingController(text: _imageUrlCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Billede URL'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _imageUrlCtrl.text = urlCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(homeBlocksProvider.notifier);

    if (_isNew) {
      await notifier.createBlock(
        blockType: _blockType,
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        content:
            _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
        imageUrl: _imageUrlCtrl.text.trim().isEmpty
            ? null
            : _imageUrlCtrl.text.trim(),
        visibleRoles: _selectedRoles,
      );
    } else {
      await notifier.updateBlock(widget.block!.id, {
        'title':
            _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        'content':
            _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
        'image_url': _imageUrlCtrl.text.trim().isEmpty
            ? null
            : _imageUrlCtrl.text.trim(),
        'visible_roles': _selectedRoles,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isNew ? 'Blok oprettet' : 'Blok opdateret')),
      );
      Navigator.pop(context);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet blok'),
        content: Text('Slet "${_titleCtrl.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(homeBlocksProvider.notifier)
                  .deleteBlock(widget.block!.id);
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
