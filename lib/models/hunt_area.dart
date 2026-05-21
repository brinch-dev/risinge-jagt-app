import 'package:latlong2/latlong.dart';

class HuntArea {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final String? description;
  final String alarmText;
  final double alarmMarginMeters;
  final String createdBy;
  final DateTime createdAt;

  const HuntArea({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    this.description,
    this.alarmText = 'Advarsel: Du nærmer dig jagtområdets grænse! Vend om.',
    this.alarmMarginMeters = 100,
    required this.createdBy,
    required this.createdAt,
  });

  LatLng get center => LatLng(centerLat, centerLng);

  factory HuntArea.fromJson(Map<String, dynamic> json) {
    return HuntArea(
      id: json['id'] as String,
      name: json['name'] as String,
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLng: (json['center_lng'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      description: json['description'] as String?,
      alarmText: json['alarm_text'] as String? ??
          'Advarsel: Du nærmer dig jagtområdets grænse! Vend om.',
      alarmMarginMeters:
          (json['alarm_margin_meters'] as num?)?.toDouble() ?? 100,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'center_lat': centerLat,
        'center_lng': centerLng,
        'radius_meters': radiusMeters,
        'description': description,
        'alarm_text': alarmText,
        'alarm_margin_meters': alarmMarginMeters,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}
