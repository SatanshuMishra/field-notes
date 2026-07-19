import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_banner_for_date.dart';
import 'package:field_notes/state/state.dart';

import 'support/mood_harness.dart';

void main() {
  testWidgets('writes the chosen mood for the date and shows it',
      (WidgetTester tester) async {
    final FakeJournalRepository fake =
        FakeJournalRepository(initialDay: testDay(mood: null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(fake),
        ],
        child: moodHarness(const MoodBannerForDate(date: '2026-07-19')),
      ),
    );
    await tester.pump();

    expect(find.text('How are you feeling today?'), findsOneWidget);

    await tester.tap(find.text('How are you feeling today?'));
    await tester.pumpAndSettle();
    expect(find.text('How are you feeling?'), findsOneWidget);

    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(fake.moodWrites, <({String date, Mood? mood})>[
      (date: '2026-07-19', mood: Mood.calm),
    ]);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Change mood'), findsOneWidget);
  });

  testWidgets('surfaces a non-destructive error when the write fails',
      (WidgetTester tester) async {
    final FakeJournalRepository fake =
        FakeJournalRepository(initialDay: testDay(mood: null))
          ..setMoodError = Exception('disk full');
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(fake),
        ],
        child: moodHarness(const MoodBannerForDate(date: '2026-07-19')),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('How are you feeling today?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(fake.moodWrites, isEmpty);
    expect(
      find.text("Couldn't save your mood. Please try again."),
      findsOneWidget,
    );
    expect(find.text('How are you feeling today?'), findsOneWidget);
  });
}
