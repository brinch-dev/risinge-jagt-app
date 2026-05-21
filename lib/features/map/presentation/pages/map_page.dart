import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/models/hunt_area.dart';
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/models/tower.dart';
import 'package:jagt_app/models/tower_reservation.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/providers/location_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/providers/event_signup_provider.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/providers/live_location_provider.dart';
import 'package:jagt_app/services/notification_service.dart';
import 'package:jagt_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:jagt_app/features/map/presentation/widgets/area_detail_sheet.dart';
import 'package:jagt_app/services/foreground_service.dart';
import 'package:jagt_app/providers/event_boundary_provider.dart';
import 'package:jagt_app/providers/area_boundary_provider.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();
  bool _locationReady = false;
  String? _boundaryWarning;
  Timer? _warningTimer;
  bool _showCheckin = false;
  String? _checkinEventId;
  String? _checkinEventTitle;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;
  final Map<String, DateTime> _lastLogTime = {};
  bool _trackingStarted = false;
  bool _insideArea = false;
  int _tileLayerIndex = 0;
  bool _measureMode = false;
  LatLng? _measurePointB;
  bool _hasFittedToArea = false;

  static const _tileLayers = [
    {'name': 'Standard', 'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'},
    {'name': 'Satellit', 'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'},
    {'name': 'Topografisk', 'url': 'https://tile.opentopomap.org/{z}/{x}/{y}.png'},
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final posNotifier = ref.read(currentPositionProvider.notifier);
    final ready = await posNotifier.initialize();
    if (!mounted) return;
    setState(() => _locationReady = ready);

    if (ready) {
      posNotifier.startTracking();
      _startAreaCheck();
    }
    _checkExistingCheckin();
  }

  Future<void> _checkExistingCheckin() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    final events = ref.read(eventsProvider).value ?? [];
    final signups = ref.read(eventSignupsProvider).value ?? [];
    final myAttendingIds = signups
        .where((s) => s.userId == userId && s.isAttending)
        .map((s) => s.eventId)
        .toSet();

    final todayEvents = events.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day &&
        myAttendingIds.contains(e.id)).toList();

    for (final event in todayEvents) {
      final data = await client
          .from('event_checkins')
          .select()
          .eq('event_id', event.id)
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null) {
        final checkedOutAt = data['checked_out_at'];
        if (mounted) {
          setState(() {
            _checkinEventId = event.id;
            _checkinEventTitle = event.title;
            if (checkedOutAt != null) {
              _hasCheckedIn = true;
              _hasCheckedOut = true;
            } else {
              _hasCheckedIn = true;
              _hasCheckedOut = false;
            }
          });
        }
        return;
      }
    }
  }

  void _startAreaCheck() {
    _warningTimer?.cancel();
    _warningTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkIfInsideArea();
      _checkBoundaries();
      _checkProximityForCheckin();
    });
    _checkIfInsideArea();
  }

  void _checkIfInsideArea() {
    final position = ref.read(currentPositionProvider).value;
    if (position == null) return;

    final areaBoundaries = ref.read(areaBoundariesProvider).value ?? {};
    final locationService = ref.read(locationServiceProvider);

    bool inside = false;
    for (final entry in areaBoundaries.entries) {
      if (entry.value.length >= 3 &&
          locationService.isInsidePolygon(position, entry.value)) {
        inside = true;
        break;
      }
    }

    if (inside && !_trackingStarted) {
      _trackingStarted = true;
      ForegroundService.start();
      ref.read(liveLocationProvider).startTracking();
    } else if (!inside && _trackingStarted) {
      _trackingStarted = false;
      ref.read(liveLocationProvider).stopTracking();
      ForegroundService.stop();
    }

    if (inside != _insideArea) {
      setState(() => _insideArea = inside);
    }
  }

  void _checkBoundaries() {
    final position = ref.read(currentPositionProvider).value;
    if (position == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final now = DateTime.now();
    final events = ref.read(eventsProvider).value ?? [];
    final signups = ref.read(eventSignupsProvider).value ?? [];
    final myAttendingEventIds = signups
        .where((s) => s.userId == currentUserId && s.isAttending)
        .map((s) => s.eventId)
        .toSet();

    final areaBoundaries = ref.read(areaBoundariesProvider).value ?? {};
    final eventBoundaries = ref.read(eventBoundariesProvider).value ?? {};
    final allAreas = ref.read(huntAreasProvider).value ?? [];
    final locationService = ref.read(locationServiceProvider);
    final profile = ref.read(userProfileProvider).value;

    final todayEvents = events.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);

    final myTodayEvents = todayEvents
        .where((e) => myAttendingEventIds.contains(e.id))
        .toList();

    if (myTodayEvents.isNotEmpty) {
      for (final event in myTodayEvents) {
        final polygon = eventBoundaries[event.id];
        if (polygon == null || polygon.length < 3) continue;

        final area = event.areaId != null
            ? allAreas.where((a) => a.id == event.areaId).firstOrNull
            : null;
        final alarmText = area?.alarmText;
        final alarmMargin = area?.alarmMarginMeters ?? 100;
        final label = event.title;

        if (!locationService.isInsidePolygon(position, polygon)) {
          NotificationService().showOutsideBoundary(customText: alarmText);
          setState(() => _boundaryWarning = alarmText ?? 'Uden for $label!');
          _throttledLog(event.id, 'geofence_outside',
              '${profile?.displayName ?? 'Ukendt'} er uden for $label',
              currentUserId, profile?.displayName);
          return;
        }

        if (locationService.isNearPolygonBoundary(position, polygon,
            thresholdMeters: alarmMargin)) {
          final dist =
              locationService.distanceToPolygonBoundary(position, polygon);
          NotificationService()
              .showBoundaryWarning(dist, customText: alarmText);
          setState(() => _boundaryWarning =
              '${dist.round()}m til grænsen af $label');
          _throttledLog(
              event.id,
              'geofence_warning',
              '${profile?.displayName ?? 'Ukendt'} er ${dist.round()}m fra grænsen af $label',
              currentUserId,
              profile?.displayName);
          return;
        }
      }
    } else {
      for (final entry in areaBoundaries.entries) {
        final polygon = entry.value;
        if (polygon.length < 3) continue;
        final area = allAreas.where((a) => a.id == entry.key).firstOrNull;
        if (area == null) continue;

        if (!locationService.isInsidePolygon(position, polygon)) {
          if (_insideArea) {
            NotificationService().showOutsideBoundary(customText: area.alarmText);
            setState(() => _boundaryWarning = area.alarmText);
            _throttledLog(area.id, 'geofence_outside',
                '${profile?.displayName ?? 'Ukendt'} er uden for ${area.name}',
                currentUserId, profile?.displayName);
            return;
          }
          continue;
        }

        if (locationService.isNearPolygonBoundary(position, polygon,
            thresholdMeters: area.alarmMarginMeters)) {
          final dist =
              locationService.distanceToPolygonBoundary(position, polygon);
          NotificationService()
              .showBoundaryWarning(dist, customText: area.alarmText);
          setState(() => _boundaryWarning =
              '${dist.round()}m til grænsen af ${area.name}');
          _throttledLog(
              area.id,
              'geofence_warning',
              '${profile?.displayName ?? 'Ukendt'} er ${dist.round()}m fra grænsen af ${area.name}',
              currentUserId,
              profile?.displayName);
          return;
        }
      }
    }
    setState(() => _boundaryWarning = null);
  }

  void _throttledLog(String areaId, String type, String message,
      String? userId, String? userName) {
    final key = '$type:$areaId';
    final last = _lastLogTime[key];
    if (last != null && DateTime.now().difference(last).inSeconds < 60) return;
    _lastLogTime[key] = DateTime.now();
    writeAdminLog(ref,
        type: type,
        message: message,
        userId: userId,
        userName: userName,
        referenceId: areaId);
  }

  void _checkProximityForCheckin() {
    if (_hasCheckedIn) return;

    final position = ref.read(currentPositionProvider).value;
    if (position == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final now = DateTime.now();
    final events = ref.read(eventsProvider).value ?? [];
    final signups = ref.read(eventSignupsProvider).value ?? [];
    final areaBoundaries = ref.read(areaBoundariesProvider).value ?? {};
    final locationService = ref.read(locationServiceProvider);
    final myEventIds = signups
        .where((s) => s.userId == currentUserId && s.isAttending)
        .map((s) => s.eventId)
        .toSet();

    for (final event in events) {
      if (!event.checkinEnabled) continue;
      if (!myEventIds.contains(event.id)) continue;
      if (event.areaId == null) continue;
      if (event.date.year != now.year ||
          event.date.month != now.month ||
          event.date.day != now.day) continue;

      if (event.startTime != null && event.endTime != null) {
        final startParts = event.startTime!.split(':');
        final endParts = event.endTime!.split(':');
        final eventStart = DateTime(now.year, now.month, now.day,
            int.parse(startParts[0]), int.parse(startParts[1]));
        final eventEnd = DateTime(now.year, now.month, now.day,
            int.parse(endParts[0]), int.parse(endParts[1]));
        final windowStart = eventStart.subtract(const Duration(hours: 1));
        final windowEnd = eventEnd.add(const Duration(hours: 1));
        if (now.isBefore(windowStart) || now.isAfter(windowEnd)) continue;
      }

      final polygon = areaBoundaries[event.areaId];
      if (polygon != null && polygon.length >= 3) {
        if (locationService.isInsidePolygon(position, polygon)) {
          setState(() {
            _showCheckin = true;
            _checkinEventId = event.id;
            _checkinEventTitle = event.title;
          });
          return;
        }
      }
    }
    setState(() => _showCheckin = false);
  }

  Future<void> _doCheckin() async {
    final position = ref.read(currentPositionProvider).value;
    if (position == null || _checkinEventId == null) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await client.from('event_checkins').upsert({
        'event_id': _checkinEventId,
        'user_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      final profile = ref.read(userProfileProvider).value;
      await writeAdminLog(ref,
          type: 'checkin',
          message:
              '${profile?.displayName ?? 'Ukendt'} checkede ind til $_checkinEventTitle',
          userId: userId,
          userName: profile?.displayName,
          referenceId: _checkinEventId);

      if (mounted) {
        setState(() {
          _hasCheckedIn = true;
          _showCheckin = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked ind til $_checkinEventTitle!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl ved checkin: $e')),
        );
      }
    }
  }

  Future<void> _doCheckout() async {
    if (_checkinEventId == null) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await client
          .from('event_checkins')
          .update({'checked_out_at': DateTime.now().toIso8601String()})
          .eq('event_id', _checkinEventId!)
          .eq('user_id', userId);

      final profile = ref.read(userProfileProvider).value;
      await writeAdminLog(ref,
          type: 'checkout',
          message:
              '${profile?.displayName ?? 'Ukendt'} checkede ud fra $_checkinEventTitle',
          userId: userId,
          userName: profile?.displayName,
          referenceId: _checkinEventId);

      if (mounted) {
        setState(() => _hasCheckedOut = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked ud fra $_checkinEventTitle!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl ved checkout: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    if (_trackingStarted) {
      ref.read(liveLocationProvider).stopTracking();
      ForegroundService.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(huntAreasProvider);
    final towersAsync = ref.watch(towersProvider);
    final reservationsAsync = ref.watch(towerReservationsProvider);
    final positionAsync = ref.watch(currentPositionProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final upcoming = ref.watch(upcomingEventsProvider);
    final nextEvent = upcoming.isNotEmpty ? upcoming.first : null;
    final reservations = reservationsAsync.value ?? [];
    final activeEventId = _getActiveEventId(nextEvent);
    final boundariesAsync = ref.watch(eventBoundariesProvider);
    final areaBoundsAsync = ref.watch(areaBoundariesProvider);

    if (!_hasFittedToArea && areaBoundsAsync.hasValue) {
      final allPoints = areaBoundsAsync.value!.values.expand((p) => p).toList();
      if (allPoints.isNotEmpty) {
        _hasFittedToArea = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final bounds = LatLngBounds.fromPoints(allPoints);
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
          );
        });
      }
    }

    final showLiveUsers = profile != null &&
        (profile.canSeeLivePositions || _insideArea);
    final liveLocations = showLiveUsers
        ? ref.watch(allUserLocationsProvider).value ?? []
        : <UserLocation>[];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 36),
            const SizedBox(width: 10),
            const Text('Jagtkort'),
          ],
        ),
        actions: const [
          NotificationBell(),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(55.3835, 10.6100),
              initialZoom: 14,
              onTap: _measureMode
                  ? (_, latLng) => setState(() => _measurePointB = latLng)
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: _tileLayers[_tileLayerIndex]['url']!,
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
              if (boundariesAsync.hasValue)
                PolygonLayer(
                  polygons: boundariesAsync.value!.entries
                      .where((e) {
                        final ev = upcoming
                            .where((ev) => ev.id == e.key)
                            .firstOrNull;
                        return ev != null;
                      })
                      .map((e) => Polygon(
                            points: e.value,
                            color: Colors.red.withValues(alpha: 0.15),
                            borderColor: Colors.red.shade700,
                            borderStrokeWidth: 2,
                          ))
                      .toList(),
                ),
              if (towersAsync.hasValue && (profile?.canSeeTowers ?? false))
                MarkerLayer(
                  markers: towersAsync.value!.map((tower) {
                    final color = _getTowerColor(
                        tower, reservations, activeEventId, currentUserId);
                    return Marker(
                      point: LatLng(tower.lat, tower.lng),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showTowerInfo(
                            tower, reservations, activeEventId,
                            isAdmin: profile?.isAdmin ?? false,
                            currentUserId: currentUserId),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(32, 32),
                              painter: _getTowerPainter(tower.towerType, color),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (areasAsync.hasValue && areaBoundsAsync.hasValue)
                MarkerLayer(
                  markers: areasAsync.value!
                      .where((area) {
                        final bounds = areaBoundsAsync.value![area.id];
                        return bounds != null && bounds.length >= 3;
                      })
                      .map((area) {
                        final bounds = areaBoundsAsync.value![area.id]!;
                        final center = _polygonCenter(bounds);
                        return Marker(
                          point: center,
                          width: 120,
                          height: 34,
                          child: GestureDetector(
                            onTap: () => _showAreaDetail(area),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      area.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              if (liveLocations.isNotEmpty)
                MarkerLayer(
                  markers: liveLocations
                      .where((loc) => loc.userId != currentUserId)
                      .map((loc) {
                    final isRecent = DateTime.now().difference(loc.updatedAt).inMinutes < 5;
                    return Marker(
                      point: LatLng(loc.latitude, loc.longitude),
                      width: 80,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isRecent ? Colors.orange.shade700 : Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              loc.displayName ?? 'Ukendt',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isRecent ? Colors.orange : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              if (positionAsync.hasValue && positionAsync.value != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(positionAsync.value!.latitude,
                          positionAsync.value!.longitude),
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              if (_measureMode &&
                  _measurePointB != null &&
                  positionAsync.hasValue &&
                  positionAsync.value != null) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(positionAsync.value!.latitude,
                            positionAsync.value!.longitude),
                        _measurePointB!,
                      ],
                      color: Colors.deepOrange,
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _measurePointB!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Marker(
                      point: LatLng(
                        (positionAsync.value!.latitude +
                                _measurePointB!.latitude) /
                            2,
                        (positionAsync.value!.longitude +
                                _measurePointB!.longitude) /
                            2,
                      ),
                      width: 100,
                      height: 30,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          _formatDistance(
                            const Distance().as(
                              LengthUnit.Meter,
                              LatLng(positionAsync.value!.latitude,
                                  positionAsync.value!.longitude),
                              _measurePointB!,
                            ),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (_insideArea)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.green.shade700,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'GPS aktiv — du er i jagtområdet',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_boundaryWarning != null)
            Positioned(
              top: _insideArea ? 40 : 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade700,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _boundaryWarning!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showCheckin)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Card(
                elevation: 8,
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Du er ved $_checkinEventTitle',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _doCheckin,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Check ind'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_hasCheckedIn && !_hasCheckedOut)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Card(
                elevation: 8,
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Checked ind til $_checkinEventTitle',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _doCheckout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Check ud'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_hasCheckedOut)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Card(
                elevation: 4,
                color: Colors.orange.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Du er checked ud',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.add,
                  heroTag: 'zoomIn',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom + 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 6),
                _MapButton(
                  icon: Icons.remove,
                  heroTag: 'zoomOut',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom - 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 6),
                _MapButton(
                  icon: Icons.layers,
                  heroTag: 'layers',
                  onPressed: () {
                    setState(() {
                      _tileLayerIndex = (_tileLayerIndex + 1) % _tileLayers.length;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_tileLayers[_tileLayerIndex]['name']!),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                _MapButton(
                  icon: _measureMode ? Icons.close : Icons.straighten,
                  heroTag: 'measure',
                  onPressed: () {
                    setState(() {
                      _measureMode = !_measureMode;
                      if (!_measureMode) _measurePointB = null;
                    });
                    if (_measureMode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tryk på kortet for at måle afstand'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                if (_locationReady) ...[
                  const SizedBox(height: 6),
                  _MapButton(
                    icon: Icons.my_location,
                    heroTag: 'center',
                    onPressed: () {
                      final pos = ref.read(currentPositionProvider).value;
                      if (pos != null) {
                        _mapController.move(
                            LatLng(pos.latitude, pos.longitude), 15);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getActiveEventId(HuntEvent? event) {
    if (event == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
    if (eventDay != today) return null;
    if (event.startTime != null && event.endTime != null) {
      final startParts = event.startTime!.split(':');
      final endParts = event.endTime!.split(':');
      final start = DateTime(now.year, now.month, now.day,
          int.parse(startParts[0]), int.parse(startParts[1]));
      final end = DateTime(now.year, now.month, now.day,
          int.parse(endParts[0]), int.parse(endParts[1]));
      if (now.isBefore(start) || now.isAfter(end)) return null;
    }
    return event.id;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  LatLng _polygonCenter(List<LatLng> points) {
    double lat = 0, lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  void _showAreaDetail(HuntArea area) {
    final profile = ref.read(userProfileProvider).value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AreaDetailSheet(area: area, profile: profile),
    );
  }

  Color _getTowerColor(Tower tower, List<TowerReservation> reservations,
      String? eventId, String? currentUserId) {
    if (eventId == null) return Colors.brown;
    final reservation = reservations
        .where((r) => r.towerId == tower.id && r.eventId == eventId)
        .toList();
    if (reservation.isEmpty) return Colors.green;
    if (reservation.first.userId == currentUserId) return Colors.blue;
    return Colors.red;
  }

  void _showTowerInfo(Tower tower, List<TowerReservation> reservations,
      String? eventId,
      {required bool isAdmin, String? currentUserId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      tower.towerType == TowerType.jagttaarn
                          ? Icons.cabin
                          : tower.towerType == TowerType.skydestige
                              ? Icons.stairs
                              : Icons.crisis_alert,
                      color: Colors.brown,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tower.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            tower.towerType.label,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tower.description != null &&
                    tower.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    tower.description!,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
                if (tower.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tower.imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          tower.imageUrls[i],
                          height: 200,
                          width: 280,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            width: 280,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${tower.lat.toStringAsFixed(5)}, ${tower.lng.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

CustomPainter _getTowerPainter(TowerType type, Color color) {
  switch (type) {
    case TowerType.skydestige:
      return _SkydestigePainter(color: color);
    case TowerType.skudlinje:
      return _SkudlinjePainter(color: color);
    case TowerType.jagttaarn:
      return _JagttaarnPainter(color: color);
  }
}

class _JagttaarnPainter extends CustomPainter {
  final Color color;
  _JagttaarnPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Platform/cabin
    final cabin = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.05, w * 0.6, h * 0.35),
      const Radius.circular(2),
    );
    canvas.drawRRect(cabin, paint);

    // Roof
    final roof = ui.Path()
      ..moveTo(w * 0.15, h * 0.1)
      ..lineTo(w * 0.5, h * -0.05)
      ..lineTo(w * 0.85, h * 0.1)
      ..close();
    canvas.drawPath(roof, paint);

    // Legs
    canvas.drawLine(Offset(w * 0.25, h * 0.4), Offset(w * 0.1, h * 0.95), stroke);
    canvas.drawLine(Offset(w * 0.75, h * 0.4), Offset(w * 0.9, h * 0.95), stroke);

    // Cross brace
    canvas.drawLine(Offset(w * 0.18, h * 0.65), Offset(w * 0.82, h * 0.65), stroke..strokeWidth = 1.5);

    // Window
    final windowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.35, h * 0.12, w * 0.3, h * 0.18),
      windowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _JagttaarnPainter old) => old.color != color;
}

class _SkydestigePainter extends CustomPainter {
  final Color color;
  _SkydestigePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Two side rails (leaning slightly)
    canvas.drawLine(Offset(w * 0.3, h * 0.0), Offset(w * 0.25, h * 0.95), stroke);
    canvas.drawLine(Offset(w * 0.7, h * 0.0), Offset(w * 0.75, h * 0.95), stroke);

    // Rungs
    for (var i = 0; i < 5; i++) {
      final y = h * (0.1 + i * 0.18);
      final lx = w * 0.3 - (y / h) * w * 0.05;
      final rx = w * 0.7 + (y / h) * w * 0.05;
      canvas.drawLine(Offset(lx, y), Offset(rx, y), stroke..strokeWidth = 2.0);
    }

    // Small seat/platform at top
    canvas.drawRect(
      Rect.fromLTWH(w * 0.2, h * 0.0, w * 0.6, h * 0.08),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SkydestigePainter old) => old.color != color;
}

class _SkudlinjePainter extends CustomPainter {
  final Color color;
  _SkudlinjePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Crosshair circle
    canvas.drawCircle(Offset(cx, cy), w * 0.35, stroke);

    // Cross lines
    canvas.drawLine(Offset(cx, h * 0.05), Offset(cx, h * 0.3), stroke);
    canvas.drawLine(Offset(cx, h * 0.7), Offset(cx, h * 0.95), stroke);
    canvas.drawLine(Offset(w * 0.05, cy), Offset(w * 0.3, cy), stroke);
    canvas.drawLine(Offset(w * 0.7, cy), Offset(w * 0.95, cy), stroke);

    // Center dot
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 3, dot);
  }

  @override
  bool shouldRepaint(covariant _SkudlinjePainter old) => old.color != color;
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String heroTag;
  final VoidCallback onPressed;

  const _MapButton({
    required this.icon,
    required this.heroTag,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FloatingActionButton.small(
        heroTag: heroTag,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 3,
        onPressed: onPressed,
        child: Icon(icon, size: 20),
      ),
    );
  }
}
