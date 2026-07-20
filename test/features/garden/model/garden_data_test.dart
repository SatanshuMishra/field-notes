import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:flutter_test/flutter_test.dart';

Day _day(String date, {Mood? mood, int? deletedAt}) => Day(
      id: 'id-$date',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
      deletedAt: deletedAt,
    );

void main() {
  group('gardenBloomsForYear', () {
    test('keeps only mood-bearing, non-deleted days in the target year', () {
      final List<Day> days = <Day>[
        _day('2026-03-02', mood: Mood.happy),
        _day('2026-01-15'),
        _day('2025-12-31', mood: Mood.calm),
        _day('2026-08-09', mood: Mood.sad, deletedAt: 5),
        _day('2026-07-14', mood: Mood.love),
      ];

      final List<GardenBloomData> blooms = gardenBloomsForYear(days, 2026);

      expect(
        blooms.map((GardenBloomData b) => b.date),
        <String>['2026-03-02', '2026-07-14'],
      );
      expect(
        blooms.map((GardenBloomData b) => b.mood),
        <Mood>[Mood.happy, Mood.love],
      );
    });

    test('does not mutate the caller list and tolerates malformed dates', () {
      final List<Day> days = <Day>[
        _day('bad', mood: Mood.warm),
        _day('26', mood: Mood.warm),
        _day('2026-05-05', mood: Mood.warm),
      ];
      final List<Day> before = List<Day>.of(days);

      final List<GardenBloomData> blooms = gardenBloomsForYear(days, 2026);

      expect(blooms.single.date, '2026-05-05');
      expect(days, before);
    });
  });

  group('moodTally', () {
    test('counts per mood in moodOrder, omitting zeros', () {
      final List<Day> days = <Day>[
        _day('2026-01-01', mood: Mood.happy),
        _day('2026-01-02', mood: Mood.love),
        _day('2026-01-03', mood: Mood.happy),
        _day('2026-01-04', mood: Mood.love),
        _day('2026-01-05', mood: Mood.love),
        _day('2025-01-05', mood: Mood.sad),
        _day('2026-01-06', mood: Mood.sad, deletedAt: 1),
      ];

      final List<MoodTallyEntry> tally = moodTally(days, 2026);

      expect(tally, <MoodTallyEntry>[
        const MoodTallyEntry(mood: Mood.happy, count: 2),
        const MoodTallyEntry(mood: Mood.love, count: 3),
      ]);
    });
  });
}
