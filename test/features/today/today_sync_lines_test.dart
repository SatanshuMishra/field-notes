import 'dart:async';

import 'package:field_notes/data/sync/engine/sync_engine.dart'
    show FirstPullProgress;
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sync_overrides.dart';
import 'support/today_harness.dart';

const String _attention = "Needs attention · can't reach your server";
const String _fix = "Your changes are safe here and will go up when it's back.";

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.android},
);

bool get _onAndroid => defaultTargetPlatform == TargetPlatform.android;

CaptureRouteRegistry _allCaptureRoutes() => captureOptions.fold(
  CaptureRouteRegistry.empty,
  (CaptureRouteRegistry registry, CaptureOption option) => registry.withRoute(
    CaptureRoute(
      type: option.type,
      open: (BuildContext context, String date) async => null,
    ),
  ),
);

List<Override> _todayOverrides() => <Override>[
  captureRoutesProvider.overrideWithValue(_allCaptureRoutes()),
  todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 20)),
  weekStartProvider.overrideWithValue(WeekStart.sunday),
  allDaysProvider.overrideWith(
    (Ref ref) => Stream<List<Day>>.value(<Day>[
      todayTestDay(date: '2026-07-19', mood: Mood.calm),
    ]),
  ),
  dayForDateProvider.overrideWith(
    (Ref ref, String date) =>
        Stream<Day?>.value(todayTestDay(date: date, mood: Mood.calm)),
  ),
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[
      todayTestEntry(textContent: 'morning walk'),
    ]),
  ),
  entriesForDayProvider.overrideWith(
    (Ref ref, String dayId) => Stream<List<Entry>>.value(const <Entry>[]),
  ),
  photosForEntryProvider.overrideWith(
    (Ref ref, String entryId) =>
        Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
  ),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => const StubMediaResolver(),
  ),
  onThisDayMemoryProvider.overrideWith(
    (Ref ref) async => OnThisDayMemory(
      day: todayTestDay(id: 'day-2025', date: '2025-07-19', mood: Mood.happy),
      yearsAgo: 1,
    ),
  ),
];

Future<void> _pumpToday(WidgetTester tester, List<Override> sync) async {
  await pumpToday(
    tester,
    const TodayScreen(),
    overrides: <Override>[..._todayOverrides(), ...sync],
    surface: _onAndroid ? todayPhoneSurface : todayDesktopSurface,
  );
}

void main() {
  testWidgets('Today shows the needs-attention line on Android', (
    WidgetTester tester,
  ) async {
    await _pumpToday(
      tester,
      syncOnOverrides(
        status: const AttentionStatus(AttentionReason.unreachable),
      ),
    );

    expect(find.text(_attention), _onAndroid ? findsOneWidget : findsNothing);
    expect(find.text(_fix), _onAndroid ? findsOneWidget : findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pumpToday(
      tester,
      syncOnOverrides(status: SyncedStatus(DateTime.now().toUtc())),
    );

    expect(find.textContaining('Needs attention'), findsNothing);
    expect(find.textContaining('Synced'), findsNothing);
    expect(find.text(_fix), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pumpToday(tester, syncOffOverrides());

    expect(find.textContaining('Needs attention'), findsNothing);
  }, variant: _bothPlatforms);

  testWidgets('Today shows first-pull progress until the pull completes', (
    WidgetTester tester,
  ) async {
    final StreamController<FirstPullProgress?> progress =
        StreamController<FirstPullProgress?>();
    addTearDown(progress.close);
    await _pumpToday(
      tester,
      syncOnOverrides(
        status: const WaitingStatus(3),
        progress: progress.stream,
      ),
    );

    expect(find.textContaining('Bringing your journal over'), findsNothing);

    progress.add(const FirstPullProgress(done: 2, total: 5));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bringing your journal over · 2 of 5'), findsOneWidget);

    progress.add(const FirstPullProgress(done: 4, total: 5));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bringing your journal over · 2 of 5'), findsNothing);
    expect(find.text('Bringing your journal over · 4 of 5'), findsOneWidget);

    progress.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Bringing your journal over'), findsNothing);
  }, variant: _bothPlatforms);
}
