import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/settings_harness.dart';

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 900);
const double _statusBar = 34;
const double _gestureBar = 24;

final Finder _sheet = find.byType(PhoneSheet);

Finder _inSheet(String label) =>
    find.descendant(of: _sheet, matching: find.text(label));

void _useSurface(WidgetTester tester, TargetPlatform platform) {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phone : _desktop;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
  } else {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
  }
  addTearDown(tester.view.reset);
}

Future<void> _pumpJournal(
  WidgetTester tester,
  TargetPlatform platform,
  FakeSettingsRepository repository,
) async {
  debugDefaultTargetPlatformOverride = platform;
  _useSurface(tester, platform);
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: settingsFeatureHarness(
        JournalSection(
          settings: AppSettings.defaults.copyWith(weekStart: WeekStart.monday),
          onFeedback: (String message) {},
        ),
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a phone select opens the shared sheet and saves the pick', (
    WidgetTester tester,
  ) async {
    try {
      final FakeSettingsRepository phoneRepository = FakeSettingsRepository();
      await _pumpJournal(tester, TargetPlatform.android, phoneRepository);

      expect(find.byType(PopupMenuButton<WeekStart>), findsNothing);
      await tester.tap(find.byType(SettingsSelect<WeekStart>));
      await tester.pumpAndSettle();

      expect(_sheet, findsOneWidget);
      expect(find.byKey(phoneSheetGrabberKey), findsOneWidget);
      expect(find.byType(PopupMenuItem<WeekStart>), findsNothing);
      for (final String day in <String>['Monday', 'Sunday', 'Saturday']) {
        expect(_inSheet(day), findsOneWidget);
        final SemanticsNode row = tester.getSemantics(_inSheet(day));
        expect(row.rect.height, greaterThanOrEqualTo(48));
        expect(
          row,
          isSemantics(label: day, isButton: true, isSelected: day == 'Monday'),
        );
        final TextStyle style = tester.widget<Text>(_inSheet(day)).style!;
        expect(style.fontSize, 16);
        expect(style.fontFamily, TypographyTokens.sans);
      }
      final Rect monday = tester.getRect(_inSheet('Monday'));
      final Rect sunday = tester.getRect(_inSheet('Sunday'));
      final Rect saturday = tester.getRect(_inSheet('Saturday'));
      expect(monday.top, greaterThanOrEqualTo(sunday.bottom));
      expect(saturday.top, greaterThanOrEqualTo(monday.bottom));

      await tester.tap(_inSheet('Sunday'));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(phoneRepository.weekStartWrites, <WeekStart>[WeekStart.sunday]);

      final FakeSettingsRepository desktopRepository = FakeSettingsRepository();
      await _pumpJournal(tester, TargetPlatform.macOS, desktopRepository);

      expect(find.byType(PopupMenuButton<WeekStart>), findsOneWidget);
      await tester.tap(find.byType(SettingsSelect<WeekStart>));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(find.byType(PopupMenuItem<WeekStart>), findsNWidgets(3));

      await tester.tap(find.widgetWithText(PopupMenuItem<WeekStart>, 'Sunday'));
      await tester.pumpAndSettle();

      expect(desktopRepository.weekStartWrites, <WeekStart>[WeekStart.sunday]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
