class EventCheckin {
  final String id;
  final String eventId;
  final String userId;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;

  const EventCheckin({
    required this.id,
    required this.eventId,
    required this.userId,
    this.checkedInAt,
    this.checkedOutAt,
  });

  bool get isCheckedIn => checkedInAt != null && checkedOutAt == null;

  factory EventCheckin.fromJson(Map<String, dynamic> json) => EventCheckin(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        userId: json['user_id'] as String,
        checkedInAt: json['checked_in_at'] != null
            ? DateTime.parse(json['checked_in_at'] as String)
            : null,
        checkedOutAt: json['checked_out_at'] != null
            ? DateTime.parse(json['checked_out_at'] as String)
            : null,
      );
}
