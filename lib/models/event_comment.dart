class EventComment {
  final String id;
  final String eventId;
  final String userId;
  final String? userName;
  final String body;
  final DateTime createdAt;

  const EventComment({
    required this.id,
    required this.eventId,
    required this.userId,
    this.userName,
    required this.body,
    required this.createdAt,
  });

  factory EventComment.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['profiles'] != null && json['profiles'] is Map) {
      name = json['profiles']['display_name'] as String? ??
          json['profiles']['full_name'] as String?;
    }
    return EventComment(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      userName: name,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
