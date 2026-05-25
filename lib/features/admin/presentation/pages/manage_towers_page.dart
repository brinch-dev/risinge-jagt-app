import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:jagt_app/models/hunt_area.dart';
import 'package:jagt_app/models/tower.dart';
import 'package:jagt_app/providers/map_provider.dart';

class ManageTowersPage extends ConsumerStatefulWidget {
  final HuntArea area;
  const ManageTowersPage({super.key, required this.area});

  @override
  ConsumerState<ManageTowersPage> createState() => _ManageTowersPageState();
}

class _ManageTowersPageState extends ConsumerState<ManageTowersPage> {
  final _mapController = MapController();
  LatLng? _tapPosition;

  @override
  Widget build(BuildContext context) {
    final towersAsync = ref.watch(towersProvider);
    final areaTowers = towersAsync.value
            ?.where((t) => t.areaId == widget.area.id)
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Poster - ${widget.area.name}'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.area.center,
                initialZoom: 14,
                onTap: (_, latLng) {
                  setState(() => _tapPosition = latLng);
                  _showAddTowerSheet(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'dk.jagtapp',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: widget.area.center,
                      radius: widget.area.radiusMeters,
                      useRadiusInMeter: true,
                      color: Colors.green.withValues(alpha: 0.15),
                      borderColor: Colors.green,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: areaTowers
                      .map((t) => Marker(
                            point: LatLng(t.lat, t.lng),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.visibility,
                                color: Colors.brown, size: 32),
                          ))
                      .toList(),
                ),
                if (_tapPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _tapPosition!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.add_location,
                            color: Colors.red, size: 36),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.touch_app, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Tryk paa kortet for at placere ny post',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: areaTowers.isEmpty
                ? const Center(child: Text('Ingen poster i dette omraade'))
                : ListView.builder(
                    itemCount: areaTowers.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final tower = areaTowers[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.visibility,
                              color: Colors.brown),
                          title: Text(tower.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tower.description ?? 'Ingen beskrivelse'),
                              if (tower.imageUrls.isNotEmpty)
                                Text(
                                  '${tower.imageUrls.length} billede(r)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditTowerSheet(tower),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(tower),
                              ),
                            ],
                          ),
                          onTap: () {
                            _mapController.move(
                                LatLng(tower.lat, tower.lng), 16);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddTowerSheet(LatLng position) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TowerType selectedType = TowerType.jagttaarn;
    List<String> imageUrls = [];
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ny post',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Navn *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Beskrivelse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Type', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<TowerType>(
                  segments: TowerType.values.map((t) => ButtonSegment(
                    value: t,
                    label: Text(t.label, style: const TextStyle(fontSize: 12)),
                    icon: Icon(_towerTypeIcon(t), size: 18),
                  )).toList(),
                  selected: {selectedType},
                  onSelectionChanged: (s) =>
                      setSheetState(() => selectedType = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Billeder', style: Theme.of(ctx).textTheme.labelLarge),
                    TextButton.icon(
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate, size: 20),
                      label: const Text('Tilfoej'),
                      onPressed: uploading
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1920,
                                maxHeight: 1920,
                                imageQuality: 80,
                              );
                              if (picked == null) return;
                              setSheetState(() => uploading = true);
                              try {
                                final client = Supabase.instance.client;
                                final ext =
                                    picked.path.split('.').last.toLowerCase();
                                final tempId = const Uuid().v4();
                                final fileName = 'new/$tempId.$ext';
                                final bytes = await picked.readAsBytes();
                                await client.storage
                                    .from('towers')
                                    .uploadBinary(
                                      fileName,
                                      bytes,
                                      fileOptions: FileOptions(
                                        contentType: 'image/$ext',
                                      ),
                                    );
                                final url = client.storage
                                    .from('towers')
                                    .getPublicUrl(fileName);
                                setSheetState(() {
                                  imageUrls.add(url);
                                  uploading = false;
                                });
                              } catch (e) {
                                setSheetState(() => uploading = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Upload fejl: $e')),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
                if (imageUrls.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrls[i],
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(() => imageUrls.removeAt(i));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    await ref.read(towersProvider.notifier).createTowerWithImages(
                      name: nameCtrl.text.trim(),
                      lat: position.latitude,
                      lng: position.longitude,
                      areaId: widget.area.id,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      towerType: selectedType,
                      imageUrls: imageUrls,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() => _tapPosition = null);
                  },
                  child: const Text('Opret post'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTowerSheet(Tower tower) {
    final nameCtrl = TextEditingController(text: tower.name);
    final descCtrl = TextEditingController(text: tower.description ?? '');
    TowerType selectedType = tower.towerType;
    List<String> imageUrls = List.from(tower.imageUrls);
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Rediger post',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${tower.lat.toStringAsFixed(5)}, ${tower.lng.toStringAsFixed(5)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Navn *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Beskrivelse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Type', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<TowerType>(
                  segments: TowerType.values.map((t) => ButtonSegment(
                    value: t,
                    label: Text(t.label, style: const TextStyle(fontSize: 12)),
                    icon: Icon(_towerTypeIcon(t), size: 18),
                  )).toList(),
                  selected: {selectedType},
                  onSelectionChanged: (s) =>
                      setSheetState(() => selectedType = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Billeder', style: Theme.of(ctx).textTheme.labelLarge),
                    TextButton.icon(
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate, size: 20),
                      label: const Text('Tilfoej'),
                      onPressed: uploading
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1920,
                                maxHeight: 1920,
                                imageQuality: 80,
                              );
                              if (picked == null) return;
                              setSheetState(() => uploading = true);
                              try {
                                final client = Supabase.instance.client;
                                final ext =
                                    picked.path.split('.').last.toLowerCase();
                                final fileName =
                                    '${tower.id}/${const Uuid().v4()}.$ext';
                                final bytes = await picked.readAsBytes();
                                await client.storage
                                    .from('towers')
                                    .uploadBinary(
                                      fileName,
                                      bytes,
                                      fileOptions: FileOptions(
                                        contentType: 'image/$ext',
                                      ),
                                    );
                                final url = client.storage
                                    .from('towers')
                                    .getPublicUrl(fileName);
                                setSheetState(() {
                                  imageUrls.add(url);
                                  uploading = false;
                                });
                              } catch (e) {
                                setSheetState(() => uploading = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text('Upload fejl: $e')),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
                if (imageUrls.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrls[i],
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(() => imageUrls.removeAt(i));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    await ref.read(towersProvider.notifier).updateTower(tower.id, {
                      'name': nameCtrl.text.trim(),
                      'description': descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      'tower_type': selectedType.dbValue,
                      'image_urls': imageUrls,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Gem'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _towerTypeIcon(TowerType type) {
    switch (type) {
      case TowerType.jagttaarn:
        return Icons.cabin;
      case TowerType.skydestige:
        return Icons.stairs;
      case TowerType.skudlinje:
        return Icons.crisis_alert;
    }
  }

  void _confirmDelete(Tower tower) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet post'),
        content: Text('Slet "${tower.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(towersProvider.notifier).deleteTower(tower.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }
}
