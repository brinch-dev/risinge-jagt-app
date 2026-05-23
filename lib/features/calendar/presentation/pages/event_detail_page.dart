import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/models/event_signup.dart';
import 'package:jagt_app/providers/event_signup_provider.dart';
import 'package:jagt_app/providers/event_comment_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/providers/chat_provider.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/features/towers/presentation/pages/tower_reservation_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/edit_event_page.dart';
import 'package:jagt_app/providers/event_provider.dart';

final _eventWeatherFamily =
    FutureProvider.family<Map<String, dynamic>?, ({DateTime date, double lat, double lng})>(
        (ref, params) async {
  try {
    final dateStr = params.date.toIso8601String().split('T').first;
    final response = await http.get(Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${params.lat}&longitude=${params.lng}'
      '&daily=sunrise,sunset,temperature_2m_max,temperature_2m_min'
      '&timezone=Europe/Copenhagen'
      '&start_date=$dateStr&end_date=$dateStr',
    ));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

class EventDetailPage extends ConsumerStatefulWidget {
  final HuntEvent event;
  const EventDetailPage({Key? key, required this.event}) : super(key: key);

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final profile = ref.watch(userProfileProvider).value;
    final signupsAsync = ref.watch(eventSignupsProvider);
    final commentsAsync = ref.watch(eventCommentsProviderFamily(event.id));
    final allMembers = ref.watch(allMembersProvider);

    final signups = signupsAsync.value ?? [];
    final eventSignups = signups.where((s) => s.eventId == event.id).toList();
    final attending = eventSignups.where((s) => s.isAttending).toList();
    final declined = eventSignups.where((s) => s.isNotAttending).toList();
    final respondedIds = eventSignups.map((s) => s.userId).toSet();

    final myStatus = currentUserId != null
        ? ref.read(eventSignupsProvider.notifier).getStatus(event.id, currentUserId)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        actions: [
          if (profile != null &&
              (profile.canEditAllEvents ||
                  (profile.canEditOwnEvents && event.createdBy == currentUserId))) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditEventPage(event: event),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
          ],
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
                  Text(event.title,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 6),
                      Text(DateFormat('EEEE d. MMMM yyyy', 'da').format(event.date)),
                    ],
                  ),
                  if (event.startTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(width: 6),
                        Text('${event.startTime}${event.endTime != null ? ' - ${event.endTime}' : ''}'),
                      ],
                    ),
                  ],
                  if (event.description != null) ...[
                    const SizedBox(height: 12),
                    Text(event.description!),
                  ],
                  if (event.areaName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.map, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('Område: ${event.areaName}',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          _buildEventWeather(context, ref),
          const SizedBox(height: 16),
          if (profile != null && !profile.isGuest) ...[
            Text('Din status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: myStatus == SignupStatus.attending
                        ? null
                        : () => _setStatus('attending'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Tilmeldt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: myStatus == SignupStatus.attending
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: myStatus == SignupStatus.notAttending
                        ? null
                        : () => _setStatus('not_attending'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Kommer ikke'),
                    style: FilledButton.styleFrom(
                      backgroundColor: myStatus == SignupStatus.notAttending
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            if (event.areaId != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TowerReservationPage(event: event),
                  ),
                ),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Se poster'),
              ),
            ],
          ],

          const SizedBox(height: 24),
          Text('Tilmelding', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          if (attending.isNotEmpty) ...[
            _sectionHeader(Icons.check_circle, 'Tilmeldt (${attending.length})', Theme.of(context).colorScheme.primary),
            ...attending.map((s) => _memberTile(s.userName ?? 'Ukendt', Theme.of(context).colorScheme.primary, Icons.check_circle)),
          ],

          if (declined.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionHeader(Icons.cancel, 'Kommer ikke (${declined.length})', Theme.of(context).colorScheme.error),
            ...declined.map((s) => _memberTile(s.userName ?? 'Ukendt', Theme.of(context).colorScheme.error, Icons.cancel)),
          ],

          allMembers.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (members) {
              final notResponded = members
                  .where((m) => !respondedIds.contains(m['id'] as String))
                  .toList();
              if (notResponded.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _sectionHeader(Icons.help_outline, 'Ikke reageret (${notResponded.length})', Theme.of(context).colorScheme.outline),
                  ...notResponded.map((m) => _memberTile(
                      m['display_name'] as String? ?? m['email'] as String,
                      Theme.of(context).colorScheme.outline,
                      Icons.help_outline)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          Text('Noter', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          commentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Fejl: $e'),
            data: (comments) {
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Ingen noter endnu', style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(
                children: comments.map((c) {
                  final isOwn = c.userId == currentUserId;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        radius: 16,
                        child: Text(
                          (c.userName ?? '?')[0].toUpperCase(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 14),
                        ),
                      ),
                      title: Text(c.body),
                      subtitle: Text(
                        '${c.userName ?? 'Ukendt'} — ${timeago.format(c.createdAt, locale: 'da')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isOwn
                          ? IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => ref
                                  .read(eventCommentsProviderFamily(event.id).notifier)
                                  .deleteComment(c.id),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (profile != null && !profile.isGuest) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Skriv en note...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _addComment,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEventWeather(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(huntAreasProvider).value ?? [];
    final lat = areas.isNotEmpty ? areas.first.centerLat : 55.3835;
    final lng = areas.isNotEmpty ? areas.first.centerLng : 10.6100;
    final weatherAsync = ref.watch(
        _eventWeatherFamily((date: widget.event.date, lat: lat, lng: lng)));

    return weatherAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final daily = data['daily'] as Map<String, dynamic>;
        final sunrise =
            ((daily['sunrise'] as List).first as String).split('T').last;
        final sunset =
            ((daily['sunset'] as List).first as String).split('T').last;
        final tempMax =
            ((daily['temperature_2m_max'] as List).first as num).round();
        final tempMin =
            ((daily['temperature_2m_min'] as List).first as num).round();

        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _weatherCol(context, Icons.thermostat, '$tempMin° / $tempMax°', 'Temp'),
                  _weatherCol(context, Icons.wb_twilight, sunrise, 'Sol op'),
                  _weatherCol(context,
                      Icons.nightlight_round, sunset, 'Sol ned'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _weatherCol(BuildContext context, IconData icon, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: cs.outline),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.outline)),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _memberTile(String name, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(name),
        ],
      ),
    );
  }

  Future<void> _setStatus(String status) async {
    final profile = ref.read(userProfileProvider).value;
    try {
      if (status == 'attending') {
        await ref.read(eventSignupsProvider.notifier).signup(widget.event.id);
        await writeAdminLog(ref,
            type: 'event_signup',
            message: '${profile?.displayName ?? 'Ukendt'} tilmeldt ${widget.event.title}',
            userId: Supabase.instance.client.auth.currentUser?.id,
            userName: profile?.displayName,
            referenceId: widget.event.id);
      } else {
        await ref.read(eventSignupsProvider.notifier).decline(widget.event.id);
        await writeAdminLog(ref,
            type: 'event_unsignup',
            message: '${profile?.displayName ?? 'Ukendt'} kommer ikke til ${widget.event.title}',
            userId: Supabase.instance.client.auth.currentUser?.id,
            userName: profile?.displayName,
            referenceId: widget.event.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet event'),
        content: Text('Er du sikker på at du vil slette "${widget.event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(eventsProvider.notifier).deleteEvent(widget.event.id);
              if (mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(eventCommentsProviderFamily(widget.event.id).notifier)
          .addComment(body);
      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
