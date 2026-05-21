import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/services/notification_service.dart';
import 'package:jagt_app/providers/notification_provider.dart';
import 'package:jagt_app/providers/admin_log_provider.dart';
import 'package:jagt_app/providers/auth_provider.dart';

class CreateEventPage extends ConsumerStatefulWidget {
  final DateTime? selectedDate;

  const CreateEventPage({Key? key, this.selectedDate}) : super(key: key);

  @override
  ConsumerState<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends ConsumerState<CreateEventPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _date;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  bool _checkinEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final areas = ref.read(huntAreasProvider).value ?? [];
      final areaId = areas.isNotEmpty ? areas.first.id : null;

      final event = HuntEvent(
        id: '',
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        date: _date,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        areaId: areaId,
        createdBy: userId,
        createdAt: DateTime.now(),
        checkinEnabled: _checkinEnabled,
      );

      final createdEvent =
          await ref.read(eventsProvider.notifier).createEvent(event);
      await NotificationService().scheduleEventReminder(createdEvent);
      await ref
          .read(notificationsProvider.notifier)
          .sendEventNotification(event.title, createdEvent.id);

      final profile = ref.read(userProfileProvider).value;
      await writeAdminLog(ref,
          type: 'event_created',
          message:
              '${profile?.displayName ?? 'Admin'} oprettede event: ${event.title}',
          userId: userId,
          userName: profile?.displayName,
          referenceId: createdEvent.id);

      if (mounted) Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nyt event'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titel *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Beskrivelse',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Dato'),
            subtitle: Text(DateFormat('d. MMMM yyyy', 'da').format(_date)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Starttid'),
            subtitle: Text(_formatTime(_startTime)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _startTime,
              );
              if (picked != null) setState(() => _startTime = picked);
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Sluttid'),
            subtitle: Text(_formatTime(_endTime)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _endTime,
              );
              if (picked != null) setState(() => _endTime = picked);
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Check-in / Check-ud'),
            subtitle: const Text('Deltagere skal checke ind naar de er i omraadet'),
            value: _checkinEnabled,
            onChanged: (v) => setState(() => _checkinEnabled = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _create,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Opret event'),
          ),
        ],
      ),
    );
  }

}
