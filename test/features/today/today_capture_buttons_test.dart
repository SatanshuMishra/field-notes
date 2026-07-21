import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/today/today_capture_buttons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

CaptureRouteRegistry _registry({
  required List<String> openedDates,
  bool throwOnOpen = false,
}) {
  return CaptureRouteRegistry.empty.withRoute(
    CaptureRoute(
      type: EntryType.text,
      open: (BuildContext context, String date) async {
        if (throwOnOpen) {
          throw Exception('composer unavailable');
        }
        openedDates.add(date);
        return 'entry-42';
      },
    ),
  );
}

void main() {
  testWidgets('the primary button opens the chooser and runs the chosen route',
      (WidgetTester tester) async {
    final List<String> openedDates = <String>[];
    await pumpToday(
      tester,
      const TodayCaptureButtons(date: '2026-07-19'),
      overrides: <Override>[
        captureRoutesProvider
            .overrideWithValue(_registry(openedDates: openedDates)),
      ],
    );

    expect(find.text('Quick capture'), findsOneWidget);

    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    expect(find.text('Capture a moment'), findsOneWidget);

    await tester.tap(find.text('Write a note').last);
    await tester.pumpAndSettle();

    expect(openedDates, <String>['2026-07-19']);
  });

  testWidgets('renders a direct button only for registered capture types',
      (WidgetTester tester) async {
    final List<String> openedDates = <String>[];
    await pumpToday(
      tester,
      const TodayCaptureButtons(date: '2026-07-19'),
      overrides: <Override>[
        captureRoutesProvider
            .overrideWithValue(_registry(openedDates: openedDates)),
      ],
    );

    expect(find.text('Write a note'), findsOneWidget);
    expect(find.text('Record voice'), findsNothing);
    expect(find.text('Record video'), findsNothing);

    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();

    expect(openedDates, <String>['2026-07-19']);
  });

  testWidgets('surfaces a friendly error when opening capture fails',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayCaptureButtons(date: '2026-07-19'),
      overrides: <Override>[
        captureRoutesProvider.overrideWithValue(
          _registry(openedDates: <String>[], throwOnOpen: true),
        ),
      ],
    );

    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't open capture. Please try again."),
      findsOneWidget,
    );
    expect(find.text('Write a note'), findsOneWidget);
  });
}
