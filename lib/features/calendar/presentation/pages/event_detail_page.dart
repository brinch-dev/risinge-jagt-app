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
import 'package:jagt_app/providers/game_bag_provider.dart';
import 'package:jagt_app/constants/game_species.dart';

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
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    // Fallback: sunrise/sunset works for any date (astronomical calculation)
    final fallback = await http.get(Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${params.lat}&longitude=${params.lng}'
      '&daily=sunrise,sunset'
      '&timezone=Europe/Copenhagen'
      '&start_date=$dateStr&end_date=$dateStr',
    ));
    if (fallback.statusCode == 200) {
      return jsonDecode(fallback.body) as Map<String, dynamic>;
    }
    return null;
  } catch (_) {
    return null;
  }
});

class EventDetailPage extends ConsumerStatefulWidget {
  final HuntEvent event;
  const EventDetailPage({super.key, required this.event});

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
            if (!_isEventPast(event))
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
          _GameBagSection(eventId: event.id),
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
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Skriv en note...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 5,
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
        final sunriseList = daily['sunrise'] as List?;
        final sunsetList = daily['sunset'] as List?;
        if (sunriseList == null || sunriseList.isEmpty ||
            sunsetList == null || sunsetList.isEmpty) {
          return const SizedBox.shrink();
        }
        final sunrise = (sunriseList.first as String).split('T').last;
        final sunset = (sunsetList.first as String).split('T').last;

        final tempMaxRaw = (daily['temperature_2m_max'] as List?)?.first;
        final tempMinRaw = (daily['temperature_2m_min'] as List?)?.first;
        final int? tempMax = tempMaxRaw is num ? tempMaxRaw.round() : null;
        final int? tempMin = tempMinRaw is num ? tempMinRaw.round() : null;

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
                  if (tempMin != null && tempMax != null)
                    _weatherCol(context, Icons.thermostat,
                        '$tempMin° / $tempMax°', 'Temp'),
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
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }

  bool _isEventPast(HuntEvent event) {
    final now = DateTime.now();
    final lockTime = DateTime(event.date.year, event.date.month, event.date.day, 0, 1);
    return now.isAfter(lockTime);
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

class _GameBagSection extends ConsumerStatefulWidget {
  final String eventId;
  const _GameBagSection({required this.eventId});

  @override
  ConsumerState<_GameBagSection> createState() => _GameBagSectionState();
}

class _GameBagSectionState extends ConsumerState<_GameBagSection> {
  String? _selectedSpecies;
  final _countCtrl = TextEditingController();
  final _shotsCtrl = TextEditingController();
  bool _shotsInitialized = false;
  bool _isExpanded = false;

  @override
  void dispose() {
    _countCtrl.dispose();
    _shotsCtrl.dispose();
    super.dispose();
  }

  void _pickSpecies() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Vælg vildtart',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: gameSpeciesCategories.expand((cat) => [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(cat.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                          letterSpacing: 1,
                        )),
                  ),
                  ...cat.species.map((s) => ListTile(
                        title: Text(s),
                        dense: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedSpecies = s);
                        },
                      )),
                ]).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gameBagAsync = ref.watch(gameBagProviderFamily(widget.eventId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.pets, size: 20, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nedlagt vildt',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                )),
                            gameBagAsync.whenOrNull(
                                  data: (gb) => gb.entries.isNotEmpty
                                      ? Text(
                                          '${gb.entries.length} arter — ${gb.entries.fold<int>(0, (s, e) => s + e.count)} stk.',
                                          style: TextStyle(fontSize: 12, color: cs.outline),
                                        )
                                      : Text('Tryk for at registrere',
                                          style: TextStyle(fontSize: 12, color: cs.outline)),
                                ) ??
                                const SizedBox.shrink(),
                          ],
                        ),
                      ),
                      gameBagAsync.whenOrNull(
                            data: (gb) => gb.totalShots != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.secondaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('${gb.totalShots} skud',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSecondaryContainer,
                                        )),
                                  )
                                : null,
                          ) ??
                          const SizedBox.shrink(),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, color: cs.outline),
                      ),
                    ],
                  ),
                ),
              ),

              gameBagAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Fejl: $e'),
                ),
                data: (gameBag) {
                  if (!_shotsInitialized && gameBag.totalShots != null) {
                    _shotsCtrl.text = gameBag.totalShots.toString();
                    _shotsInitialized = true;
                  }
                  return Column(
                    children: [
                      if (gameBag.entries.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            children: [
                              for (int i = 0; i < gameBag.entries.length; i++) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${gameBag.entries[i].count}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          gameBag.entries[i].species,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(Icons.close, size: 16, color: cs.outline),
                                          onPressed: () => ref
                                              .read(gameBagProviderFamily(widget.eventId).notifier)
                                              .deleteEntry(gameBag.entries[i].id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < gameBag.entries.length - 1)
                                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                              ],
                            ],
                          ),
                        ),

                      if (gameBag.entries.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total vildt',
                                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                              Text(
                                '${gameBag.entries.fold<int>(0, (sum, e) => sum + e.count)} stk.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _isExpanded
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    GestureDetector(
                                      onTap: _pickSpecies,
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: 'Vildtart',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          suffixIcon: Icon(Icons.arrow_drop_down, color: cs.outline),
                                        ),
                                        child: Text(
                                          _selectedSpecies ?? 'Vælg art...',
                                          style: TextStyle(
                                            color: _selectedSpecies != null ? cs.onSurface : cs.outline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _countCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Antal',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        FilledButton.icon(
                                          onPressed: _addEntry,
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Tilføj'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _shotsCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Samlet antal skud afgivet',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        FilledButton.tonal(
                                          onPressed: _saveTotalShots,
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text('Gem'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        gameBagAsync.whenOrNull(
          data: (gb) {
            final totalGame = gb.entries.fold<int>(0, (sum, e) => sum + e.count);
            if (totalGame == 0 && gb.totalShots == null) return null;
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCol(cs, '$totalGame', 'Nedlagt'),
                      if (gb.totalShots != null)
                        _statCol(cs, '${gb.totalShots}', 'Skud afgivet'),
                    ],
                  ),
                ),
              ),
            );
          },
        ) ?? const SizedBox.shrink(),
      ],
    );
  }

  Widget _statCol(ColorScheme cs, String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: cs.outline)),
      ],
    );
  }

  Future<void> _addEntry() async {
    if (_selectedSpecies == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vælg en vildtart først')),
      );
      return;
    }
    final count = int.tryParse(_countCtrl.text.trim());
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indtast antal (mindst 1)')),
      );
      return;
    }

    try {
      await ref
          .read(gameBagProviderFamily(widget.eventId).notifier)
          .addOrUpdateEntry(_selectedSpecies!, count);
      _countCtrl.clear();
      setState(() => _selectedSpecies = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }

  Future<void> _saveTotalShots() async {
    final shots = int.tryParse(_shotsCtrl.text.trim());
    if (shots == null || shots < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indtast antal skud')),
      );
      return;
    }

    try {
      await ref
          .read(gameBagProviderFamily(widget.eventId).notifier)
          .setTotalShots(shots);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Antal skud gemt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fejl: $e')));
      }
    }
  }
}
