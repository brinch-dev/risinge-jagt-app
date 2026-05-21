import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:jagt_app/models/hunt_area.dart';

final locationServiceProvider = Provider((ref) => LocationService());

final currentPositionProvider =
    AsyncNotifierProvider<PositionNotifier, Position?>(PositionNotifier.new);

class PositionNotifier extends AsyncNotifier<Position?> {
  StreamSubscription<Position>? _subscription;

  @override
  Future<Position?> build() async {
    ref.onDispose(() => _subscription?.cancel());
    return null;
  }

  Future<bool> initialize() async {
    final service = ref.read(locationServiceProvider);
    final hasPermission = await service.checkAndRequestPermission();
    if (!hasPermission) return false;

    final position = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    );
    state = AsyncData(position);
    return true;
  }

  void startTracking() {
    _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) => state = AsyncData(position),
      onError: (e) => state = AsyncError(e, StackTrace.current),
    );
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }
}

class LocationService {
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return true;
  }

  double distanceToAreaBoundary(Position position, HuntArea area) {
    final distanceToCenter = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      area.centerLat,
      area.centerLng,
    );
    return max(0, area.radiusMeters - distanceToCenter);
  }

  bool isInsideArea(Position position, HuntArea area) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      area.centerLat,
      area.centerLng,
    );
    return distance <= area.radiusMeters;
  }

  bool isNearBoundary(Position position, HuntArea area,
      {double thresholdMeters = 100}) {
    final distToBoundary = distanceToAreaBoundary(position, area);
    return distToBoundary <= thresholdMeters && distToBoundary >= 0;
  }

  bool isInsidePolygon(Position position, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    return _pointInPolygon(
        LatLng(position.latitude, position.longitude), polygon);
  }

  bool isNearPolygonBoundary(Position position, List<LatLng> polygon,
      {double thresholdMeters = 100}) {
    final dist = distanceToPolygonBoundary(position, polygon);
    return dist <= thresholdMeters;
  }

  double distanceToPolygonBoundary(Position position, List<LatLng> polygon) {
    if (polygon.length < 3) return double.infinity;
    double minDist = double.infinity;
    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final dist = _distanceToSegment(
        position.latitude, position.longitude,
        polygon[i].latitude, polygon[i].longitude,
        polygon[j].latitude, polygon[j].longitude,
      );
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  static bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude) &&
          point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  double _distanceToSegment(
      double px, double py, double ax, double ay, double bx, double by) {
    final distAB = Geolocator.distanceBetween(ax, ay, bx, by);
    if (distAB < 0.01) return Geolocator.distanceBetween(px, py, ax, ay);

    final distPA = Geolocator.distanceBetween(px, py, ax, ay);
    final distPB = Geolocator.distanceBetween(px, py, bx, by);

    if (distPA * distPA > distPB * distPB + distAB * distAB) {
      return distPB;
    }
    if (distPB * distPB > distPA * distPA + distAB * distAB) {
      return distPA;
    }

    final s = (distPA + distPB + distAB) / 2;
    final area = sqrt(s * (s - distPA) * (s - distPB) * (s - distAB));
    return 2 * area / distAB;
  }
}
