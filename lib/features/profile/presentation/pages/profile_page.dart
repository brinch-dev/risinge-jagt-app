import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:jagt_app/features/profile/presentation/pages/journal_page.dart';
import 'package:jagt_app/services/push_notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 36),
            const SizedBox(width: 10),
            const Text('Profil'),
          ],
        ),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (!kIsWeb) await PushNotificationService().removeToken();
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil ikke fundet'));
          }
          return _buildProfile(profile);
        },
      ),
    );
  }

  Widget _buildProfile(UserProfile profile) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              profile.displayName.isNotEmpty
                  ? profile.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 36),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            profile.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            profile.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Chip(
            label: Text(profile.role.label),
            avatar: Icon(_roleIcon(profile.role), size: 18),
            backgroundColor: _roleColor(profile.role),
          ),
        ),
        const SizedBox(height: 32),
        Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Jagtjournal'),
            subtitle: const Text('Personlig registrering pr. kreds'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JournalPage()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rediger navn'),
            onTap: () => _editName(profile),
          ),
        ),
        if (profile.isAdmin) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin panel'),
              subtitle: const Text('Administrer områder og brugere'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin'),
            ),
          ),
        ],
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _confirmDeleteAccount(),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Slet konto', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 32),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '';
            final build = snapshot.data?.buildNumber ?? '';
            return Center(
              child: Text(
                'Version $version ($build)',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.shield;
      case UserRole.jaegerMedlem:
        return Icons.person;
      case UserRole.ejer:
        return Icons.home;
      case UserRole.forvalter:
        return Icons.manage_accounts;
      case UserRole.bbDirektoer:
        return Icons.hotel;
      case UserRole.jagtGaest:
        return Icons.nature_people;
      case UserRole.gaest:
        return Icons.person_outline;
    }
  }

  Color _roleColor(UserRole role) {
    final cs = Theme.of(context).colorScheme;
    switch (role) {
      case UserRole.admin:
        return cs.secondaryContainer;
      case UserRole.jaegerMedlem:
        return cs.primaryContainer;
      case UserRole.ejer:
        return cs.primaryContainer;
      case UserRole.forvalter:
        return cs.primaryContainer;
      case UserRole.bbDirektoer:
        return cs.secondaryContainer;
      case UserRole.jagtGaest:
        return cs.surfaceContainerHighest;
      case UserRole.gaest:
        return cs.surfaceContainerHighest;
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet konto permanent?'),
        content: const Text(
          'Dette sletter din konto og alle tilhørende data permanent. '
          'Handlingen kan ikke fortrydes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (!kIsWeb) await PushNotificationService().removeToken();
                await ref.read(authServiceProvider).deleteAccount();
                if (context.mounted) context.go('/login');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fejl ved sletning: $e')),
                  );
                }
              }
            },
            child: const Text('Slet konto'),
          ),
        ],
      ),
    );
  }

  void _editName(UserProfile profile) {
    final controller = TextEditingController(text: profile.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rediger navn'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Navn',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref
                    .read(userProfileProvider.notifier)
                    .updateProfile(displayName: controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Gem'),
          ),
        ],
      ),
    );
  }
}
