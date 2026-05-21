import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:jagt_app/models/app_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/providers/notification_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final profile = ref.watch(userProfileProvider).value;
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikationer'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllAsRead(),
            child: const Text('Marker alle læst'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Ingen notifikationer'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _NotificationTile(
                notification: notif,
                isAdmin: isAdmin,
                onTap: () {
                  if (!notif.isRead) {
                    ref
                        .read(notificationsProvider.notifier)
                        .markAsRead(notif.id);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showBroadcastDialog(context, ref),
              child: const Icon(Icons.campaign),
            )
          : null,
    );
  }

  void _showBroadcastDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send broadcast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titel *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bodyCtrl,
              decoration: const InputDecoration(
                labelText: 'Besked',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await ref
                  .read(notificationsProvider.notifier)
                  .sendBroadcast(titleCtrl.text.trim(), bodyCtrl.text.trim());
              final profile = ref.read(userProfileProvider).value;
              await writeAdminLog(ref,
                  type: 'broadcast',
                  message:
                      '${profile?.displayName ?? 'Admin'} sendte broadcast: ${titleCtrl.text.trim()}',
                  userId: Supabase.instance.client.auth.currentUser?.id,
                  userName: profile?.displayName);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isAdmin;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();
    final color = _getColor();

    return Card(
      color: notification.isRead ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.body != null && notification.body!.isNotEmpty)
              Text(notification.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  notification.typeLabel,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                ),
                if (notification.senderName != null) ...[
                  const Text(' - ', style: TextStyle(fontSize: 11)),
                  Text(notification.senderName!, style: const TextStyle(fontSize: 11)),
                ],
                const Spacer(),
                Text(
                  timeago.format(notification.createdAt, locale: 'da'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.broadcast:
        return Icons.campaign;
      case NotificationType.newEvent:
        return Icons.event;
      case NotificationType.chatMessage:
        return Icons.chat_bubble;
      case NotificationType.chatGeneral:
        return Icons.forum;
    }
  }

  Color _getColor() {
    switch (notification.type) {
      case NotificationType.broadcast:
        return Colors.orange;
      case NotificationType.newEvent:
        return Colors.green;
      case NotificationType.chatMessage:
        return Colors.blue;
      case NotificationType.chatGeneral:
        return Colors.purple;
    }
  }
}
