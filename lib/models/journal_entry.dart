class JournalEntry {
  final String id;
  final String userId;
  final int kreds;
  final String species;
  final int count;
  final DateTime createdAt;

  const JournalEntry({
    required this.id,
    required this.userId,
    required this.kreds,
    required this.species,
    required this.count,
    required this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        kreds: json['kreds'] as int,
        species: json['species'] as String,
        count: json['count'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
