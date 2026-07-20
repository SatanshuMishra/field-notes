import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/chooser/capture_routes_provider.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test_support.dart';

class _Trigger extends StatelessWidget {
  const _Trigger({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: const Text('open'),
    );
  }
}

class _OpenCapture extends ConsumerWidget {
  const _OpenCapture({required this.date, required this.onResult});

  final String date;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Trigger(
      onPressed: () async {
        onResult(await openCapture(context, ref, date: date));
      },
    );
  }
}

void main() {
  testWidgets('the sheet lists every capture option under the spec title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      captureHarness(
        CaptureChooserSheet(
          availableTypes: const <EntryType>{EntryType.text},
          onOptionSelected: (EntryType _) {},
        ),
      ),
    );

    expect(find.text('Capture a moment'), findsOneWidget);
    expect(find.text('Write a note'), findsOneWidget);
    expect(find.text('Record voice'), findsOneWidget);
    expect(find.text('Record video'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(2));
  });

  testWidgets('an unavailable option cannot be selected',
      (WidgetTester tester) async {
    final List<EntryType> selected = <EntryType>[];

    await tester.pumpWidget(
      captureHarness(
        CaptureChooserSheet(
          availableTypes: const <EntryType>{EntryType.text},
          onOptionSelected: selected.add,
        ),
      ),
    );

    await tester.tap(find.text('Record voice'));
    await tester.pump();
    expect(selected, isEmpty);

    await tester.tap(find.text('Write a note'));
    await tester.pump();
    expect(selected, <EntryType>[EntryType.text]);
  });

  testWidgets('showCaptureChooser returns the chosen type',
      (WidgetTester tester) async {
    EntryType? chosen;

    await tester.pumpWidget(
      captureHarness(
        Builder(
          builder: (BuildContext context) {
            return _Trigger(
              onPressed: () async {
                chosen = await showCaptureChooser(
                  context,
                  availableTypes: const <EntryType>{EntryType.text},
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();

    expect(chosen, EntryType.text);
  });

  testWidgets('showCaptureChooser returns null when the barrier is tapped',
      (WidgetTester tester) async {
    EntryType? chosen = EntryType.video;

    await tester.pumpWidget(
      captureHarness(
        Builder(
          builder: (BuildContext context) {
            return _Trigger(
              onPressed: () async {
                chosen = await showCaptureChooser(
                  context,
                  availableTypes: const <EntryType>{EntryType.text},
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(chosen, isNull);
  });

  testWidgets('openCapture runs the registered route with the given date',
      (WidgetTester tester) async {
    final List<String> openedDates = <String>[];
    String? result = 'unset';

    final CaptureRouteRegistry registry = CaptureRouteRegistry.empty.withRoute(
      CaptureRoute(
        type: EntryType.text,
        open: (BuildContext context, String date) async {
          openedDates.add(date);
          return 'entry-42';
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          captureRoutesProvider.overrideWithValue(registry),
        ],
        child: captureHarness(
          _OpenCapture(
            date: '2026-07-19',
            onResult: (String? id) => result = id,
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a note'));
    await tester.pumpAndSettle();

    expect(openedDates, <String>['2026-07-19']);
    expect(result, 'entry-42');
  });
}
