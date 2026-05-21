class TowerReservation {
  final String id;
  final String towerId;
  final String eventId;
  final String userId;
  final String? userName;
  final DateTime reservedAt;

  const TowerReservation({
    required this.id,
    required this.towerId,
    required this.eventId,
    required this.userId,
    this.userName,
    required this.reservedAt,
  });

  factory TowerReservation.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['profiles'] != null && json['profiles'] is Map) {
      name = json['profiles']['display_name'] as String? ??
          json['profiles']['full_name'] as String?;
    }
    return TowerReservation(
      id: json['id'] as String,
      towerId: json['tower_id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      userName: name,
      reservedAt: DateTime.parse(json['reserved_at'] as String),
    );
  }
}
