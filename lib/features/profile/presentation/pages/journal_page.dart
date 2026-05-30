import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jagt_app/constants/dj_kredse.dart';
import 'package:jagt_app/constants/game_species.dart';
import 'package:jagt_app/models/journal_entry.dart';
import 'package:jagt_app/providers/journal_provider.dart';

class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  int? _selectedKreds;
  String? _selectedSpecies;
  final _countCtrl = TextEditingController(text: '1');
  bool _locating = false;

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _suggestKreds() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final suggested = suggestKredsFromLocation(pos.latitude, pos.longitude);
      if (suggested != null && mounted) {
        setState(() => _selectedKreds = suggested);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addEntry() async {
    if (_selectedKreds == null || _selectedSpecies == null) return;
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (count <= 0) return;
    await ref.read(journalProvider.notifier).addEntry(_selectedKreds!, _selectedSpecies!, count);
    setState(() {
      _selectedSpecies = null;
      _countCtrl.text = '1';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tilføjet til journalen')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final journalAsync = ref.watch(journalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jagtjournal')),
      body: journalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (entries) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAddForm(cs),
            const SizedBox(height: 24),
            if (entries.isNotEmpty) ...[
              _buildSummary(entries, cs),
              const SizedBox(height: 16),
              _buildPerKreds(entries, cs),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Ingen registreringer endnu',
                      style: TextStyle(color: cs.outline)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm(ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ny registrering',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 16),

            // Kreds selector
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedKreds,
                    hint: const Text('Vælg kreds...'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    items: djKredse
                        .map((k) => DropdownMenuItem(
                              value: k.number,
                              child: Text('Kreds ${k.number} — ${k.name}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedKreds = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Foreslå kreds fra GPS',
                  icon: _locating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  onPressed: _locating ? null : _suggestKreds,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Art dropdown
            DropdownButtonFormField<String>(
              value: _selectedSpecies,
              hint: const Text('Vælg art...'),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              items: gameSpeciesCategories
                  .expand((cat) => [
                        DropdownMenuItem<String>(
                          enabled: false,
                          value: '__cat__${cat.name}',
                          child: Text(cat.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary)),
                        ),
                        ...cat.species.map((s) => DropdownMenuItem(
                              value: s,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(s),
                              ),
                            )),
                      ])
                  .toList(),
              onChanged: (v) {
                if (v != null && !v.startsWith('__cat__')) {
                  setState(() => _selectedSpecies = v);
                }
              },
            ),
            const SizedBox(height: 12),

            // Antal
            TextField(
              controller: _countCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Antal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('TILFØJ'),
                onPressed: (_selectedKreds != null && _selectedSpecies != null) ? _addEntry : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<JournalEntry> entries, ColorScheme cs) {
    // Total per species across all kredse
    final totals = <String, int>{};
    for (final e in entries) {
      totals[e.species] = (totals[e.species] ?? 0) + e.count;
    }
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: cs.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('SAMLET UDBYTTE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: cs.outline, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 12),
            ...sorted.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key, style: TextStyle(fontSize: 14, color: cs.onSurface))),
                      Text('${e.value}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPerKreds(List<JournalEntry> entries, ColorScheme cs) {
    // Group by kreds
    final byKreds = <int, List<JournalEntry>>{};
    for (final e in entries) {
      byKreds.putIfAbsent(e.kreds, () => []).add(e);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pr. kreds',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 8),
        ...byKreds.entries.map((kv) {
          final kredsInfo = djKredse.firstWhere((k) => k.number == kv.key);
          final speciesTotals = <String, int>{};
          for (final e in kv.value) {
            speciesTotals[e.species] = (speciesTotals[e.species] ?? 0) + e.count;
          }
          final sorted = speciesTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primary,
                  radius: 18,
                  child: Text('${kv.key}',
                      style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold)),
                ),
                title: Text('Kreds ${kv.key} — ${kredsInfo.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    sorted.take(3).map((e) => '${e.key}: ${e.value}').join(' · '),
                    style: TextStyle(fontSize: 12, color: cs.outline)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: sorted
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: Text(e.key,
                                            style: TextStyle(fontSize: 14, color: cs.onSurface))),
                                    Text('${e.value}',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: cs.primary)),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                                      onPressed: () => _deleteEntriesForSpeciesInKreds(
                                          kv.key, e.key, kv.value),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _deleteEntriesForSpeciesInKreds(
      int kreds, String species, List<JournalEntry> entries) async {
    final toDelete = entries.where((e) => e.species == species).toList();
    for (final e in toDelete) {
      await ref.read(journalProvider.notifier).deleteEntry(e.id);
    }
  }
}
