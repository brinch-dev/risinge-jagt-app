import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/event_signup_provider.dart';
import 'package:jagt_app/providers/homepage_provider.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_homepage_page.dart';
import 'package:jagt_app/features/home/home_shell.dart';
import 'package:jagt_app/features/calendar/presentation/pages/event_detail_page.dart';
import 'package:jagt_app/bootstrap.dart';

final _weatherProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final response = await http.get(Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=55.3835&longitude=10.6100'
      '&current=temperature_2m,wind_speed_10m,weather_code,relative_humidity_2m'
      '&daily=sunrise,sunset,temperature_2m_max,temperature_2m_min'
      '&timezone=Europe/Copenhagen&forecast_days=1',
    ));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

final _myReservationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final data = await client
      .from('tower_reservations')
      .select('*, towers(name), hunt_events(title, date)')
      .eq('user_id', userId)
      .gte('hunt_events.date', DateTime.now().toIso8601String().split('T')[0])
      .order('reserved_at', ascending: true);
  return List<Map<String, dynamic>>.from(data)
      .where((r) => r['hunt_events'] != null)
      .toList();
});

final _recentMessagesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseProvider);
  final data = await client
      .from('chat_messages')
      .select('content, created_at, message_type, profiles(display_name), chat_channels(name)')
      .order('created_at', ascending: false)
      .limit(5);
  return List<Map<String, dynamic>>.from(data);
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _refreshTimer;
  int _tickCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _tickCount++;
      ref.invalidate(upcomingEventsProvider);
      ref.invalidate(_myReservationsProvider);
      ref.invalidate(_recentMessagesProvider);
      if (_tickCount % 15 == 0) {
        ref.invalidate(_weatherProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final blocksAsync = ref.watch(homeBlocksProvider);
    final isAdmin = profile?.isAdmin ?? false;
    final userRole = profile?.role.dbValue ?? 'gaest';

    return blocksAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Fejl: $e')),
      ),
      data: (allBlocks) {
        final blocks = allBlocks
            .where((b) => b.isActive && b.isVisibleToRole(userRole))
            .toList();

        final heroBlock =
            blocks.where((b) => b.blockType == 'hero').firstOrNull;
        final contentBlocks =
            blocks.where((b) => b.blockType != 'hero').toList();

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _buildHero(heroBlock, isAdmin, context, ref),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final block in contentBlocks)
                        _buildBlock(context, ref, block,
                            profile?.displayName ?? '', isAdmin, userRole),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(
      HomeBlock? hero, bool isAdmin, BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: cs.primary,
      iconTheme: IconThemeData(color: cs.onPrimary),
      actionsIconTheme: IconThemeData(color: cs.onPrimary),
      actions: [
        const NotificationBell(),
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.dashboard_customize),
            tooltip: 'Rediger forside',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageHomepagePage()),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/risinge_hero.jpg',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x60000000),
                          const Color(0x80000000),
                          cs.primary.withValues(alpha: 0.93),
                        ],
                        stops: const [0.3, 0.6, 1.0],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x20000000),
                          const Color(0x10000000),
                          cs.primary.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToTab(WidgetRef ref, int index) {
    ref.read(tabIndexProvider.notifier).set(index);
  }

  Widget _buildBlock(BuildContext context, WidgetRef ref, HomeBlock block,
      String userName, bool isAdmin, String userRole) {
    switch (block.blockType) {
      case 'welcome':
        return _WelcomeBlock(block: block, userName: userName);
      case 'info_cards':
        return const SizedBox.shrink();
      case 'next_event':
        return const SizedBox.shrink();
      case 'event_stats':
        return _UpcomingEventsBlock(ref: ref);
      case 'weather':
        return _WeatherBlock(ref: ref);
      case 'my_reservations':
        return _MyReservationsBlock(ref: ref);
      case 'recent_chat':
        return GestureDetector(
          onTap: () => _goToTab(ref, 3),
          child: _RecentChatBlock(ref: ref),
        );
      case 'countdown':
        return _NextEventCountdownBlock(ref: ref);
      case 'text':
        return _TextBlock(block: block);
      case 'announcement':
        return _AnnouncementBlock(block: block);
      case 'image':
        return _ImageBlock(block: block);
      default:
        return const SizedBox.shrink();
    }
  }
}

// --- Welcome ---

class _WelcomeBlock extends StatelessWidget {
  final HomeBlock block;
  final String userName;
  const _WelcomeBlock({required this.block, required this.userName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userName.isNotEmpty) ...[
            Text(
              'Hej, $userName',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            block.title ?? 'Velkommen',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (block.content != null && block.content!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              block.content!,
              style: TextStyle(
                fontSize: 14,
                color: cs.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Next Event + Countdown (combined) ---

class _NextEventCountdownBlock extends StatelessWidget {
  final WidgetRef ref;
  const _NextEventCountdownBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final upcoming = ref.watch(upcomingEventsProvider);
    final event = upcoming.isNotEmpty ? upcoming.first : null;

    if (event == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
    final diff = eventDate.difference(DateTime(now.year, now.month, now.day));
    String countdownText;
    if (diff.inDays == 0) {
      countdownText = 'I DAG';
    } else if (diff.inDays == 1) {
      countdownText = 'I MORGEN';
    } else {
      countdownText = '${diff.inDays} DAGE';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
        ),
        child: Card(
          color: cs.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cs.primary, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NÆSTE EVENT',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.outline,
                        letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(countdownText,
                          style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface)),
                          Text(
                            '${DateFormat('EEEE d. MMMM', 'da').format(event.date)}'
                            '${event.startTime != null ? ' kl. ${event.startTime}' : ''}',
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.outline),
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

// --- Upcoming Events List ---

class _UpcomingEventsBlock extends StatelessWidget {
  final WidgetRef ref;
  const _UpcomingEventsBlock({required this.ref});

  String _statusLabel(HuntEvent event, List signups, String? userId) {
    if (userId == null) return 'Ikke reageret';
    final signup = signups.where((s) => s.eventId == event.id && s.userId == userId).firstOrNull;
    if (signup == null) return 'Ikke reageret';
    return signup.isAttending ? 'Tilmeldt' : 'Kommer ikke';
  }

  Color _statusColor(String label, ColorScheme cs) {
    switch (label) {
      case 'Tilmeldt':
        return cs.primary;
      case 'Kommer ikke':
        return cs.error;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final upcoming = ref.watch(upcomingEventsProvider);
    final signups = ref.watch(eventSignupsProvider).value ?? [];
    final userId = ref.watch(currentUserProvider)?.id;

    if (upcoming.isEmpty) return const SizedBox.shrink();

    final preview = upcoming.take(3).toList();
    final hasMore = upcoming.length > 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('KOMMENDE EVENTS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.outline,
                          letterSpacing: 1.2)),
                  const Spacer(),
                  Text('${upcoming.length} i alt',
                      style: TextStyle(fontSize: 12, color: cs.outline)),
                ],
              ),
              const SizedBox(height: 12),
              ...preview.map((event) {
                final label = _statusLabel(event, signups, userId);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              DateFormat('d\nMMM', 'da').format(event.date),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                  height: 1.2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                DateFormat('EEEE', 'da').format(event.date) +
                                    (event.startTime != null ? ' kl. ${event.startTime}' : ''),
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(label, cs).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(label, cs))),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (hasMore) ...[
                const Divider(),
                GestureDetector(
                  onTap: () => _showAllEvents(context, upcoming, signups, userId, cs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Se alle ${upcoming.length} events',
                          style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w600)),
                      Icon(Icons.expand_more, color: cs.primary, size: 18),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAllEvents(BuildContext context, List<HuntEvent> events, List signups,
      String? userId, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Alle kommende events',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final event = events[i];
                  final signup = signups
                      .where((s) => s.eventId == event.id && s.userId == userId)
                      .firstOrNull;
                  final label = signup == null
                      ? 'Ikke reageret'
                      : signup.isAttending
                          ? 'Tilmeldt'
                          : 'Kommer ikke';
                  return ListTile(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => EventDetailPage(event: event)));
                    },
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text(
                          DateFormat('d\nMMM', 'da').format(event.date),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: cs.primary, height: 1.2),
                        ),
                      ),
                    ),
                    title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(DateFormat('EEEE d. MMMM', 'da').format(event.date),
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: (label == 'Tilmeldt'
                                  ? cs.primary
                                  : label == 'Kommer ikke'
                                      ? cs.error
                                      : cs.outline)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: label == 'Tilmeldt'
                                  ? cs.primary
                                  : label == 'Kommer ikke'
                                      ? cs.error
                                      : cs.outline)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Weather + Sun ---

class _WeatherBlock extends StatelessWidget {
  final WidgetRef ref;
  const _WeatherBlock({required this.ref});

  static const _weatherIcons = {
    0: Icons.wb_sunny,
    1: Icons.wb_sunny,
    2: Icons.cloud,
    3: Icons.cloud,
    45: Icons.foggy,
    48: Icons.foggy,
    51: Icons.grain,
    53: Icons.grain,
    55: Icons.grain,
    61: Icons.water_drop,
    63: Icons.water_drop,
    65: Icons.water_drop,
    71: Icons.ac_unit,
    73: Icons.ac_unit,
    75: Icons.ac_unit,
    80: Icons.shower,
    81: Icons.shower,
    82: Icons.shower,
    95: Icons.thunderstorm,
    96: Icons.thunderstorm,
    99: Icons.thunderstorm,
  };

  static const _weatherLabels = {
    0: 'Klart vejr',
    1: 'Overvejende klart',
    2: 'Delvist skyet',
    3: 'Overskyet',
    45: 'Tåget',
    48: 'Rimtåge',
    51: 'Let støvregn',
    53: 'Støvregn',
    55: 'Tæt støvregn',
    61: 'Let regn',
    63: 'Regn',
    65: 'Kraftig regn',
    71: 'Let sne',
    73: 'Sne',
    75: 'Kraftig sne',
    80: 'Regnbyger',
    81: 'Kraftige byger',
    82: 'Voldsomme byger',
    95: 'Tordenvejr',
    96: 'Torden med hagl',
    99: 'Kraftig torden',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weatherAsync = ref.watch(_weatherProvider);

    return weatherAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final current = data['current'] as Map<String, dynamic>;
        final daily = data['daily'] as Map<String, dynamic>;
        final temp = (current['temperature_2m'] as num).round();
        final wind = (current['wind_speed_10m'] as num).round();
        final humidity = (current['relative_humidity_2m'] as num).round();
        final code = current['weather_code'] as int;
        final sunrise = (daily['sunrise'] as List).first as String;
        final sunset = (daily['sunset'] as List).first as String;
        final sunriseTime = sunrise.split('T').last;
        final sunsetTime = sunset.split('T').last;
        final icon = _weatherIcons[code] ?? Icons.cloud;
        final label = _weatherLabels[code] ?? 'Ukendt';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 36, color: cs.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$temp°C — $label',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface)),
                            const SizedBox(height: 2),
                            Text('Risinge Herregaard',
                                style: TextStyle(
                                    fontSize: 12, color: cs.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _WeatherDetail(
                          icon: Icons.air, label: 'Vind', value: '$wind km/t'),
                      _WeatherDetail(
                          icon: Icons.water_drop_outlined,
                          label: 'Fugtighed',
                          value: '$humidity%'),
                      _WeatherDetail(
                          icon: Icons.wb_twilight,
                          label: 'Sol op',
                          value: sunriseTime),
                      _WeatherDetail(
                          icon: Icons.nightlight_round,
                          label: 'Sol ned',
                          value: sunsetTime),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeatherDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WeatherDetail(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: cs.outline),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
        Text(label, style: TextStyle(fontSize: 10, color: cs.outline)),
      ],
    );
  }
}

// --- My Reservations ---

class _MyReservationsBlock extends StatelessWidget {
  final WidgetRef ref;
  const _MyReservationsBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reservationsAsync = ref.watch(_myReservationsProvider);

    return reservationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reservations) {
        if (reservations.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: cs.outline),
                    const SizedBox(width: 12),
                    Text('Ingen kommende reservationer',
                        style: TextStyle(color: cs.outline)),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('DINE RESERVATIONER',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.outline,
                              letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...reservations.take(5).map((r) {
                    final tower = r['towers'] as Map<String, dynamic>?;
                    final eventData = r['hunt_events'] as Map<String, dynamic>?;
                    final allEvents = ref.watch(eventsProvider).value ?? [];
                    final eventId = r['event_id'] as String?;
                    final matchedEvent = eventId != null
                        ? allEvents.where((e) => e.id == eventId).firstOrNull
                        : null;
                    return GestureDetector(
                      onTap: matchedEvent != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EventDetailPage(event: matchedEvent),
                                ),
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.chevron_right,
                                size: 16, color: cs.outline),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${tower?['name'] ?? '?'} — ${eventData?['title'] ?? '?'}',
                                style: TextStyle(
                                    fontSize: 14, color: cs.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (eventData?['date'] != null)
                              Text(
                                DateFormat('d/M').format(
                                    DateTime.parse(eventData!['date'] as String)),
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (reservations.length > 5)
                    Text(
                      '+${reservations.length - 5} mere',
                      style: TextStyle(
                          fontSize: 12, color: cs.outline),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Recent Chat ---

class _RecentChatBlock extends StatelessWidget {
  final WidgetRef ref;
  const _RecentChatBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final messagesAsync = ref.watch(_recentMessagesProvider);

    return messagesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (messages) {
        if (messages.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('SENESTE BESKEDER',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.outline,
                              letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...messages.take(4).map((m) {
                    final sender =
                        m['profiles'] as Map<String, dynamic>?;
                    final channel =
                        m['chat_channels'] as Map<String, dynamic>?;
                    final name = sender?['display_name'] as String? ?? '?';
                    final channelName = channel?['name'] as String? ?? '';
                    final type = m['message_type'] as String? ?? 'text';
                    final content = type == 'text'
                        ? (m['content'] as String? ?? '')
                        : type == 'image'
                            ? 'Billede'
                            : 'Video';
                    final time = DateTime.tryParse(m['created_at'] as String? ?? '');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: cs.primaryContainer,
                            child: Text(name[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11, color: cs.onPrimaryContainer)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface)),
                                    if (channelName.isNotEmpty) ...[
                                      Text(' i ',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: cs.outline)),
                                      Flexible(
                                        child: Text(channelName,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  content,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (time != null)
                            Text(
                              DateFormat('HH:mm').format(time.toLocal()),
                              style: TextStyle(
                                  fontSize: 10, color: cs.outline),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Text Block ---

class _TextBlock extends StatelessWidget {
  final HomeBlock block;
  const _TextBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (block.content == null || block.content!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.title != null && block.title!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    block.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
              Text(
                block.content!,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Announcement ---

class _AnnouncementBlock extends StatelessWidget {
  final HomeBlock block;
  const _AnnouncementBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: cs.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign, color: cs.onPrimaryContainer, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (block.title != null && block.title!.isNotEmpty)
                      Text(
                        block.title!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                          fontSize: 15,
                        ),
                      ),
                    if (block.content != null &&
                        block.content!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        block.content!,
                        style: TextStyle(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Image ---

class _ImageBlock extends StatelessWidget {
  final HomeBlock block;
  const _ImageBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (block.imageUrl == null || block.imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              block.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: cs.surfaceContainerHighest,
                child:
                    Center(child: Icon(Icons.broken_image, size: 48, color: cs.outline)),
              ),
            ),
            if (block.title != null && block.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  block.title!,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
