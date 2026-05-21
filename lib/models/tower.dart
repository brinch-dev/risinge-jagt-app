enum TowerType {
  jagttaarn,
  skydestige,
  skudlinje;

  String get label {
    switch (this) {
      case TowerType.jagttaarn:
        return 'Jagttårn';
      case TowerType.skydestige:
        return 'Skydestige';
      case TowerType.skudlinje:
        return 'Hul / Skudlinje';
    }
  }

  String get dbValue => name;

  static TowerType fromDb(String? value) {
    switch (value) {
      case 'skydestige':
        return TowerType.skydestige;
      case 'skudlinje':
        return TowerType.skudlinje;
      default:
        return TowerType.jagttaarn;
    }
  }
}

class Tower {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? areaId;
  final String? description;
  final TowerType towerType;
  final DateTime createdAt;
  final List<String> imageUrls;

  const Tower({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.areaId,
    this.description,
    this.towerType = TowerType.jagttaarn,
    required this.createdAt,
    this.imageUrls = const [],
  });

  factory Tower.fromJson(Map<String, dynamic> json) {
    return Tower(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      areaId: json['area_id'] as String?,
      description: json['description'] as String?,
      towerType: TowerType.fromDb(json['tower_type'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      imageUrls: json['image_urls'] != null
          ? List<String>.from(json['image_urls'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'area_id': areaId,
        'description': description,
        'tower_type': towerType.dbValue,
        'created_at': createdAt.toIso8601String(),
        'image_urls': imageUrls,
      };
}
