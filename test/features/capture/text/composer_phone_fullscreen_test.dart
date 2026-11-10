import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/immersive/immersive_route.dart'
    show immersiveFadeFor;
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/repository_providers.dart';

import '../../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
import '../core/capture_test_support.dart' show FakeDraftStore, FakeNoteWriter;

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _keyboard = 300;
const Size _desktop = Size(1280, 900);
const double _minimumHitHeight = 44;
const Duration _settled = Duration(milliseconds: 600);
const String _date = '2026-07-19';
const String _launcher = 'open';

typedef _Opener = Future<Object?> Function(BuildContext context);

Entry _noteEntry() => Entry(
  id: 'entry-1',
  dayId: 'day-1',
  type: EntryType.text,
  textContent: 'a good day',
  createdAt: DateTime(2026, 7, 19, 14, 30).millisecondsSinceEpoch,
  updatedAt: 0,
);

Future<Object?> _newNote(BuildContext context) =>
    showTextComposer(context, _date);

Future<Object?> _editedNote(BuildContext context) =>
    showEditNote(context, entry: _noteEntry(), date: _date);

const Map<String, _Opener> _composers = <String, _Opener>{
  'new note': _newNote,
  'edited note': _editedNote,
};

void _usePhone(WidgetTester tester, {double keyboard = 0}) {
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
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

void _useDesktop(WidgetTester tester) {
  tester.view.physicalSize = _desktop;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester,
  TargetPlatform platform,
  _Opener open,
) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: <Entry>[_noteEntry()]),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Builder(
          builder: (BuildContext context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(open(context)),
            child: const Text(_launcher),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_launcher));
  await tester.pump();
}

Finder get _panelFinder => find.byKey(composerPanelKey);

Rect _panel(WidgetTester tester) => tester.getRect(_panelFinder);

ModalRoute<Object?> _route(WidgetTester tester) =>
    ModalRoute.of(tester.element(_panelFinder))!;

double _hitHeight(WidgetTester tester, Finder control) =>
    tester.getSize(control).height;

void main() {
  testWidgets('the note room fills the window on phone and desktop alike', (
    WidgetTester tester,
  ) async {
    for (final MapEntry<String, _Opener> composer in _composers.entries) {
      final String reason = 'the ${composer.key} composer';

      _usePhone(tester);
      await _open(tester, TargetPlatform.android, composer.value);
      await tester.pump(_settled);

      expect(tester.takeException(), isNull, reason: reason);
      expect(_panel(tester), Offset.zero & _phone, reason: reason);
      expect(
        tester.widget<ColoredBox>(_panelFinder).color.toARGB32(),
        FieldNotesColors.light.viewerStage.toARGB32(),
        reason: reason,
      );
      expect(
        tester.getRect(find.byKey(composerCloseKey)).top,
        greaterThanOrEqualTo(_statusBar),
        reason: reason,
      );
      expect(
        _hitHeight(tester, find.byKey(composerCloseKey)),
        greaterThanOrEqualTo(_minimumHitHeight),
        reason: reason,
      );
      expect(
        _hitHeight(tester, find.byKey(composerSaveKey)),
        greaterThanOrEqualTo(_minimumHitHeight),
        reason: reason,
      );

      _useDesktop(tester);
      await _open(tester, TargetPlatform.macOS, composer.value);
      await tester.pump(_settled);

      expect(tester.takeException(), isNull, reason: reason);
      expect(_panel(tester), Offset.zero & _desktop, reason: reason);
      expect(
        tester.getSize(find.byKey(composerCloseKey)).height,
        greaterThanOrEqualTo(36),
        reason: reason,
      );
    }
  });

  testWidgets('the room fades in the way the other rooms do', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _open(tester, TargetPlatform.android, _newNote);

    expect(
      _route(tester).transitionDuration,
      immersiveFadeFor(ShellLayout.bottomBar),
    );
    expect(
      find.ancestor(of: _panelFinder, matching: find.byType(FadeTransition)),
      findsWidgets,
    );
    expect(
      find.ancestor(of: _panelFinder, matching: find.byType(SlideTransition)),
      findsNothing,
    );
    await tester.pump(_settled);
    expect(_panel(tester).top, 0);
  });

  testWidgets('with reduce motion the room appears at once', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester, TargetPlatform.android, _newNote);

    expect(_route(tester).transitionDuration, Duration.zero);
    expect(_panel(tester), Offset.zero & _phone);
  });

  testWidgets('a tap on the ground of the room keeps it open', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _open(tester, TargetPlatform.android, _newNote);
    await tester.pump(_settled);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.pump(_settled);

    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(find.text(composerDiscardTitle), findsNothing);
  });

  testWidgets('the room ends its controls at the top of the keyboard', (
    WidgetTester tester,
  ) async {
    _usePhone(tester, keyboard: _keyboard);
    await _open(tester, TargetPlatform.android, _newNote);
    await tester.pump(_settled);

    expect(tester.takeException(), isNull);
    expect(_panel(tester), Offset.zero & _phone);
    expect(
      tester.getRect(find.byKey(composerSaveKey)).bottom,
      lessThanOrEqualTo(_phone.height - _keyboard),
    );
  });
}
