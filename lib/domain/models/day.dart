import '../mood/mood.dart';

class Day {
  const Day({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
    this.deletedAt,
  });

  final String id;
  final String date;
  final Mood? mood;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Day &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          mood == other.mood &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hash(
        id,
        date,
        mood,
        createdAt,
        updatedAt,
        deletedAt,
      );

  @override
  String toString() =>
      'Day(id: $id, date: $date, mood: $mood, createdAt: $createdAt, '
      'updatedAt: $updatedAt, deletedAt: $deletedAt)';
}
