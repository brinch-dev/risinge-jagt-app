import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/models/admin_log_entry.dart';

class AdminLogPage extends ConsumerWidget {
  const AdminLogPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminLogProvider.notifier).refresh(),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('Ingen log-poster endnu'));
          }
          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _typeColor(log.type),
                    radius: 18,
                    child: Icon(_typeIcon(log.type),
                        color: Colors.white, size: 18),
                  ),
                  title: Text(log.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${log.typeLabel} — ${DateFormat('d/M HH:mm').format(log.createdAt.toLocal())}${log.userName != null ? ' — ${log.userName}' : ''}',
                  ),
                  onTap: () => _showDetail(context, log),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, AdminLogEntry log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(log.typeLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log.message),
            const SizedBox(height: 8),
            if (log.userName != null)
              Text('Bruger: ${log.userName}',
                  style: const TextStyle(color: Colors.grey)),
            Text(
                'Tidspunkt: ${DateFormat('d. MMMM yyyy HH:mm', 'da').format(log.createdAt.toLocal())}',
                style: const TextStyle(color: Colors.grey)),
            if (log.metadata != null) ...[
              const SizedBox(height: 8),
              Text('Data: ${log.metadata}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'new_user':
        return Colors.blue;
      case 'event_signup':
        return Colors.green;
      case 'event_unsignup':
        return Colors.orange;
      case 'geofence_warning':
        return Colors.amber;
      case 'geofence_outside':
        return Colors.red;
      case 'reservation':
        return Colors.purple;
      case 'reservation_cancel':
        return Colors.purple.shade300;
      case 'event_created':
        return Colors.teal;
      case 'area_created':
        return Colors.green.shade700;
      case 'broadcast':
        return Colors.indigo;
      case 'role_change':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'new_user':
        return Icons.person_add;
      case 'event_signup':
        return Icons.how_to_reg;
      case 'event_unsignup':
        return Icons.person_remove;
      case 'geofence_warning':
        return Icons.warning;
      case 'geofence_outside':
        return Icons.gps_off;
      case 'reservation':
        return Icons.bookmark_add;
      case 'reservation_cancel':
        return Icons.bookmark_remove;
      case 'event_created':
        return Icons.event;
      case 'area_created':
        return Icons.map;
      case 'broadcast':
        return Icons.campaign;
      case 'role_change':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }
}
