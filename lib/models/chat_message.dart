enum MessageType {
  text,
  image,
  video;

  static MessageType fromDb(String? value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      default:
        return MessageType.text;
    }
  }
}

class ChatMessage {
  final String id;
  final String channelId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? senderName;
  final MessageType messageType;
  final String? mediaUrl;
  final String? mediaType;

  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.mediaType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['display_name']
              as String?
          : null,
      messageType: MessageType.fromDb(json['message_type'] as String?),
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'channel_id': channelId,
        'sender_id': senderId,
        'content': content,
        'message_type': messageType.name,
        'media_url': mediaUrl,
        'media_type': mediaType,
      };
}
