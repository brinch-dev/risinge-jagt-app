import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:jagt_app/providers/live_location_provider.dart';
import 'package:jagt_app/providers/area_boundary_provider.dart';

class LiveMapPage extends ConsumerWidget {
  const LiveMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(allUserLocationsProvider);
    final areaBoundsAsync = ref.watch(areaBoundariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live overvågning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allUserLocationsProvider),
          ),
        ],
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(55.3835, 10.6100),
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dk.jagtapp',
          ),
          if (areaBoundsAsync.hasValue)
            PolygonLayer(
              polygons: areaBoundsAsync.value!.entries
                  .where((e) => e.value.length >= 3)
                  .map((e) => Polygon(
                        points: e.value,
                        color: Colors.green.withValues(alpha: 0.15),
                        borderColor: Colors.green,
                        borderStrokeWidth: 2,
                      ))
                  .toList(),
            ),
          if (locationsAsync.hasValue)
            MarkerLayer(
              markers: locationsAsync.value!
                  .map((loc) => Marker(
                        point: LatLng(loc.latitude, loc.longitude),
                        width: 120,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _showUserInfo(context, loc),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isRecent(loc)
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade600,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  loc.displayName ?? 'Ukendt',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _isRecent(loc)
                                      ? Colors.blue
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isRecent(loc)
                                              ? Colors.blue
                                              : Colors.grey)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  bool _isRecent(UserLocation loc) {
    return DateTime.now().difference(loc.updatedAt).inMinutes < 5;
  }

  void _showUserInfo(BuildContext context, UserLocation loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.displayName ?? 'Ukendt bruger'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle,
                    size: 12,
                    color: _isRecent(loc) ? Colors.green : Colors.grey),
                const SizedBox(width: 6),
                Text(_isRecent(loc) ? 'Aktiv' : 'Inaktiv'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Sidst set: ${timeago.format(loc.updatedAt, locale: 'da')}'),
            const SizedBox(height: 4),
            Text(
              'Position: ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (loc.accuracy != null)
              Text(
                'Nøjagtighed: ${loc.accuracy!.round()}m',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
