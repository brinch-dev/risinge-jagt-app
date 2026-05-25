import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/providers/notification_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/services/notification_service.dart';

class BroadcastPage extends ConsumerStatefulWidget {
  const BroadcastPage({super.key});

  @override
  ConsumerState<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends ConsumerState<BroadcastPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime = TimeOfDay.now();
  String? _selectedEventId;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titel er påkrævet')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final title = _titleCtrl.text.trim();
      final body = _bodyCtrl.text.trim();
      final profile = ref.read(userProfileProvider).value;

      if (_isScheduled) {
        final scheduled = DateTime(
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
          _scheduledTime.hour,
          _scheduledTime.minute,
        );

        if (scheduled.isBefore(DateTime.now())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tidspunkt skal være i fremtiden')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        await NotificationService().scheduleLocalBroadcast(
          title: title,
          body: body,
          scheduledTime: scheduled,
        );

        await ref
            .read(notificationsProvider.notifier)
            .sendBroadcast(title, body, referenceId: _selectedEventId);

        await writeAdminLog(ref,
            type: 'broadcast',
            message:
                '${profile?.displayName ?? 'Admin'} planlagde broadcast: $title til ${DateFormat('d/M HH:mm').format(scheduled)}',
            userId: Supabase.instance.client.auth.currentUser?.id,
            userName: profile?.displayName,
            referenceId: _selectedEventId,
            metadata: {'scheduled_at': scheduled.toIso8601String()});
      } else {
        await ref
            .read(notificationsProvider.notifier)
            .sendBroadcast(title, body, referenceId: _selectedEventId);

        await writeAdminLog(ref,
            type: 'broadcast',
            message:
                '${profile?.displayName ?? 'Admin'} sendte broadcast: $title',
            userId: Supabase.instance.client.auth.currentUser?.id,
            userName: profile?.displayName,
            referenceId: _selectedEventId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isScheduled ? 'Broadcast planlagt' : 'Broadcast sendt'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send broadcast'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.campaign, size: 48, color: Colors.orange),
          const SizedBox(height: 8),
          Text(
            'Send en besked til alle medlemmer',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Titel *',
              hintText: 'F.eks. Husk jagtpas til lørdag',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Besked (valgfrit)',
              hintText: 'Yderligere detaljer...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.message),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Tilknyt event (valgfrit)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
            // ignore: deprecated_member_use
            value: _selectedEventId,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Ingen event valgt'),
              ),
              ...eventsAsync.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.title} — ${DateFormat('d/M').format(e.date)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (v) => setState(() => _selectedEventId = v),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Planlæg tidspunkt'),
            subtitle:
                const Text('Send push-notifikation på et bestemt tidspunkt'),
            value: _isScheduled,
            onChanged: (v) => setState(() => _isScheduled = v),
          ),
          if (_isScheduled) ...[
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Dato'),
                    subtitle: Text(DateFormat('d. MMMM yyyy', 'da')
                        .format(_scheduledDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _scheduledDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _scheduledDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Tidspunkt'),
                    subtitle: Text(
                        '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}'),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _scheduledTime,
                      );
                      if (picked != null) {
                        setState(() => _scheduledTime = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isLoading ? null : _send,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_isScheduled ? Icons.schedule_send : Icons.send),
            label: Text(_isScheduled ? 'Planlæg broadcast' : 'Send nu'),
          ),
        ],
      ),
    );
  }
}
