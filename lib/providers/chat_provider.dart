import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';
import 'package:jagt_app/models/chat_channel.dart';
import 'package:jagt_app/models/chat_message.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/providers/auth_provider.dart';

final chatChannelsProvider =
    AsyncNotifierProvider<ChatChannelsNotifier, List<ChatChannel>>(
  ChatChannelsNotifier.new,
);

class ChatChannelsNotifier extends AsyncNotifier<List<ChatChannel>> {
  RealtimeChannel? _membersChannel;
  RealtimeChannel? _channelsChannel;
  Timer? _pollTimer;

  @override
  Future<List<ChatChannel>> build() async {
    ref.onDispose(() {
      _membersChannel?.unsubscribe();
      _channelsChannel?.unsubscribe();
      _pollTimer?.cancel();
    });
    ref.watch(userProfileProvider);
    _subscribeToChanges();
    _startPolling();
    return _fetch();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        state = AsyncData(await _fetch());
      } catch (_) {}
    });
  }

  void _subscribeToChanges() {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;

    _membersChannel = client
        .channel('my-channel-members')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'channel_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .subscribe();

    _channelsChannel = client
        .channel('chat-channels-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_channels',
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .subscribe();
  }

  Future<List<ChatChannel>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;

    // Hent rolle ALTID direkte fra DB for at sikre korrekt filtrering
    final profileData = await client.from('profiles').select('role').eq('id', userId).single();
    final userRole = profileData['role'] as String;

    final generalChannels = await client
        .from('chat_channels')
        .select()
        .eq('type', 'general')
        .order('sort_order', ascending: true);

    final memberChannelIds = await client
        .from('channel_members')
        .select('channel_id')
        .eq('user_id', userId);

    final ids = (memberChannelIds as List)
        .map((e) => e['channel_id'] as String)
        .toList();

    List<dynamic> privateChannels = [];
    if (ids.isNotEmpty) {
      privateChannels = await client
          .from('chat_channels')
          .select()
          .inFilter('id', ids)
          .neq('type', 'general')
          .order('last_message_at', ascending: false);
    }

    final parsed = (generalChannels as List).map((e) => ChatChannel.fromJson(e)).toList();
    final visible = parsed.where((c) => c.isVisibleToRole(userRole)).toList();
    final all = [
      ...visible,
      ...(privateChannels).map((e) => ChatChannel.fromJson(e)),
    ];
    return all;
  }

  Future<ChatChannel> createChannel(
      String name, ChannelType type, List<String> memberIds) async {
    final client = ref.read(supabaseProvider);

    final channelId = await client.rpc('create_channel_with_members', params: {
      'p_name': name,
      'p_type': type.name,
      'p_member_ids': memberIds,
    });

    final data = await client
        .from('chat_channels')
        .select()
        .eq('id', channelId as String)
        .single();

    state = AsyncData(await _fetch());
    return ChatChannel.fromJson(data);
  }

  Future<void> deleteChannel(String channelId) async {
    final client = ref.read(supabaseProvider);
    await client.from('chat_messages').delete().eq('channel_id', channelId);
    await client.from('channel_members').delete().eq('channel_id', channelId);
    await client.from('chat_channels').delete().eq('id', channelId);
    state = AsyncData(await _fetch());
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }
}

class ChatMessagesNotifier extends AsyncNotifier<List<ChatMessage>> {
  late final String channelId;
  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;

  ChatMessagesNotifier(this.channelId);

  @override
  Future<List<ChatMessage>> build() async {
    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
      _pollTimer?.cancel();
    });
    _subscribeToMessages();
    _startPolling();
    return _loadMessages();
  }

  Future<List<ChatMessage>> _loadMessages() async {
    final client = ref.read(supabaseProvider);
    final data = await client
        .from('chat_messages')
        .select('*, profiles(display_name)')
        .eq('channel_id', channelId)
        .order('created_at', ascending: true)
        .limit(100);
    return (data as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  void _subscribeToMessages() {
    final client = ref.read(supabaseProvider);
    _realtimeChannel = client
        .channel('messages:$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) async {
            state = AsyncData(await _loadMessages());
          },
        )
        .subscribe();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final fresh = await _loadMessages();
        final current = state.value ?? [];
        final freshLastId = fresh.isNotEmpty ? fresh.last.id : '';
        final currentLastId = current.isNotEmpty ? current.last.id : '';
        if (fresh.length != current.length || freshLastId != currentLastId) {
          state = AsyncData(fresh);
        }
      } catch (_) {}
    });
  }

  Future<void> refresh() async {
    state = AsyncData(await _loadMessages());
  }

  Future<void> sendMessage(String content) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;
    await client.from('chat_messages').insert({
      'channel_id': channelId,
      'sender_id': userId,
      'content': content,
      'message_type': 'text',
    });
    await client.from('chat_channels').update({
      'last_message': content,
      'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', channelId);
    state = AsyncData(await _loadMessages());
  }

  Future<void> deleteMessage(String messageId) async {
    final client = ref.read(supabaseProvider);
    await client.from('chat_messages').delete().eq('id', messageId);
    state = AsyncData(await _loadMessages());
  }

  Future<void> sendMediaMessage({
    required String mediaUrl,
    required String messageType,
    String? mediaType,
    String caption = '',
  }) async {
    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser!.id;
    await client.from('chat_messages').insert({
      'channel_id': channelId,
      'sender_id': userId,
      'content': caption,
      'message_type': messageType,
      'media_url': mediaUrl,
      'media_type': mediaType,
    });
    final label = messageType == 'image' ? 'Billede' : 'Video';
    await client.from('chat_channels').update({
      'last_message': caption.isNotEmpty ? caption : label,
      'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', channelId);
  }
}

final chatMessagesProviderFamily =
    AsyncNotifierProvider.family<ChatMessagesNotifier, List<ChatMessage>,
        String>(
  (channelId) => ChatMessagesNotifier(channelId),
);

final allMembersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseProvider);
  final data = await client
      .from('profiles')
      .select('id, display_name, email, role')
      .neq('role', 'gaest')
      .order('display_name');
  return List<Map<String, dynamic>>.from(data);
});
