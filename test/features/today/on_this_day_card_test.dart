import 'dart:async';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/today/on_this_day_card.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

void main() {
  testWidgets(
      'renders the memory as a captioned band above a title and meta line',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      OnThisDayCard(
        memory: OnThisDayMemory(
          day: todayTestDay(id: 'day-2024', date: '2024-07-19', mood: Mood.calm),
          yearsAgo: 2,
        ),
        preview: 'sun on the deck',
      ),
    );

    expect(find.text('on this day'), findsOneWidget);
    expect(find.text('memory · 2 years ago'), findsOneWidget);
    expect(find.text('Jul 19, 2024 · felt Calm'), findsOneWidget);
    expect(find.text('sun on the deck'), findsOneWidget);
    expect(find.byType(CrossHatchPlaceholder), findsOneWidget);
    expect(find.byType(FlowerBloom), findsNothing);
  });

  testWidgets('renders an empty state when there is no memory',
      (WidgetTester tester) async {
    await pumpToday(tester, const OnThisDayCard(memory: null));

    expect(find.text('on this day'), findsOneWidget);
    expect(
      find.text('No memory from this day in past years yet.'),
      findsOneWidget,
    );
    expect(find.byType(FlowerBloom), findsNothing);
  });

  testWidgets('the connector renders the memory with its first note preview',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const OnThisDayRailCard(),
      overrides: <Override>[
        onThisDayMemoryProvider.overrideWith(
          (Ref ref) async => OnThisDayMemory(
            day: todayTestDay(id: 'day-2025', date: '2025-07-19', mood: Mood.happy),
            yearsAgo: 1,
          ),
        ),
        entriesForDayProvider.overrideWith(
          (Ref ref, String dayId) => Stream<List<Entry>>.value(<Entry>[
            todayTestEntry(dayId: dayId, textContent: 'first light'),
          ]),
        ),
      ],
    );

    expect(find.text('memory · 1 year ago'), findsOneWidget);
    expect(find.text('first light'), findsOneWidget);
  });

  testWidgets('the connector never shows the empty state while loading',
      (WidgetTester tester) async {
    final Completer<OnThisDayMemory?> pending = Completer<OnThisDayMemory?>();
    await pumpToday(
      tester,
      const OnThisDayRailCard(),
      overrides: <Override>[
        onThisDayMemoryProvider.overrideWith((Ref ref) => pending.future),
        entriesForDayProvider.overrideWith(
          (Ref ref, String dayId) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
      ],
    );

    expect(
      find.text('No memory from this day in past years yet.'),
      findsNothing,
    );
    expect(find.byType(OnThisDayCard), findsNothing);

    pending.complete(
      OnThisDayMemory(
        day: todayTestDay(id: 'day-2025', date: '2025-07-19', mood: Mood.happy),
        yearsAgo: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('memory · 1 year ago'), findsOneWidget);
  });

  testWidgets('the connector surfaces a friendly error when the lookup fails',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const OnThisDayRailCard(),
      overrides: <Override>[
        onThisDayMemoryProvider.overrideWith(
          (Ref ref) async => throw Exception('db unavailable'),
        ),
      ],
    );

    expect(
      find.text("Couldn't load your past-year memory."),
      findsOneWidget,
    );
  });
}
