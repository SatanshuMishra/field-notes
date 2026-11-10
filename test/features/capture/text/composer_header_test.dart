import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_day_line.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialApp, ThemeData;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_editor_driver.dart';
import '../core/capture_test_support.dart';

const Duration _roomFade = Duration(milliseconds: 650);

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

const CaptureDayLine _sundayLine = (lead: 'today', date: 'Sunday, July 19');

const String _widePrivacyLine = 'Private · only you will read this';
const String _compactPrivacyLine = 'Only you will read this';

Widget _desktopSheet({
  ComposerExit exit = ComposerExit.cancel,
  CaptureDayLine? dayLine,
}) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.macOS),
    home: TextComposerSheet(
      onSave: (String _) {},
      onCancel: () {},
      exit: exit,
      dayLine: dayLine,
    ),
  );
}

double _dayLineCentre(WidgetTester tester, CaptureDayLine line) =>
    (tester.getTopLeft(find.text(line.lead)).dx +
        tester.getTopRight(find.text(line.date)).dx) /
    2;

void _useDesktopWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the desktop band says Leave, the day line and the keys', (
    WidgetTester tester,
  ) async {
    _useDesktopWindow(tester);
    await tester.pumpWidget(_desktopSheet(dayLine: _sundayLine));

    expect(
      find.descendant(
        of: find.byKey(composerCloseKey),
        matching: find.text('Leave'),
      ),
      findsOneWidget,
    );
    expect(find.text(_sundayLine.lead), findsOneWidget);
    expect(find.text(_sundayLine.date), findsOneWidget);
    expect(find.text(_widePrivacyLine), findsNothing);
    expect(find.text('⌘ Return'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(_dayLineCentre(tester, _sundayLine), closeTo(640, 12));
  });

  testWidgets('Windows reads the keep key as Ctrl Enter', (
    WidgetTester tester,
  ) async {
    _useDesktopWindow(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: TextComposerSheet(onSave: (String _) {}, onCancel: () {}),
      ),
    );

    expect(find.text('Ctrl Enter'), findsOneWidget);
    expect(find.text('⌘ Return'), findsNothing);
  });

  testWidgets('the phone band is an icon and the same day line', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      captureHarness(
        TextComposerSheet(
          onSave: (String _) {},
          onCancel: () {},
          dayLine: _sundayLine,
        ),
      ),
    );

    expect(find.text('Leave'), findsNothing);
    expect(find.bySemanticsLabel('Leave'), findsOneWidget);
    expect(find.text(_sundayLine.lead), findsOneWidget);
    expect(find.text(_sundayLine.date), findsOneWidget);
    expect(find.text(_compactPrivacyLine), findsNothing);
    expect(find.text('Esc'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a new note for today says today and the date in its band', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _composerApp(date: '2026-07-19', now: DateTime(2026, 7, 19, 14, 30)),
    );
    await _open(tester);

    expect(find.text('today'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text(_widePrivacyLine), findsNothing);
    expect(find.text(_compactPrivacyLine), findsNothing);
  });

  testWidgets('a new note for a past day says it is adding to that day', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _composerApp(date: '2026-07-15', now: DateTime(2026, 7, 19, 14, 30)),
    );
    await _open(tester);

    expect(find.text('adding to'), findsOneWidget);
    expect(find.text('Wednesday, July 15'), findsOneWidget);
    expect(find.text('today'), findsNothing);
    expect(find.text(_widePrivacyLine), findsNothing);
    expect(find.text(_compactPrivacyLine), findsNothing);
  });

  testWidgets('a Back exit says Back with a chevron', (
    WidgetTester tester,
  ) async {
    _useDesktopWindow(tester);
    await tester.pumpWidget(_desktopSheet(exit: ComposerExit.back));

    expect(
      find.descendant(
        of: find.byKey(composerCloseKey),
        matching: find.text('Back'),
      ),
      findsOneWidget,
    );
    expect(find.text('Leave'), findsNothing);
  });

  testWidgets('a new note for today names the room and the time to a reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _composerApp(date: '2026-07-19', now: DateTime(2026, 7, 19, 14, 30)),
    );
    await _open(tester);

    expect(
      find.bySemanticsLabel('$newNoteTitle, Today · 2:30 PM'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a new note for a past day names that day to a reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _composerApp(date: '2026-07-15', now: DateTime(2026, 7, 19, 14, 30)),
    );
    await _open(tester);

    expect(
      find.bySemanticsLabel('$newNoteTitle, Wednesday, July 15'),
      findsOneWidget,
    );
    semantics.dispose();
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
    await tester.tap(find.text('Keep this'));
    await tester.pump();
    await tester.pump();
    await tester.pump(_roomFade);

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
      await tester.pump(_roomFade);

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
