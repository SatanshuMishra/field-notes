import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_editor_driver.dart';
import '../core/capture_test_support.dart';

class _ComposerTrigger extends StatelessWidget {
  const _ComposerTrigger({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextComposer(context, date),
      child: const Text('open'),
    );
  }
}

Widget _composerApp({
  required String date,
  required DateTime now,
  NoteWriter? writer,
}) {
  return ProviderScope(
    overrides: <Override>[
      noteWriterProvider.overrideWith((Ref ref) => writer ?? FakeNoteWriter()),
      draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
      todayClockProvider.overrideWith(
        (Ref ref) =>
            () => now,
      ),
    ],
    child: captureHarness(_ComposerTrigger(date: date)),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the header shows a labelled Cancel pill, a kicker and a left-aligned title',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        captureHarness(
          TextComposerSheet(
            onSave: (String _) {},
            onCancel: () {},
            title: 'New note',
            kicker: 'Today · 14:30',
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(composerCloseKey),
          matching: find.text('Cancel'),
        ),
        findsOneWidget,
      );
      expect(find.text('Today · 14:30'), findsOneWidget);
      expect(tester.getSize(find.byKey(composerCloseKey)).height, 34);

      final double pillRight = tester
          .getTopRight(find.byKey(composerCloseKey))
          .dx;
      final double titleLeft = tester.getTopLeft(find.text('New note')).dx;
      final double kickerLeft = tester
          .getTopLeft(find.text('Today · 14:30'))
          .dx;
      final double panelCentre = tester
          .getCenter(find.byType(TextComposerSheet))
          .dx;
      expect(titleLeft, lessThan(panelCentre));
      expect(titleLeft, moreOrLessEquals(pillRight + 14));
      expect(kickerLeft, moreOrLessEquals(titleLeft));
      expect(
        tester.getTopLeft(find.text('Today · 14:30')).dy,
        lessThan(tester.getTopLeft(find.text('New note')).dy),
      );
    },
  );

  testWidgets('a Back exit shows a Back pill with a back chevron', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      captureHarness(
        TextComposerSheet(
          onSave: (String _) {},
          onCancel: () {},
          title: 'New note',
          kicker: 'Wednesday, July 15',
          exit: ComposerExit.back,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(composerCloseKey),
        matching: find.text('Back'),
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('a new note for today carries the Today kicker with the time', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _composerApp(date: '2026-07-19', now: DateTime(2026, 7, 19, 14, 30)),
    );
    await _open(tester);

    expect(find.text('Today · 14:30'), findsOneWidget);
    expect(find.text(newNoteTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(composerCloseKey),
        matching: find.text('Cancel'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new note for a past day carries that day as its kicker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _composerApp(date: '2026-07-15', now: DateTime(2026, 7, 19, 14, 30)),
    );
    await _open(tester);

    expect(find.text('Wednesday, July 15'), findsOneWidget);
    expect(find.text(newNoteTitle), findsOneWidget);
  });

  testWidgets('saving a new note toasts where it was saved', (
    WidgetTester tester,
  ) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final FakeNoteWriter writer = FakeNoteWriter();
    await tester.pumpWidget(
      _composerApp(
        date: '2026-07-19',
        now: DateTime(2026, 7, 19, 14, 30),
        writer: writer,
      ),
    );
    await _open(tester);

    await driver.enterText('a good day');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(writer.saves, hasLength(1));
    expect(find.byType(TextComposerSheet), findsNothing);
    expect(find.text('Saved to today'), findsOneWidget);

    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'command or control Enter saves the note',
    (WidgetTester tester) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      final FakeNoteWriter writer = FakeNoteWriter();
      await tester.pumpWidget(
        _composerApp(
          date: '2026-07-19',
          now: DateTime(2026, 7, 19, 14, 30),
          writer: writer,
        ),
      );
      await _open(tester);

      await driver.enterText('a good day');
      await tester.pump();
      final bool mac = defaultTargetPlatform == TargetPlatform.macOS;
      final LogicalKeyboardKey modifier = mac
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(writer.saves, hasLength(1));
      expect(writer.saves.single.source, 'a good day');
      expect(find.byType(TextComposerSheet), findsNothing);

      await tester.pump(kToastLifetime);
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('Escape backs out of a composer with no unsaved changes', (
    WidgetTester tester,
  ) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    await tester.pumpWidget(
      _composerApp(
        date: '2026-07-19',
        now: DateTime(2026, 7, 19, 14, 30),
        writer: writer,
      ),
    );
    await _open(tester);
    expect(find.byType(TextComposerSheet), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TextComposerSheet), findsNothing);
    expect(writer.saves, isEmpty);
  });
}
