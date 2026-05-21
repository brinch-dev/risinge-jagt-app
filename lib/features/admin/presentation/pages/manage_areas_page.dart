import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/providers/map_provider.dart';
import 'package:jagt_app/providers/area_boundary_provider.dart';
import 'package:jagt_app/models/hunt_area.dart';
import 'package:jagt_app/features/admin/presentation/pages/create_area_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/edit_area_page.dart';
import 'package:jagt_app/features/admin/presentation/pages/manage_towers_page.dart';

class ManageAreasPage extends ConsumerWidget {
  const ManageAreasPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(huntAreasProvider);
    final boundsAsync = ref.watch(areaBoundariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jagtområder'),
      ),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (areas) {
          if (areas.isEmpty) {
            return const Center(
              child: Text('Ingen jagtområder oprettet endnu'),
            );
          }
          final bounds = boundsAsync.value ?? {};
          return ListView.builder(
            itemCount: areas.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final area = areas[index];
              final pointCount = bounds[area.id]?.length ?? 0;
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map, color: Colors.green),
                      title: Text(area.name),
                      subtitle: Text(
                        'Polygon: $pointCount punkter\n'
                        'Alarm margin: ${area.alarmMarginMeters.round()}m',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditAreaPage(area: area),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, ref, area),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 8),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ManageTowersPage(area: area),
                              ),
                            ),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('Poster'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateAreaPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, HuntArea area) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet område'),
        content: Text('Er du sikker på at du vil slette "${area.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(huntAreasProvider.notifier).deleteArea(area.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }
}
