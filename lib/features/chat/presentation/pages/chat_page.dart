import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:jagt_app/providers/chat_provider.dart';
import 'package:jagt_app/models/chat_message.dart';
import 'package:jagt_app/providers/auth_provider.dart';
import 'package:video_player/video_player.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;

  const ChatPage({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  int _lastMessageCount = 0;
  bool _isUploading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      await ref
          .read(chatMessagesProviderFamily(widget.channelId).notifier)
          .sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked == null) return;
    await _uploadAndSend(picked, 'image');
  }

  Future<void> _pickAndSendVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null) return;
    await _uploadAndSend(picked, 'video');
  }

  Future<void> _uploadAndSend(XFile file, String type) async {
    setState(() => _isUploading = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '$userId/${const Uuid().v4()}.$ext';
      final bytes = await file.readAsBytes();

      await client.storage.from('chat').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: type == 'image' ? 'image/$ext' : 'video/$ext',
            ),
          );

      final url = client.storage.from('chat').getPublicUrl(fileName);

      await ref
          .read(chatMessagesProviderFamily(widget.channelId).notifier)
          .sendMediaMessage(
            mediaUrl: url,
            messageType: type,
            mediaType: '$type/$ext',
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl ved upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _confirmDeleteMessage(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Slet besked'),
        content: Text(
          msg.content.isNotEmpty
              ? 'Slet "${msg.content.length > 50 ? '${msg.content.substring(0, 50)}...' : msg.content}"?'
              : 'Slet denne besked?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(chatMessagesProviderFamily(widget.channelId).notifier)
                    .deleteMessage(msg.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fejl: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Slet'),
          ),
        ],
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Vaelg billede fra galleri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Tag billede'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.orange),
              title: const Text('Vaelg video fra galleri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendVideo(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.videocam_outlined, color: Colors.red),
                title: const Text('Optag video'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendVideo(ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(chatMessagesProviderFamily(widget.channelId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isAdmin = ref.watch(userProfileProvider).value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(chatMessagesProviderFamily(widget.channelId));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fejl: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Ingen beskeder endnu. Skriv den foerste!'),
                  );
                }
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());
                }
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return GestureDetector(
                      onLongPress: isAdmin
                          ? () => _confirmDeleteMessage(msg)
                          : null,
                      child: _MessageBubble(message: msg, isMe: isMe),
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _isUploading ? null : _showAttachMenu,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Skriv en besked...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      maxLines: 5,
                      minLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (message.senderName ?? '?')[0].toUpperCase(),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: message.messageType == MessageType.text
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                  : const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.senderName != null)
                    Padding(
                      padding: message.messageType != MessageType.text
                          ? const EdgeInsets.fromLTRB(10, 6, 10, 4)
                          : EdgeInsets.zero,
                      child: Text(
                        message.senderName!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isMe
                              ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  if (message.messageType == MessageType.image &&
                      message.mediaUrl != null)
                    GestureDetector(
                      onTap: () => _showFullImage(context, message.mediaUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          message.mediaUrl!,
                          width: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 240,
                            height: 160,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child:
                                const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    ),
                  if (message.messageType == MessageType.video &&
                      message.mediaUrl != null)
                    _VideoThumbnail(
                      url: message.mediaUrl!,
                      isMe: isMe,
                    ),
                  if (message.messageType == MessageType.text ||
                      message.content.isNotEmpty)
                    Padding(
                      padding: message.messageType != MessageType.text
                          ? const EdgeInsets.fromLTRB(10, 4, 10, 0)
                          : EdgeInsets.zero,
                      child: message.messageType == MessageType.text
                          ? Text(
                              message.content,
                              style: TextStyle(
                                color:
                                    isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                              ),
                            )
                          : message.content.isNotEmpty
                              ? Text(
                                  message.content,
                                  style: TextStyle(
                                    color: isMe
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),
                  Padding(
                    padding: message.messageType != MessageType.text
                        ? const EdgeInsets.fromLTRB(10, 2, 10, 6)
                        : const EdgeInsets.only(top: 2),
                    child: Text(
                      DateFormat('HH:mm')
                          .format(message.createdAt.toLocal()),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String url;
  final bool isMe;
  const _VideoThumbnail({required this.url, required this.isMe});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _playVideo(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 240,
          height: 160,
          color: Colors.black87,
          child: const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
          ),
        ),
      ),
    );
  }

  void _playVideo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoPlayerPage(url: widget.url),
      ),
    );
  }
}

class _VideoPlayerPage extends StatefulWidget {
  final String url;
  const _VideoPlayerPage({required this.url});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.play_circle_fill,
                            color: Colors.white70, size: 64),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
