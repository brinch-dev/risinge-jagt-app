import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:jagt_app/models/hunt_area.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/providers/location_provider.dart';
import 'package:jagt_app/providers/area_boundary_provider.dart';

class EditAreaPage extends ConsumerStatefulWidget {
  final HuntArea area;

  const EditAreaPage({Key? key, required this.area}) : super(key: key);

  @override
  ConsumerState<EditAreaPage> createState() => _EditAreaPageState();
}

class _EditAreaPageState extends ConsumerState<EditAreaPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _alarmTextCtrl;
  late final TextEditingController _alarmMarginCtrl;
  final _mapController = MapController();

  bool _isLoading = false;
  bool _drawingBoundary = false;
  late List<LatLng> _boundaryPoints;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.area.name);
    _descCtrl = TextEditingController(text: widget.area.description ?? '');
    _alarmTextCtrl = TextEditingController(text: widget.area.alarmText);
    _alarmMarginCtrl =
        TextEditingController(text: widget.area.alarmMarginMeters.round().toString());

    final bounds = ref.read(areaBoundariesProvider).value ?? {};
    _boundaryPoints = List<LatLng>.from(bounds[widget.area.id] ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _alarmTextCtrl.dispose();
    _alarmMarginCtrl.dispose();
    super.dispose();
  }

  LatLng _getCentroid() {
    if (_boundaryPoints.isEmpty) return widget.area.center;
    double lat = 0, lng = 0;
    for (final p in _boundaryPoints) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / _boundaryPoints.length, lng / _boundaryPoints.length);
  }

  Future<void> _save() async {
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
      final centroid = _getCentroid();
      await ref.read(huntAreasProvider.notifier).updateArea(widget.area.id, {
        'name': _nameCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'alarm_text': _alarmTextCtrl.text.trim(),
        'alarm_margin_meters': double.tryParse(_alarmMarginCtrl.text) ?? 100,
        'center_lat': centroid.latitude,
        'center_lng': centroid.longitude,
      });

      await ref
          .read(areaBoundariesProvider.notifier)
          .saveBoundary(widget.area.id, _boundaryPoints);

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

  LatLng _getInitialCenter() {
    if (_boundaryPoints.isNotEmpty) return _getCentroid();
    final pos = ref.read(currentPositionProvider).value;
    if (pos != null) return LatLng(pos.latitude, pos.longitude);
    return widget.area.center;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rediger jagtområde'),
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
                    initialZoom: 14,
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
                          setState(() => _drawingBoundary = !_drawingBoundary);
                        },
                        child:
                            Icon(_drawingBoundary ? Icons.stop : Icons.draw),
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
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _alarmMarginCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alarm margin (meter)',
                    border: OutlineInputBorder(),
                    suffixText: 'm',
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
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Gem ændringer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
