import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:jagt_app/models/hunt_area.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/providers/location_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/providers/area_boundary_provider.dart';

class CreateAreaPage extends ConsumerStatefulWidget {
  const CreateAreaPage({super.key});

  @override
  ConsumerState<CreateAreaPage> createState() => _CreateAreaPageState();
}

class _CreateAreaPageState extends ConsumerState<CreateAreaPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _alarmTextCtrl = TextEditingController(
      text: 'Advarsel: Du nærmer dig jagtområdets grænse! Vend om.');
  final _alarmMarginCtrl = TextEditingController(text: '100');
  final _addressCtrl = TextEditingController();
  final _mapController = MapController();

  bool _isLoading = false;
  bool _isSearching = false;
  List<_SearchResult> _searchResults = [];
  bool _drawingBoundary = false;
  final List<LatLng> _boundaryPoints = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _searchAddress() async {
    final query = _addressCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=dk');
      final response = await http.get(uri, headers: {
        'User-Agent': 'JagtApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _searchResults = data
              .map((e) => _SearchResult(
                    name: e['display_name'] as String,
                    lat: double.parse(e['lat'] as String),
                    lng: double.parse(e['lon'] as String),
                  ))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _isSearching = false);
  }

  void _selectSearchResult(_SearchResult result) {
    setState(() {
      _searchResults = [];
      _addressCtrl.text = result.name;
    });
    _mapController.move(LatLng(result.lat, result.lng), 15);
  }

  LatLng _getCentroid() {
    if (_boundaryPoints.isEmpty) return const LatLng(55.3835, 10.6100);
    double lat = 0, lng = 0;
    for (final p in _boundaryPoints) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / _boundaryPoints.length, lng / _boundaryPoints.length);
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Angiv et områdenavn')),
      );
      return;
    }
    if (_boundaryPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tegn mindst 3 punkter på kortet')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final centroid = _getCentroid();

      final area = HuntArea(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        centerLat: centroid.latitude,
        centerLng: centroid.longitude,
        radiusMeters: 0,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        alarmText: _alarmTextCtrl.text.trim(),
        alarmMarginMeters: double.tryParse(_alarmMarginCtrl.text) ?? 100,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      await ref.read(huntAreasProvider.notifier).createArea(area);

      await ref
          .read(areaBoundariesProvider.notifier)
          .saveBoundary(area.id, _boundaryPoints);

      final profile = ref.read(userProfileProvider).value;
      await writeAdminLog(ref,
          type: 'area_created',
          message:
              '${profile?.displayName ?? 'Admin'} oprettede område: ${area.name}',
          userId: userId,
          userName: profile?.displayName,
          referenceId: area.id);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _alarmTextCtrl.dispose();
    _alarmMarginCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  LatLng _getInitialCenter() {
    final pos = ref.read(currentPositionProvider).value;
    if (pos != null) return LatLng(pos.latitude, pos.longitude);
    return const LatLng(55.3835, 10.6100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nyt jagtområde'),
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _getInitialCenter(),
                    initialZoom: 13,
                    onTap: (_, latLng) {
                      if (_drawingBoundary) {
                        setState(() => _boundaryPoints.add(latLng));
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'dk.jagtapp',
                    ),
                    if (_boundaryPoints.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _boundaryPoints,
                            color: Colors.green.withValues(alpha: 0.2),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    if (_boundaryPoints.length >= 2 &&
                        _boundaryPoints.length < 3)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _boundaryPoints,
                            color: Colors.green,
                            strokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: _boundaryPoints
                          .asMap()
                          .entries
                          .map((e) => Marker(
                                point: e.value,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: e.key == 0
                                        ? Colors.green
                                        : Colors.green.shade700,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${e.key + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'draw',
                        backgroundColor:
                            _drawingBoundary ? Colors.red : Colors.green,
                        onPressed: () {
                          setState(
                              () => _drawingBoundary = !_drawingBoundary);
                        },
                        child: Icon(
                            _drawingBoundary ? Icons.stop : Icons.draw),
                      ),
                      const SizedBox(height: 4),
                      FloatingActionButton.small(
                        heroTag: 'mypos',
                        onPressed: () {
                          final pos = ref.read(currentPositionProvider).value;
                          if (pos != null) {
                            _mapController.move(
                                LatLng(pos.latitude, pos.longitude), 15);
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                      if (_boundaryPoints.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        FloatingActionButton.small(
                          heroTag: 'undo',
                          backgroundColor: Colors.orange,
                          onPressed: () {
                            setState(() => _boundaryPoints.removeLast());
                          },
                          child: const Icon(Icons.undo),
                        ),
                        const SizedBox(height: 4),
                        FloatingActionButton.small(
                          heroTag: 'clear',
                          backgroundColor: Colors.grey,
                          onPressed: () {
                            setState(() => _boundaryPoints.clear());
                          },
                          child: const Icon(Icons.delete),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_drawingBoundary)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tegner: ${_boundaryPoints.length} punkt${_boundaryPoints.length == 1 ? '' : 'er'}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: 'Søg adresse',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchAddress,
                          ),
                  ),
                  onSubmitted: (_) => _searchAddress(),
                ),
                if (_searchResults.isNotEmpty)
                  Card(
                    child: Column(
                      children: _searchResults
                          .map((r) => ListTile(
                                title: Text(r.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                dense: true,
                                onTap: () => _selectSearchResult(r),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Områdenavn *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Beskrivelse',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text('Geofencing alarm',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _alarmTextCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alarm-tekst',
                    border: OutlineInputBorder(),
                    helperText:
                        'Teksten der vises når brugeren nærmer sig grænsen',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _alarmMarginCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alarm margin (meter før grænse)',
                    border: OutlineInputBorder(),
                    suffixText: 'm',
                    helperText:
                        'Hvor mange meter før grænsen skal advarslen komme',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_boundaryPoints.length} punkter tegnet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isLoading ? null : _create,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Opret jagtområde'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String name;
  final double lat;
  final double lng;

  const _SearchResult({
    required this.name,
    required this.lat,
    required this.lng,
  });
}
