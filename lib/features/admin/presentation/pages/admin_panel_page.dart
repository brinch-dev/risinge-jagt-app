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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.map, color: Colors.green),
              title: const Text('Jagtområder'),
              subtitle: const Text('Opret og administrer jagtområder'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageAreasPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people, color: Colors.blue),
              title: const Text('Brugere'),
              subtitle: const Text('Administrer brugerroller'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageUsersPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_customize, color: Colors.indigo),
              title: const Text('Forside'),
              subtitle: const Text('Rediger forsideblokke og synlighed'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageHomepagePage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield, color: Colors.purple),
              title: const Text('Roller'),
              subtitle: const Text('Opret, rediger og slet roller + chat adgang'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageRolesPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat, color: Colors.teal),
              title: const Text('Chat-kanaler'),
              subtitle: const Text('Opret, rediger og slet kanaler + rolle-adgang'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageChannelsPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign, color: Colors.orange),
              title: const Text('Broadcast'),
              subtitle: const Text('Send besked til alle medlemmer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BroadcastPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.deepOrange),
              title: const Text('Admin Log'),
              subtitle: const Text('Se al aktivitet i appen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLogPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
