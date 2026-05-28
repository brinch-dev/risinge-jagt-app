import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/event_signup_provider.dart';
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/models/event_signup.dart';
import 'package:jagt_app/features/admin/presentation/pages/create_event_page.dart';
import 'package:jagt_app/features/calendar/presentation/pages/event_detail_page.dart';
import 'package:jagt_app/features/notifications/presentation/widgets/notification_bell.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final profile = ref.watch(userProfileProvider).value;
    final signupsAsync = ref.watch(eventSignupsProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final profileLoaded = profile != null;
    final canSeeAll = profile?.canSeeAllEvents ?? true;
    final myEventIds = !canSeeAll && profileLoaded && currentUserId != null
        ? (signupsAsync.value ?? [])
            .where((s) => s.userId == currentUserId && s.isAttending)
            .map((s) => s.eventId)
            .toSet()
        : <String>{};

    List<HuntEvent> filterEvents(List<HuntEvent> events) {
      if (canSeeAll || !profileLoaded) return events;
      return events.where((e) => myEventIds.contains(e.id)).toList();
    }

    final selectedEvents = _selectedDay != null
        ? filterEvents(ref.watch(eventsForDateProvider(_selectedDay!)))
        : <HuntEvent>[];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 36),
            const SizedBox(width: 10),
            const Text('Kalender'),
          ],
        ),
        actions: const [NotificationBell()],
      ),
      body: Column(
        children: [
          eventsAsync.when(
            loading: () => const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 300,
              child: Center(child: Text('Fejl: $e')),
            ),
            data: (events) {
              return TableCalendar<HuntEvent>(
                locale: 'da_DK',
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) =>
                    setState(() => _calendarFormat = format),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                eventLoader: (day) {
                  return filterEvents(events
                      .where((e) =>
                          e.date.year == day.year &&
                          e.date.month == day.month &&
                          e.date.day == day.day)
                      .toList());
                },
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                ),
              );
            },
          ),
          const Divider(),
          Expanded(
            child: selectedEvents.isEmpty
                ? const Center(
                    child: Text('Ingen events denne dag'),
                  )
                : ListView.builder(
                    itemCount: selectedEvents.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final event = selectedEvents[index];
                      final isPast = DateTime.now().isAfter(
                        DateTime(event.date.year, event.date.month, event.date.day, 0, 1),
                      );
                      return _EventCard(
                        event: event,
                        profile: profile,
                        onDelete: !isPast &&
                                profile != null &&
                                (profile.canEditAllEvents ||
                                    (profile.canEditOwnEvents &&
                                        event.createdBy == currentUserId))
                            ? () => _confirmDelete(event)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: profile != null && profile.canCreateEvents
          ? FloatingActionButton(
              heroTag: 'calendar_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEventPage(
                      selectedDate: _selectedDay,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _confirmDelete(HuntEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet event'),
        content: Text('Er du sikker på at du vil slette "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(eventsProvider.notifier).deleteEvent(event.id);
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

class _EventCard extends ConsumerWidget {
  final HuntEvent event;
  final dynamic profile;
  final VoidCallback? onDelete;

  const _EventCard({
    required this.event,
    required this.profile,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final signupsAsync = ref.watch(eventSignupsProvider);
    final signups = signupsAsync.value ?? [];
    final eventSignups = signups.where((s) => s.eventId == event.id).toList();
    final attending = eventSignups.where((s) => s.isAttending).toList();
    final declined = eventSignups.where((s) => s.isNotAttending).toList();

    final myStatus = currentUserId != null
        ? ref.read(eventSignupsProvider.notifier).getStatus(event.id, currentUserId)
        : null;

    final cs = Theme.of(context).colorScheme;
    Color statusColor = cs.outline;
    String statusText = 'Ikke reageret';
    IconData statusIcon = Icons.help_outline;
    if (myStatus == SignupStatus.attending) {
      statusColor = cs.primary;
      statusText = 'Tilmeldt';
      statusIcon = Icons.check_circle;
    } else if (myStatus == SignupStatus.notAttending) {
      statusColor = cs.error;
      statusText = 'Kommer ikke';
      statusIcon = Icons.cancel;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailPage(event: event),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(event.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: onDelete,
                    ),
                ],
              ),
              if (event.description != null) ...[
                const SizedBox(height: 4),
                Text(event.description!,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (event.startTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${event.startTime}${event.endTime != null ? ' - ${event.endTime}' : ''}',
                  style: TextStyle(color: cs.outline),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text(
                    '${attending.length} tilmeldt',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  if (declined.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${declined.length} afbud',
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tryk for detaljer, tilmelding og noter',
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
