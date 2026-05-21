class AdminLogEntry {
  final String id;
  final String type;
  final String message;
  final String? userId;
  final String? userName;
  final String? referenceId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AdminLogEntry({
    required this.id,
    required this.type,
    required this.message,
    this.userId,
    this.userName,
    this.referenceId,
    this.metadata,
    required this.createdAt,
  });

  factory AdminLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminLogEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      message: json['message'] as String,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      referenceId: json['reference_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'new_user':
        return 'Ny bruger';
      case 'event_signup':
        return 'Tilmelding';
      case 'event_unsignup':
        return 'Afmelding';
      case 'geofence_warning':
        return 'Grænse-advarsel';
      case 'geofence_outside':
        return 'Uden for område';
      case 'reservation':
        return 'Reservation';
      case 'reservation_cancel':
        return 'Reservation annulleret';
      case 'event_created':
        return 'Event oprettet';
      case 'area_created':
        return 'Omraade oprettet';
      case 'broadcast':
        return 'Broadcast';
      case 'role_change':
        return 'Rolle ændret';
      default:
        return type;
    }
  }
}
