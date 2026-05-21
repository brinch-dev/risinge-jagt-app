import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/models/hunt_area.dart';
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/models/tower.dart';
import 'package:jagt_app/models/tower_reservation.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/providers/area_boundary_provider.dart';
import 'package:jagt_app/features/towers/presentation/pages/tower_reservation_page.dart';

class AreaDetailSheet extends ConsumerWidget {
  final HuntArea area;
  final UserProfile? profile;

  const AreaDetailSheet({
    Key? key,
    required this.area,
    required this.profile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMemberOrAdmin = profile != null && !profile!.isGuest;
    final towers =
        (ref.watch(towersProvider).value ?? []).where((t) => t.areaId == area.id).toList();
    final events =
        (ref.watch(eventsProvider).value ?? []).where((e) => e.areaId == area.id).toList();
    final reservations = ref.watch(towerReservationsProvider).value ?? [];
    final now = DateTime.now();
    final upcomingEvents = events
        .where((e) => e.date.isAfter(now.subtract(const Duration(days: 1))))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.map, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    area.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (area.description != null) ...[
              Text(area.description!, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
            ],
            _infoRow(Icons.pentagon, 'Polygon',
                '${(ref.watch(areaBoundariesProvider).value ?? {})[area.id]?.length ?? 0} punkter'),
            _infoRow(Icons.warning_amber, 'Alarm margin',
                '${area.alarmMarginMeters.round()} meter'),

            const SizedBox(height: 8),
            _infoRow(Icons.visibility, 'Poster', '${towers.length} poster i området'),

            if (isMemberOrAdmin) ...[
              const Divider(height: 24),
              Text('Poster / Tårne',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (towers.isEmpty)
                const Text('Ingen poster oprettet i dette område',
                    style: TextStyle(color: Colors.grey))
              else
                ...towers.map((tower) => _buildTowerTile(
                    context, tower, reservations, upcomingEvents, profile!)),

              const Divider(height: 24),
              Text('Kommende Events',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (upcomingEvents.isEmpty)
                const Text('Ingen kommende events',
                    style: TextStyle(color: Colors.grey))
              else
                ...upcomingEvents
                    .map((event) => _buildEventTile(context, event)),
            ] else ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Log ind som medlem for at se events, poster og reservationer',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildTowerTile(BuildContext context, Tower tower,
      List<TowerReservation> reservations, List<HuntEvent> events,
      UserProfile profile) {
    final nextEvent = events.isNotEmpty ? events.first : null;
    TowerReservation? reservation;
    if (nextEvent != null) {
      final matches = reservations
          .where((r) => r.towerId == tower.id && r.eventId == nextEvent.id)
          .toList();
      if (matches.isNotEmpty) reservation = matches.first;
    }

    final isReserved = reservation != null;
    final color = isReserved ? Colors.red : Colors.green;

    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(Icons.visibility, color: color),
        title: Text(tower.name),
        subtitle: Text(isReserved
            ? (profile.isAdmin
                ? 'Optaget af ${reservation.userName ?? 'ukendt'}'
                : 'Optaget')
            : 'Ledig'),
        trailing: isReserved
            ? Icon(Icons.circle, color: color, size: 12)
            : Icon(Icons.circle, color: color, size: 12),
      ),
    );
  }

  Widget _buildEventTile(BuildContext context, HuntEvent event) {
    final dateStr =
        '${event.date.day}/${event.date.month}/${event.date.year}';
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.event, color: Colors.green),
        title: Text(event.title),
        subtitle: Text(
            '$dateStr${event.startTime != null ? ' kl. ${event.startTime}' : ''}'
            '${event.endTime != null ? ' - ${event.endTime}' : ''}'),
        trailing: event.areaId != null
            ? IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'Se poster',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TowerReservationPage(event: event),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}
