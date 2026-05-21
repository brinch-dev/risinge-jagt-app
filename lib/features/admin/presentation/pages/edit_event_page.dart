import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jagt_app/models/hunt_event.dart';
import 'package:jagt_app/providers/event_provider.dart';
import 'package:jagt_app/providers/map_provider.dart' show huntAreasProvider;

class EditEventPage extends ConsumerStatefulWidget {
  final HuntEvent event;

  const EditEventPage({Key? key, required this.event}) : super(key: key);

  @override
  ConsumerState<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends ConsumerState<EditEventPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _checkinEnabled;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descController =
        TextEditingController(text: widget.event.description ?? '');
    _date = widget.event.date;
    _startTime = _parseTime(widget.event.startTime) ??
        const TimeOfDay(hour: 8, minute: 0);
    _endTime = _parseTime(widget.event.endTime) ??
        const TimeOfDay(hour: 16, minute: 0);
    _checkinEnabled = widget.event.checkinEnabled;
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final areas = ref.read(huntAreasProvider).value ?? [];
      final areaId = areas.isNotEmpty ? areas.first.id : null;

      await ref.read(eventsProvider.notifier).updateEvent(widget.event.id, {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'date': _date.toIso8601String().split('T').first,
        'start_time': _formatTime(_startTime),
        'end_time': _formatTime(_endTime),
        'area_id': areaId,
        'checkin_enabled': _checkinEnabled,
      });

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
        title: const Text('Rediger event'),
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
                firstDate: DateTime(2020),
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
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Gem ændringer'),
          ),
        ],
      ),
    );
  }
}
