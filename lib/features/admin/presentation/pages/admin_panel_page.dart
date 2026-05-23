import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_areas_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_users_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/admin_log_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/broadcast_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_roles_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_homepage_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_channels_page.dart';

class AdminPanelPage extends ConsumerWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    if (profile == null || !profile.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
          child: Text('Kun administratorer har adgang'),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _adminTile(context, Icons.map, cs.primary, 'Jagtområder',
              'Opret og administrer jagtområder', const ManageAreasPage()),
          const SizedBox(height: 8),
          _adminTile(context, Icons.people, cs.primary, 'Brugere',
              'Administrer brugerroller', const ManageUsersPage()),
          const SizedBox(height: 8),
          _adminTile(context, Icons.dashboard_customize, cs.primary, 'Forside',
              'Rediger forsideblokke og synlighed', const ManageHomepagePage()),
          const SizedBox(height: 8),
          _adminTile(context, Icons.shield, cs.primary, 'Roller',
              'Opret, rediger og slet roller + chat adgang', const ManageRolesPage()),
          const SizedBox(height: 8),
          _adminTile(context, Icons.chat, cs.primary, 'Chat-kanaler',
              'Opret, rediger og slet kanaler + rolle-adgang', const ManageChannelsPage()),
          const SizedBox(height: 8),
          _adminTile(context, Icons.campaign, cs.primary, 'Broadcast',
              'Send besked til alle medlemmer', const BroadcastPage()),
          const SizedBox(height: 8),
          _adminTile(context, Icons.list_alt, cs.primary, 'Admin Log',
              'Se al aktivitet i appen', const AdminLogPage()),
        ],
      ),
    );
  }

  Widget _adminTile(BuildContext context, IconData icon, Color color,
      String title, String subtitle, Widget page) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }
}
