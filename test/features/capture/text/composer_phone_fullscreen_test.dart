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
const double _desktopPanelWidth = 768;
const double _desktopPanelMargin = 28;
const double _minimumHitHeight = 44;
const double _phoneHeaderButtonHeight = 40;
const double _desktopExitPillHeight = 34;
const double _phoneSavePadding = 14;
const Duration _phoneSlide = Duration(milliseconds: 260);
const Cubic _phoneSlideCurve = Cubic(0.2, 0.8, 0.2, 1);
const Duration _desktopPop = Duration(milliseconds: 220);
const Duration _midSlide = Duration(milliseconds: 100);
const Duration _settled = Duration(milliseconds: 300);
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

Rect _sheet(WidgetTester tester) =>
    tester.getRect(find.byType(TextComposerSheet));

BoxDecoration _panelDecoration(WidgetTester tester) =>
    tester.widget<Container>(_panelFinder).decoration! as BoxDecoration;

ModalRoute<Object?> _route(WidgetTester tester) =>
    ModalRoute.of(tester.element(_panelFinder))!;

double _hitHeight(WidgetTester tester, Finder control) => tester
    .getSize(
      find.ancestor(of: control, matching: find.byType(GestureDetector)).first,
    )
    .height;

void main() {
  testWidgets(
    'the phone note composer fills the screen for new and edited notes',
    (WidgetTester tester) async {
      for (final MapEntry<String, _Opener> composer in _composers.entries) {
        final String reason = 'the ${composer.key} composer';

        _usePhone(tester);
        await _open(tester, TargetPlatform.android, composer.value);
        await tester.pump(_settled);

        expect(tester.takeException(), isNull, reason: reason);
        expect(_panel(tester), Offset.zero & _phone, reason: reason);
        expect(
          _sheet(tester),
          Rect.fromLTRB(
            0,
            _statusBar,
            _phone.width,
            _phone.height - _gestureBar,
          ),
          reason: reason,
        );
        final BoxDecoration paper = _panelDecoration(tester);
        expect(paper.border, isNull, reason: reason);
        expect(paper.borderRadius, isNull, reason: reason);
        expect(paper.boxShadow, isNull, reason: reason);
        expect(
          paper.color?.toARGB32(),
          FieldNotesColors.light.composerPaper.toARGB32(),
          reason: reason,
        );
        expect(
          _hitHeight(tester, find.byKey(composerCloseKey)),
          greaterThanOrEqualTo(_minimumHitHeight),
          reason: reason,
        );
        expect(
          _hitHeight(tester, find.textContaining('Save')),
          greaterThanOrEqualTo(_minimumHitHeight),
          reason: reason,
        );

        _useDesktop(tester);
        await _open(tester, TargetPlatform.macOS, composer.value);
        await tester.pump(_settled);

        expect(tester.takeException(), isNull, reason: reason);
        final Rect card = _panel(tester);
        expect(card.width, _desktopPanelWidth, reason: reason);
        expect(card.center.dx, _desktop.width / 2, reason: reason);
        expect(card.top, _desktopPanelMargin, reason: reason);
        expect(
          card.bottom,
          _desktop.height - _desktopPanelMargin,
          reason: reason,
        );
        final BoxDecoration floating = _panelDecoration(tester);
        expect(floating.border, isNotNull, reason: reason);
        expect(floating.borderRadius, isNotNull, reason: reason);
        expect(floating.boxShadow, isNotEmpty, reason: reason);
        expect(card.contains(_sheet(tester).center), isTrue, reason: reason);
        expect(_sheet(tester).width, lessThan(card.width), reason: reason);
      }
    },
  );

  testWidgets('the phone composer header Back and Save are 40 points tall', (
    WidgetTester tester,
  ) async {
    final Finder save = find.byKey(composerSaveKey);
    final Finder saveLabel = find.descendant(
      of: save,
      matching: find.byType(Text),
    );
    BorderRadiusGeometry? saveRadius() =>
        (tester.widget<DecoratedBox>(save).decoration as BoxDecoration)
            .borderRadius;
    for (final MapEntry<String, _Opener> composer in _composers.entries) {
      final String reason = 'the ${composer.key} composer';

      _usePhone(tester);
      await _open(tester, TargetPlatform.android, composer.value);
      await tester.pump(_settled);

      expect(tester.takeException(), isNull, reason: reason);
      expect(
        tester.getSize(find.byKey(composerCloseKey)).height,
        _phoneHeaderButtonHeight,
        reason: reason,
      );
      expect(
        tester.getSize(save).height,
        _phoneHeaderButtonHeight,
        reason: reason,
      );
      expect(
        saveRadius(),
        const BorderRadius.all(Radius.circular(12)),
        reason: reason,
      );
      expect(
        tester.widget<Text>(saveLabel).style!.fontSize,
        12,
        reason: reason,
      );
      final Rect saveRect = tester.getRect(save);
      final Rect labelRect = tester.getRect(saveLabel);
      expect(labelRect.left - saveRect.left, _phoneSavePadding, reason: reason);
      expect(
        saveRect.right - labelRect.right,
        _phoneSavePadding,
        reason: reason,
      );
      expect(
        _hitHeight(tester, find.byKey(composerCloseKey)),
        greaterThanOrEqualTo(_minimumHitHeight),
        reason: reason,
      );
      expect(
        _hitHeight(tester, save),
        greaterThanOrEqualTo(_minimumHitHeight),
        reason: reason,
      );

      _useDesktop(tester);
      await _open(tester, TargetPlatform.macOS, composer.value);
      await tester.pump(_settled);

      expect(tester.takeException(), isNull, reason: reason);
      expect(
        tester.getSize(find.byKey(composerCloseKey)).height,
        _desktopExitPillHeight,
        reason: reason,
      );
      expect(
        saveRadius(),
        const BorderRadius.all(Radius.circular(Shapes.radiusPill)),
        reason: reason,
      );
    }
  });

  testWidgets(
    'the phone composer slides up from the bottom while macOS pops in',
    (WidgetTester tester) async {
      for (final MapEntry<String, _Opener> composer in _composers.entries) {
        final String reason = 'the ${composer.key} composer';

        _usePhone(tester);
        await _open(tester, TargetPlatform.android, composer.value);

        expect(_route(tester).transitionDuration, _phoneSlide, reason: reason);
        await tester.pump(_midSlide);
        final double progress = _phoneSlideCurve.transform(
          _midSlide.inMicroseconds / _phoneSlide.inMicroseconds,
        );
        expect(_panel(tester).left, 0, reason: reason);
        expect(
          _panel(tester).top,
          closeTo((1 - progress) * _phone.height, 0.5),
          reason: reason,
        );
        expect(
          find.ancestor(
            of: _panelFinder,
            matching: find.byType(ScaleTransition),
          ),
          findsNothing,
          reason: reason,
        );
        await tester.pump(_settled);
        expect(_panel(tester).top, 0, reason: reason);

        _useDesktop(tester);
        await _open(tester, TargetPlatform.macOS, composer.value);

        expect(_route(tester).transitionDuration, _desktopPop, reason: reason);
        expect(
          find.ancestor(
            of: _panelFinder,
            matching: find.byType(SlideTransition),
          ),
          findsNothing,
          reason: reason,
        );
        expect(
          find.ancestor(
            of: _panelFinder,
            matching: find.byType(ScaleTransition),
          ),
          findsOneWidget,
          reason: reason,
        );
        await tester.pump(_settled);
      }
    },
  );

  testWidgets('with reduce motion the phone composer appears without sliding', (
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

  testWidgets('a tap on the phone composer paper keeps it open', (
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

  testWidgets('the phone composer stops at the top of the keyboard', (
    WidgetTester tester,
  ) async {
    _usePhone(tester, keyboard: _keyboard);
    await _open(tester, TargetPlatform.android, _newNote);
    await tester.pump(_settled);

    expect(tester.takeException(), isNull);
    expect(_panel(tester), Offset.zero & _phone);
    expect(
      _sheet(tester),
      Rect.fromLTRB(0, _statusBar, _phone.width, _phone.height - _keyboard),
    );
    final BuildContext sheet = tester.element(find.byType(TextComposerSheet));
    expect(MediaQuery.viewInsetsOf(sheet).bottom, 0);
    expect(MediaQuery.paddingOf(sheet).top, 0);
    expect(MediaQuery.paddingOf(sheet).bottom, 0);
  });
}
