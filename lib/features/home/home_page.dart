import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/homepage_provider.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/providers/event_signup_provider.dart';
import 'package:jagt_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_homepage_page.dart';
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

class HomePage extends ConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF1B3A1B),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
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
        title: Text(
          hero?.title ?? 'Risinge Jagtvæsen',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [
              Shadow(blurRadius: 12, color: Colors.black),
              Shadow(blurRadius: 24, color: Colors.black87),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/risinge_hero.jpg',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x60000000),
                    Color(0x80000000),
                    Color(0xEE1B3A1B),
                  ],
                  stops: [0.3, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, WidgetRef ref, HomeBlock block,
      String userName, bool isAdmin, String userRole) {
    switch (block.blockType) {
      case 'welcome':
        return _WelcomeBlock(block: block, userName: userName);
      case 'info_cards':
        return _InfoCardsBlock(ref: ref);
      case 'next_event':
        return _NextEventBlock(ref: ref);
      case 'event_stats':
        return _EventStatsBlock(ref: ref);
      case 'weather':
        return _WeatherBlock(ref: ref);
      case 'my_reservations':
        return _MyReservationsBlock(ref: ref);
      case 'recent_chat':
        return _RecentChatBlock(ref: ref);
      case 'countdown':
        return _CountdownBlock(ref: ref);
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userName.isNotEmpty) ...[
            Text(
              'Hej, $userName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B3A1B),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            block.title ?? 'Velkommen',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          if (block.content != null && block.content!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              block.content!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Legacy info_cards (kept for backwards compat) ---

class _InfoCardsBlock extends StatelessWidget {
  final WidgetRef ref;
  const _InfoCardsBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingEventsProvider);
    final signups = ref.watch(eventSignupsProvider).value ?? [];
    final totalAttending = signups.where((s) => s.isAttending).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _InfoCard(
              icon: Icons.calendar_month,
              iconColor: const Color(0xFF2E7D32),
              title: 'Næste event',
              value: upcoming.isNotEmpty
                  ? upcoming.first.title
                  : 'Ingen planlagt',
              subtitle: upcoming.isNotEmpty
                  ? DateFormat('d. MMM yyyy', 'da').format(upcoming.first.date)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InfoCard(
              icon: Icons.people,
              iconColor: const Color(0xFFC75B39),
              title: 'Events',
              value: '${upcoming.length} kommende',
              subtitle:
                  upcoming.isNotEmpty ? '$totalAttending tilmeldte' : null,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Next Event ---

class _NextEventBlock extends StatelessWidget {
  final WidgetRef ref;
  const _NextEventBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingEventsProvider);
    final event = upcoming.isNotEmpty ? upcoming.first : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFFE8F5E9),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month,
                    color: Color(0xFF2E7D32), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: event != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Næste event',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(event.title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('EEEE d. MMM', 'da').format(event.date)}'
                            '${event.startTime != null ? ' kl. ${event.startTime}' : ''}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      )
                    : const Text('Ingen kommende events',
                        style: TextStyle(fontSize: 15, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Event Stats ---

class _EventStatsBlock extends StatelessWidget {
  final WidgetRef ref;
  const _EventStatsBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingEventsProvider);
    final signups = ref.watch(eventSignupsProvider).value ?? [];
    final totalAttending = signups.where((s) => s.isAttending).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _InfoCard(
        icon: Icons.people,
        iconColor: const Color(0xFFC75B39),
        title: 'Events',
        value: '${upcoming.length} kommende',
        subtitle: upcoming.isNotEmpty ? '$totalAttending tilmeldte' : null,
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
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            color: const Color(0xFFE3F2FD),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 36, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$temp°C — $label',
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('Risinge Herregaard',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade600),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
    final reservationsAsync = ref.watch(_myReservationsProvider);

    return reservationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reservations) {
        if (reservations.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: Colors.grey.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('Ingen kommende reservationer',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            color: const Color(0xFFF3E5F5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Colors.purple.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Dine reservationer',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...reservations.take(3).map((r) {
                    final tower = r['towers'] as Map<String, dynamic>?;
                    final event = r['hunt_events'] as Map<String, dynamic>?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.chevron_right,
                              size: 16, color: Colors.purple.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${tower?['name'] ?? '?'} — ${event?['title'] ?? '?'}',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (event?['date'] != null)
                            Text(
                              DateFormat('d/M').format(
                                  DateTime.parse(event!['date'] as String)),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (reservations.length > 3)
                    Text(
                      '+${reservations.length - 3} mere',
                      style: TextStyle(
                          fontSize: 12, color: Colors.purple.shade400),
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
    final messagesAsync = ref.watch(_recentMessagesProvider);

    return messagesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (messages) {
        if (messages.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            color: const Color(0xFFE0F7FA),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          color: Colors.teal.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Seneste beskeder',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800)),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                            backgroundColor: Colors.teal.shade100,
                            child: Text(name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    if (channelName.isNotEmpty) ...[
                                      Text(' i ',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500)),
                                      Flexible(
                                        child: Text(channelName,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.teal.shade600),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  content,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700),
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
                                  fontSize: 10, color: Colors.grey.shade500),
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

// --- Countdown ---

class _CountdownBlock extends StatelessWidget {
  final WidgetRef ref;
  const _CountdownBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingEventsProvider);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final event = upcoming.first;
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: diff.inDays <= 1
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE8EAF6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: diff.inDays <= 1
                      ? Colors.orange.shade700
                      : Colors.indigo.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  countdownText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      DateFormat('EEEE d. MMMM', 'da').format(event.date),
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
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

// --- Text Block ---

class _TextBlock extends StatelessWidget {
  final HomeBlock block;
  const _TextBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    if (block.content == null || block.content!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFFF5F0E8),
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
                      color: Colors.brown.shade800,
                      fontSize: 16,
                    ),
                  ),
                ),
              Text(
                block.content!,
                style: TextStyle(
                  color: Colors.brown.shade900,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFFFFF3E0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign, color: Colors.orange.shade700, size: 24),
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
                          color: Colors.orange.shade900,
                          fontSize: 15,
                        ),
                      ),
                    if (block.content != null &&
                        block.content!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        block.content!,
                        style: TextStyle(
                          color: Colors.orange.shade800,
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
                color: Colors.grey.shade200,
                child:
                    const Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
            if (block.title != null && block.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  block.title!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
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

// --- Info Card (reusable) ---

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
