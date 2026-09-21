import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/state/state.dart';

import 'support/day_detail_harness.dart';

class _DayTrigger extends StatelessWidget {
  const _DayTrigger({required this.date, this.focusEntryId, this.onError});

  final String date;
  final String? focusEntryId;
  final ValueChanged<Object>? onError;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        try {
          showDayDetail(context, date: date, focusEntryId: focusEntryId);
        } catch (error) {
          onError?.call(error);
        }
      },
      child: const Text('open day'),
    );
  }
}

Widget _dayApp({
  required FakeJournalRepository repository,
  String date = '2026-07-19',
  String? focusEntryId,
  ValueChanged<Object>? onError,
}) {
  return ProviderScope(
    overrides: <Override>[
      journalRepositoryProvider.overrideWithValue(repository),
      dayDetailMediaResolverProvider.overrideWith(
        (Ref ref) => FakeMediaResolver(),
      ),
    ],
    child: dayDetailHarness(
      _DayTrigger(date: date, focusEntryId: focusEntryId, onError: onError),
    ),
  );
}

FakeJournalRepository _repositoryWithOneNote() {
  return FakeJournalRepository(
    entries: <Entry>[
      entryOf(type: EntryType.text, textContent: 'a good day'),
    ],
  );
}

void main() {
  testWidgets('opens the day modal for the given date',
      (WidgetTester tester) async {
    await tester.pumpWidget(_dayApp(repository: _repositoryWithOneNote()));

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text('a good day'), findsOneWidget);
    expect(find.text('Add a note'), findsOneWidget);
  });

  testWidgets('the android system back button dismisses the modal',
      (WidgetTester tester) async {
    await tester.pumpWidget(_dayApp(repository: _repositoryWithOneNote()));

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday, July 19'), findsOneWidget);

    await sendSystemBack(tester);

    expect(find.text('Sunday, July 19'), findsNothing);
    expect(find.text('open day'), findsOneWidget);
  });

  testWidgets('tapping the barrier dismisses the modal',
      (WidgetTester tester) async {
    await tester.pumpWidget(_dayApp(repository: _repositoryWithOneNote()));

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, July 19'), findsNothing);
  });

  testWidgets('the close button dismisses the modal',
      (WidgetTester tester) async {
    await tester.pumpWidget(_dayApp(repository: _repositoryWithOneNote()));

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, July 19'), findsNothing);
  });

  testWidgets('rejects a malformed date key', (WidgetTester tester) async {
    Object? captured;

    await tester.pumpWidget(
      _dayApp(
        repository: _repositoryWithOneNote(),
        date: '19-07-2026',
        onError: (Object error) => captured = error,
      ),
    );

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    expect(captured, isArgumentError);
    expect(find.text('Sunday, July 19'), findsNothing);
  });

  testWidgets('forwards focusEntryId to the panel',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _dayApp(
        repository: _repositoryWithOneNote(),
        focusEntryId: 'entry-1',
      ),
    );

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    final DayDetailPanel panel =
        tester.widget<DayDetailPanel>(find.byType(DayDetailPanel));
    expect(panel.date, '2026-07-19');
    expect(panel.focusEntryId, 'entry-1');
  });

  testWidgets('omitting focusEntryId leaves the panel unfocused',
      (WidgetTester tester) async {
    await tester.pumpWidget(_dayApp(repository: _repositoryWithOneNote()));

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    final DayDetailPanel panel =
        tester.widget<DayDetailPanel>(find.byType(DayDetailPanel));
    expect(panel.focusEntryId, isNull);
    expect(find.text('a good day'), findsOneWidget);
  });
}
