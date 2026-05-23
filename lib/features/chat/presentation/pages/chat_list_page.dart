import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:jagt_app/providers/chat_provider.dart';
import 'package:jagt_app/models/chat_channel.dart';
import 'package:jagt_app/features/chat/presentation/pages/chat_page.dart';
import 'package:jagt_app/features/chat/presentation/pages/create_channel_page.dart';
import 'package:jagt_app/features/notifications/presentation/widgets/notification_bell.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({Key? key}) : super(key: key);

  Future<bool> _confirmDelete(BuildContext context, ChatChannel channel) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Slet samtale'),
            content: Text('Vil du slette "${channel.name}"? Alle beskeder slettes.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuller'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Slet'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(chatChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 36),
            const SizedBox(width: 10),
            const Text('Chat'),
          ],
        ),
        actions: const [NotificationBell()],
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fejl: $e')),
        data: (channels) {
          if (channels.isEmpty) {
            return const Center(
              child: Text('Ingen chat kanaler endnu'),
            );
          }

          final general =
              channels.where((c) => c.isGeneral).toList();
          final others =
              channels.where((c) => !c.isGeneral).toList();

          return ListView(
            children: [
              if (general.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'GENEREL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...general.map((c) => _ChannelTile(channel: c)),
              ],
              if (others.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'PRIVATE & GRUPPE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...others.where((c) => !c.isPredefined).map((c) => Dismissible(
                      key: ValueKey(c.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        final confirmed = await _confirmDelete(context, c);
                        if (!confirmed) return false;
                        try {
                          await ref
                              .read(chatChannelsProvider.notifier)
                              .deleteChannel(c.id);
                          return true;
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kunne ikke slette: $e')),
                            );
                          }
                          return false;
                        }
                      },
                      child: _ChannelTile(channel: c),
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateChannelPage()),
          );
        },
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final ChatChannel channel;
  const _ChannelTile({required this.channel});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: channel.isGeneral
            ? Colors.green.shade100
            : Colors.blue.shade100,
        child: Icon(
          channel.isGeneral
              ? Icons.public
              : channel.type == ChannelType.group
                  ? Icons.group
                  : Icons.person,
          color: channel.isGeneral ? Colors.green : Colors.blue,
        ),
      ),
      title: Text(channel.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (channel.isGeneral && channel.description != null && channel.description!.isNotEmpty)
            Text(
              channel.description!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            channel.lastMessage ?? 'Ingen beskeder endnu',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: channel.lastMessageAt != null
          ? Text(
              timeago.format(channel.lastMessageAt!, locale: 'da'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              channelId: channel.id,
              channelName: channel.name,
            ),
          ),
        );
      },
    );
  }
}
