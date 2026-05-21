class HuntEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String? areaId;
  final String createdBy;
  final DateTime createdAt;
  final String? areaName;
  final bool checkinEnabled;

  const HuntEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.startTime,
    this.endTime,
    this.areaId,
    required this.createdBy,
    required this.createdAt,
    this.areaName,
    this.checkinEnabled = false,
  });

  factory HuntEvent.fromJson(Map<String, dynamic> json) {
    return HuntEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      areaId: json['area_id'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      areaName: json['hunt_areas'] != null
          ? (json['hunt_areas'] as Map<String, dynamic>)['name'] as String?
          : null,
      checkinEnabled: json['checkin_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'date': date.toIso8601String().split('T').first,
        'start_time': startTime,
        'end_time': endTime,
        'area_id': areaId,
        'created_by': createdBy,
        'checkin_enabled': checkinEnabled,
      };
}
