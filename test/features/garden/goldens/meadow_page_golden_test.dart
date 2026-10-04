@Tags(<String>['golden'])
library;

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/render/meadow_night_overlay.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_focus_stepper.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _meadowKey = 24601;
const int _buildFrames = 6000;
const Size _desktop = Size(1100, 960);
const Size _phone = Size(390, 844);
const Duration _referenceOffset = Duration(hours: -6);
const Key _pageKey = ValueKey<String>('meadow-page-golden');

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final DateTime _dusk = DateTime.utc(2026, 9, 29, 1);
final DateTime _midnight = DateTime.utc(2026, 9, 29, 6);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  _referenceOffset,
);

final bool _referenceZone = <DateTime>[_noon, _dusk, _midnight].every(
  (DateTime instant) => instant.toLocal().timeZoneOffset == _referenceOffset,
);

String _dateOf(int year, int index) =>
    captureDateKey(DateTime(year, 1, 1 + index));

List<int> _journaledIn(int through, int stride) => <int>[
  for (int index = 0; index < through; index++)
    if ((index * stride) % 10 < 7) index,
];

final List<int> _thisYear = _journaledIn(272, 7);
final List<int> _lastYear = _journaledIn(365, 3);

final List<Day> _days = <Day>[
  for (final int index in _thisYear)
    if (index % 13 != 5)
      dayOf(
        _dateOf(2026, index),
        mood: moodOrder[(index * 3 + index ~/ 11) % moodOrder.length],
      ),
  for (final int index in _lastYear)
    if (index % 17 != 3)
      dayOf(
        _dateOf(2025, index),
        mood: moodOrder[(index * 7 + index ~/ 29) % moodOrder.length],
      ),
];

final Map<String, int> _counts = <String, int>{
  for (final int index in _thisYear)
    _dateOf(2026, index): index % 5 == 0 ? 3 : 1,
  for (final int index in _lastYear)
    _dateOf(2025, index): index % 6 == 0 ? 3 : 1,
};

typedef _Reference = ({
  String name,
  Size size,
  TargetPlatform platform,
  Brightness brightness,
  DateTime instant,
  int? studyYear,
  String? focusMonth,
});

final List<_Reference> _references = <_Reference>[
  (
    name: 'meadow_page_desktop_noon_light',
    size: _desktop,
    platform: TargetPlatform.macOS,
    brightness: Brightness.light,
    instant: _noon,
    studyYear: null,
    focusMonth: null,
  ),
  (
    name: 'meadow_page_desktop_noon_dark',
    size: _desktop,
    platform: TargetPlatform.macOS,
    brightness: Brightness.dark,
    instant: _noon,
    studyYear: null,
    focusMonth: null,
  ),
  (
    name: 'meadow_page_desktop_midnight_dark',
    size: _desktop,
    platform: TargetPlatform.macOS,
    brightness: Brightness.dark,
    instant: _midnight,
    studyYear: null,
    focusMonth: null,
  ),
  (
    name: 'meadow_page_phone_noon_light',
    size: _phone,
    platform: TargetPlatform.android,
    brightness: Brightness.light,
    instant: _noon,
    studyYear: null,
    focusMonth: null,
  ),
  (
    name: 'meadow_page_phone_midnight_dark',
    size: _phone,
    platform: TargetPlatform.android,
    brightness: Brightness.dark,
    instant: _midnight,
    studyYear: null,
    focusMonth: null,
  ),
  (
    name: 'meadow_study_desktop_dusk_light',
    size: _desktop,
    platform: TargetPlatform.macOS,
    brightness: Brightness.light,
    instant: _dusk,
    studyYear: 2025,
    focusMonth: null,
  ),
  (
    name: 'meadow_focus_phone_noon_light',
    size: _phone,
    platform: TargetPlatform.android,
    brightness: Brightness.light,
    instant: _noon,
    studyYear: null,
    focusMonth: 'Feb',
  ),
];

Future<void> _pumpReference(WidgetTester tester, _Reference reference) async {
  tester.view.physicalSize = reference.size;
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey<String>(reference.name),
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(_days),
        ),
        journalEntryCountsProvider.overrideWith(
          (Ref ref) => Stream<Map<String, int>>.value(_counts),
        ),
        meadowKeyProvider.overrideWith((Ref ref) async => _meadowKey),
        skyClockProvider.overrideWithValue(() => reference.instant),
        skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: reference.platform,
          brightness: reference.brightness,
        ),
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const RepaintBoundary(
              key: _pageKey,
              child: Scaffold(body: GardenScreen()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  final int? studyYear = reference.studyYear;
  if (studyYear != null) {
    ProviderScope.containerOf(tester.element(find.byType(GardenScreen)))
        .read(meadowViewStateProvider.notifier)
        .openYear(studyYear, currentYear: reference.instant.toLocal().year);
    await tester.pump();
  }
  final MeadowStageState stage = tester.state<MeadowStageState>(
    find.byType(MeadowStage),
  );
  for (int i = 0; i < _buildFrames && !stage.debugIsReady; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
  }
  expect(stage.debugIsReady, isTrue, reason: '${reference.name} never grew');
  await tester.pumpAndSettle();
  final String? month = reference.focusMonth;
  if (month != null) {
    await tester.tap(find.byKey(meadowDetailsButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(month));
    await tester.pumpAndSettle();
    expect(find.byKey(meadowFocusStepperKey), findsOneWidget);
    expect(find.text('February'), findsOneWidget);
  }
}

void main() {
  testWidgets('the full-bleed meadow pages match their goldens', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadMeadowNightOverlay);

    for (final _Reference reference in _references) {
      await _pumpReference(tester, reference);
      await expectLater(
        find.byKey(_pageKey),
        matchesGoldenFile('${reference.name}.png'),
      );
    }
  }, skip: !_referenceZone);
}
