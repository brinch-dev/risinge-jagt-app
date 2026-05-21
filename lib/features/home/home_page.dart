import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/homepage_provider.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/providers/event_signup_provider.dart';
import 'package:jagt_app/providers/chat_provider.dart';
import 'package:jagt_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_homepage_page.dart';

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
                        _buildBlock(context, ref, block, profile?.displayName ?? '', isAdmin, userRole),
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

  Widget _buildHero(HomeBlock? hero, bool isAdmin, BuildContext context, WidgetRef ref) {
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

  Widget _buildBlock(BuildContext context, WidgetRef ref, HomeBlock block, String userName, bool isAdmin, String userRole) {
    switch (block.blockType) {
      case 'welcome':
        return _WelcomeBlock(block: block, userName: userName);
      case 'info_cards':
        return _InfoCardsBlock(ref: ref);
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
              'Hej, $userName 👋',
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

class _InfoCardsBlock extends StatelessWidget {
  final WidgetRef ref;
  const _InfoCardsBlock({required this.ref});

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingEventsProvider);
    final channelsAsync = ref.watch(chatChannelsProvider);
    final signups = ref.watch(eventSignupsProvider).value ?? [];
    final totalAttending = signups.where((s) => s.isAttending).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
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
                  subtitle: upcoming.isNotEmpty
                      ? '$totalAttending tilmeldte'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: channelsAsync.when(
                  loading: () => _InfoCard(
                    icon: Icons.chat,
                    iconColor: Colors.blue.shade700,
                    title: 'Chat',
                    value: '...',
                  ),
                  error: (_, __) => _InfoCard(
                    icon: Icons.chat,
                    iconColor: Colors.blue.shade700,
                    title: 'Chat',
                    value: '-',
                  ),
                  data: (channels) => _InfoCard(
                    icon: Icons.chat,
                    iconColor: Colors.blue.shade700,
                    title: 'Chat',
                    value: '${channels.length} kanaler',
                    subtitle: 'Tilgængelige for dig',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  icon: Icons.map,
                  iconColor: const Color(0xFF2E7D32),
                  title: 'Kort',
                  value: 'Jagtkort',
                  subtitle: 'Tårne & områder',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
                    if (block.content != null && block.content!.isNotEmpty) ...[
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
                child: const Center(child: Icon(Icons.broken_image, size: 48)),
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
