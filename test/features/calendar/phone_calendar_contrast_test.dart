import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/month_year_sheet.dart';
import 'package:field_notes/features/calendar/widgets/phone_flower_month.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;

Future<void> _pumpAugust(WidgetTester tester) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        weekStartProvider.overrideWithValue(WeekStart.sunday),
        journaledDatesProvider.overrideWith(
          (Ref ref) => Stream<List<String>>.value(const <String>[]),
        ),
        daysInMonthProvider.overrideWith(
          (Ref ref, ({int year, int month}) args) =>
              Stream<List<Day>>.value(const <Day>[]),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: Scaffold(
          body: CalendarScreen(
            initialMonth: const MonthRef(2026, 8),
            today: DateTime(2026, 7, 15),
            onOpenDay: (BuildContext context, {required String date}) async {},
            onOpenToday: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the phone calendar labels meet text contrast in the light theme',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpAugust(tester);

      expect(find.byKey(phoneThisMonthKey), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(find.byKey(phoneMonthPickerButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(MonthYearBackButton), findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    },
  );
}
