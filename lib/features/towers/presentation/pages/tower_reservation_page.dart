import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/models/tower.dart';
import 'package:jagt_app/models/tower_reservation.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/providers/area_boundary_provider.dart';
import 'package:jagt_app/providers/event_signup_provider.dart';

class TowerReservationPage extends ConsumerStatefulWidget {
  final HuntEvent event;
  const TowerReservationPage({Key? key, required this.event}) : super(key: key);

  @override
  ConsumerState<TowerReservationPage> createState() =>
      _TowerReservationPageState();
}

class _TowerReservationPageState extends ConsumerState<TowerReservationPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final towersAsync = ref.watch(towersProvider);
    final areasAsync = ref.watch(huntAreasProvider);
    final reservationsAsync = ref.watch(towerReservationsProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAdmin = profile?.isAdmin ?? false;

    final eventArea = areasAsync.value
        ?.where((a) => a.id == widget.event.areaId)
        .toList();
    final area = eventArea != null && eventArea.isNotEmpty
        ? eventArea.first
        : null;

    final eventTowers = towersAsync.value
            ?.where((t) => t.areaId == widget.event.areaId)
            .toList() ??
        [];

    final reservations = reservationsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Poster - ${widget.event.title}'),
      ),
      body: Column(
        children: [
          if (area != null)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: area.center,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dk.jagtapp',
                  ),
                  Builder(builder: (context) {
                    final areaBounds = ref.watch(areaBoundariesProvider).value ?? {};
                    final polygon = areaBounds[area.id];
                    if (polygon != null && polygon.length >= 3) {
                      return PolygonLayer(
                        polygons: [
                          Polygon(
                            points: polygon,
                            color: Colors.green.withValues(alpha: 0.15),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  MarkerLayer(
                    markers: eventTowers.map((tower) {
                      final reservation = _findReservation(
                          reservations, tower.id, widget.event.id);
                      final isReserved = reservation != null;
                      final isMyReservation =
                          reservation?.userId == currentUserId;

                      return Marker(
                        point: LatLng(tower.lat, tower.lng),
                        width: 44,
                        height: 44,
                        child: _TowerMapIcon(
                          isReserved: isReserved,
                          isMine: isMyReservation,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _legend(Colors.green, 'Ledig'),
                const SizedBox(width: 16),
                _legend(Colors.red, 'Optaget'),
                const SizedBox(width: 16),
                _legend(Colors.blue, 'Din'),
              ],
            ),
          ),
          Expanded(
            child: eventTowers.isEmpty
                ? const Center(child: Text('Ingen poster i dette område'))
                : ListView.builder(
                    itemCount: eventTowers.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final tower = eventTowers[index];
                      final reservation = _findReservation(
                          reservations, tower.id, widget.event.id);
                      final isReserved = reservation != null;
                      final isMyReservation =
                          reservation?.userId == currentUserId;

                      final statusColor = isMyReservation
                          ? Colors.blue
                          : isReserved
                              ? Colors.red
                              : Colors.green;
                      final statusText = reservation == null
                          ? 'Ledig'
                          : isMyReservation
                              ? 'Din reservation'
                              : isAdmin
                                  ? 'Optaget: ${reservation.userName ?? 'ukendt'}'
                                  : 'Optaget';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.circle,
                                      color: statusColor, size: 12),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(tower.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                  ),
                                  Text(statusText,
                                      style: TextStyle(
                                          fontSize: 12, color: statusColor)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: _buildActionButton(
                                  tower, reservation, isMyReservation, isAdmin),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton(
    Tower tower,
    TowerReservation? reservation,
    bool isMyReservation,
    bool isAdmin,
  ) {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (reservation == null) {
      final profile = ref.read(userProfileProvider).value;
      final canReserve = profile?.canReserveTowers ?? false;
      if (!canReserve) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('Ledig', style: TextStyle(fontSize: 12, color: Colors.green)),
        );
      }
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final isSignedUp = currentUserId != null &&
          ref.read(eventSignupsProvider.notifier).isSignedUp(
              widget.event.id, currentUserId);
      if (!isSignedUp) {
        return SizedBox(
          height: 32,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 13),
            ),
            onPressed: null,
            child: const Text('Tilmeld event først'),
          ),
        );
      }
      return SizedBox(
        height: 32,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 13),
          ),
          onPressed: () => _reserve(tower.id),
          child: const Text('Reserver'),
        ),
      );
    }

    if (isMyReservation || isAdmin) {
      return SizedBox(
        height: 32,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 13),
          ),
          onPressed: () => _cancel(tower.id),
          child: const Text('Annuller'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCDD2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Optaget', style: TextStyle(fontSize: 12, color: Colors.red)),
    );
  }

  TowerReservation? _findReservation(
      List<TowerReservation> reservations, String towerId, String eventId) {
    try {
      return reservations
          .firstWhere((r) => r.towerId == towerId && r.eventId == eventId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _reserve(String towerId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(towerReservationsProvider.notifier)
          .reserve(towerId, widget.event.id);
      final profile = ref.read(userProfileProvider).value;
      final towers = ref.read(towersProvider).value ?? [];
      final towerName =
          towers.where((t) => t.id == towerId).firstOrNull?.name ?? towerId;
      await writeAdminLog(ref,
          type: 'reservation',
          message:
              '${profile?.displayName ?? 'Ukendt'} reserverede $towerName til ${widget.event.title}',
          userId: Supabase.instance.client.auth.currentUser?.id,
          userName: profile?.displayName,
          referenceId: towerId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel(String towerId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(towerReservationsProvider.notifier)
          .cancelReservation(towerId, widget.event.id);
      final profile = ref.read(userProfileProvider).value;
      final towers = ref.read(towersProvider).value ?? [];
      final towerName =
          towers.where((t) => t.id == towerId).firstOrNull?.name ?? towerId;
      await writeAdminLog(ref,
          type: 'reservation_cancel',
          message:
              '${profile?.displayName ?? 'Ukendt'} annullerede reservation af $towerName til ${widget.event.title}',
          userId: Supabase.instance.client.auth.currentUser?.id,
          userName: profile?.displayName,
          referenceId: towerId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _TowerMapIcon extends StatelessWidget {
  final bool isReserved;
  final bool isMine;

  const _TowerMapIcon({required this.isReserved, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final color = isMine
        ? Colors.blue
        : isReserved
            ? Colors.red
            : Colors.green;

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.visibility, color: color, size: 32),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
