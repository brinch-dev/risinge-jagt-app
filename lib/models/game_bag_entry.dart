class GameBagEntry {
  final String id;
  final String eventId;
  final String species;
  final int count;
  final String? createdBy;
  final DateTime createdAt;

  const GameBagEntry({
    required this.id,
    required this.eventId,
    required this.species,
    required this.count,
    this.createdBy,
    required this.createdAt,
  });

  factory GameBagEntry.fromJson(Map<String, dynamic> json) {
    return GameBagEntry(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      species: json['species'] as String,
      count: json['count'] as int,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
