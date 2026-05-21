enum NotificationType { broadcast, newEvent, chatMessage, chatGeneral }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String? body;
  final String targetRole;
  final String? senderId;
  final String? senderName;
  final String? referenceId;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.targetRole = 'all',
    this.senderId,
    this.senderName,
    this.referenceId,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json, {bool isRead = false}) {
    final typeStr = json['type'] as String;
    NotificationType type;
    switch (typeStr) {
      case 'broadcast':
        type = NotificationType.broadcast;
        break;
      case 'new_event':
        type = NotificationType.newEvent;
        break;
      case 'chat_message':
        type = NotificationType.chatMessage;
        break;
      case 'chat_general':
        type = NotificationType.chatGeneral;
        break;
      default:
        type = NotificationType.broadcast;
    }

    String? senderName;
    if (json['profiles'] != null && json['profiles'] is Map) {
      senderName = json['profiles']['display_name'] as String? ??
          json['profiles']['full_name'] as String?;
    }

    return AppNotification(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String,
      body: json['body'] as String?,
      targetRole: json['target_role'] as String? ?? 'all',
      senderId: json['sender_id'] as String?,
      senderName: senderName,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: isRead,
    );
  }

  String get typeLabel {
    switch (type) {
      case NotificationType.broadcast:
        return 'Broadcast';
      case NotificationType.newEvent:
        return 'Ny Event';
      case NotificationType.chatMessage:
        return 'Chatbesked';
      case NotificationType.chatGeneral:
        return 'Generel Chat';
    }
  }
}
