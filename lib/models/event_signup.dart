enum SignupStatus { attending, notAttending }

class EventSignup {
  final String id;
  final String eventId;
  final String userId;
  final String? userName;
  final SignupStatus status;
  final DateTime signedUpAt;

  const EventSignup({
    required this.id,
    required this.eventId,
    required this.userId,
    this.userName,
    this.status = SignupStatus.attending,
    required this.signedUpAt,
  });

  factory EventSignup.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['profiles'] != null && json['profiles'] is Map) {
      name = json['profiles']['display_name'] as String? ??
          json['profiles']['full_name'] as String?;
    }
    return EventSignup(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      userName: name,
      status: json['status'] == 'not_attending'
          ? SignupStatus.notAttending
          : SignupStatus.attending,
      signedUpAt: DateTime.parse(json['signed_up_at'] as String),
    );
  }

  bool get isAttending => status == SignupStatus.attending;
  bool get isNotAttending => status == SignupStatus.notAttending;
}
