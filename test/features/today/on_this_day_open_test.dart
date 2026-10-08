import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/media/hatched_media_image.dart';
import 'package:field_notes/features/today/on_this_day_card.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

const String _memoryDate = '2025-07-19';
const String _photo = '7f3ac91b2d4e';
const String _caption = 'memory · 1 year ago';

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

List<Override> _memory(List<Entry> entries) => <Override>[
  onThisDayMemoryProvider.overrideWith(
    (Ref ref) async => OnThisDayMemory(
      day: todayTestDay(id: 'day-2025', date: _memoryDate, mood: Mood.warm),
      yearsAgo: 1,
    ),
  ),
  entriesForDayProvider.overrideWith(
    (Ref ref, String dayId) => Stream<List<Entry>>.value(entries),
  ),
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(entries),
  ),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => const StubMediaResolver(),
  ),
  dayDetailMediaResolverProvider.overrideWith(
    (Ref ref) async => const StubMediaResolver(),
  ),
];

final List<Entry> _notes = <Entry>[
  todayTestEntry(id: 'first', dayId: 'day-2025', textContent: 'first light'),
  todayTestEntry(
    id: 'second',
    dayId: 'day-2025',
    textContent: 'At the harbour.\n\n![Low tide](photo/$_photo)',
  ),
];

Future<void> _pumpRail(WidgetTester tester, List<Entry> entries) => pumpToday(
  tester,
  const SizedBox(width: 280, child: OnThisDayRailCard()),
  overrides: _memory(entries),
  surface: todayDesktopSurface,
);

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('clicking the memory opens that day in the day panel', (
    WidgetTester tester,
  ) async {
    await _pumpRail(tester, _notes);
    expect(find.byType(DayDetailPanel), findsNothing);

    await tester.tap(find.text('first light'));
    await tester.pumpAndSettle();

    expect(find.byType(DayDetailPanel), findsOneWidget);
    expect(
      tester.widget<DayDetailPanel>(find.byType(DayDetailPanel)).date,
      _memoryDate,
    );
    await _unmount(tester);
  }, variant: _mac);

  testWidgets('the memory is a button that opens from the keyboard', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpRail(tester, _notes);

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('first light'))),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        label: 'first light, Jul 19, 2025 · felt Warm, $_caption',
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(DayDetailPanel), findsOneWidget);
    await _unmount(tester);
    semantics.dispose();
  }, variant: _mac);

  testWidgets('the band loads the day\'s first photo', (
    WidgetTester tester,
  ) async {
    await _pumpRail(tester, _notes);

    final HatchedMediaImage band = tester.widget<HatchedMediaImage>(
      find.byType(HatchedMediaImage),
    );
    expect(band.mediaId, _photo);
    expect(band.height, 82);
    expect(find.text(_caption), findsOneWidget);
  }, variant: _mac);

  testWidgets('a memory without photos keeps the captioned hatch', (
    WidgetTester tester,
  ) async {
    await _pumpRail(tester, <Entry>[_notes.first]);

    expect(find.byType(HatchedMediaImage), findsNothing);
    expect(find.byType(CrossHatchPlaceholder), findsOneWidget);
    expect(find.text(_caption), findsOneWidget);
  }, variant: _mac);

  test('the first photo is taken from the earliest note that has one', () {
    expect(firstPhotoReference(_notes), _photo);
    expect(firstPhotoReference(<Entry>[_notes.first]), isNull);
    expect(
      firstPhotoReference(<Entry>[
        todayTestEntry(
          type: EntryType.voice,
          textContent: '![Gone](photo/aaaaaaaaaaaa)',
        ),
        ..._notes,
      ]),
      _photo,
    );
  });
}
