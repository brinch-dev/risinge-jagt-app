import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jagt_app/bootstrap.dart';

class HomeBlock {
  final String id;
  final String blockType;
  final String? title;
  final String? content;
  final String? imageUrl;
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final List<String> visibleRoles;

  const HomeBlock({
    required this.id,
    required this.blockType,
    this.title,
    this.content,
    this.imageUrl,
    this.icon,
    required this.sortOrder,
    this.isActive = true,
    this.visibleRoles = const [],
  });

  factory HomeBlock.fromJson(Map<String, dynamic> json) {
    return HomeBlock(
      id: json['id'] as String,
      blockType: json['block_type'] as String,
      title: json['title'] as String?,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      visibleRoles: json['visible_roles'] != null
          ? List<String>.from(json['visible_roles'] as List)
          : const [],
    );
  }

  bool isVisibleToRole(String roleDbValue) {
    if (visibleRoles.isEmpty) return true;
    return visibleRoles.contains(roleDbValue);
  }
}

class HomeBlocksNotifier extends AsyncNotifier<List<HomeBlock>> {
  @override
  Future<List<HomeBlock>> build() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('homepage_blocks')
        .select()
        .order('sort_order', ascending: true);
    return (data as List).map((e) => HomeBlock.fromJson(e)).toList();
  }

  Future<void> createBlock({
    required String blockType,
    String? title,
    String? content,
    String? imageUrl,
    String? icon,
    List<String> visibleRoles = const [],
  }) async {
    final client = ref.read(supabaseProvider);
    final current = state.value ?? [];
    final maxSort = current.isEmpty
        ? 0
        : current.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b);
    await client.from('homepage_blocks').insert({
      'block_type': blockType,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'icon': icon,
      'sort_order': maxSort + 1,
      'visible_roles': visibleRoles,
    });
    ref.invalidateSelf();
  }

  Future<void> updateBlock(String id, Map<String, dynamic> updates) async {
    final client = ref.read(supabaseProvider);
    updates['updated_at'] = DateTime.now().toIso8601String();
    await client.from('homepage_blocks').update(updates).eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteBlock(String id) async {
    final client = ref.read(supabaseProvider);
    await client.from('homepage_blocks').delete().eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> reorderByIndex(int oldIndex, int newIndex) async {
    final blocks = List<HomeBlock>.from(state.value ?? []);
    if (oldIndex < 0 || oldIndex >= blocks.length) return;
    if (newIndex < 0 || newIndex >= blocks.length) return;

    final block = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, block);

    final client = ref.read(supabaseProvider);
    for (int i = 0; i < blocks.length; i++) {
      await client
          .from('homepage_blocks')
          .update({'sort_order': i}).eq('id', blocks[i].id);
    }
    ref.invalidateSelf();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final client = ref.read(supabaseProvider);
    await client
        .from('homepage_blocks')
        .update({'is_active': isActive}).eq('id', id);
    ref.invalidateSelf();
  }
}

final homeBlocksProvider =
    AsyncNotifierProvider<HomeBlocksNotifier, List<HomeBlock>>(
        HomeBlocksNotifier.new);
