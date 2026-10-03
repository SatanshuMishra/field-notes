import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../capture/core/capture_test_support.dart'
    show FakeNoteWriter, NoteSaveCall;

const String _kicker = 'a moment';
const String _title = 'Write a little about today.';
const String _placeholder = 'What happened today?';
const String _waitingHint = 'write anything at all to keep going';
const String _savedHint = 'saved to today ✓';
const String _clockLine = 'Today · 9:41 AM';
const String _lineError = "Couldn't save this line. Keep typing to try again.";
const String _sidebarLead = "And there's more than one way to keep a memory.";
const String _sidebarFoot =
    "You'll find these on every log, once you're set up.";
const String _phoneTilesLead = 'More than one way to keep a memory';

const Duration _pause = Duration(milliseconds: 600);
const Duration _slowSave = Duration(seconds: 2);
const Duration _focusSettle = Duration(milliseconds: 50);
const int _maxTabs = 10;

final DateTime _openedAt = DateTime(2026, 10, 14, 9, 41);

const OnboardingDraft _draft = OnboardingDraft(
  entryDate: '2026-10-14',
  regionWeek: WeekStart.sunday,
  week: WeekStart.sunday,
  mood: Mood.calm,
);

const List<Key> _mediaKeys = <Key>[
  momentVoiceKey,
  momentVideoKey,
  momentPhotosKey,
];

typedef _Layout = ({
  ShellLayout layout,
  TargetPlatform platform,
  PointerDeviceKind pointer,
  Size surface,
  List<String> media,
});

const _Layout _sidebar = (
  layout: ShellLayout.sidebar,
  platform: TargetPlatform.macOS,
  pointer: PointerDeviceKind.mouse,
  surface: Size(1280, 758),
  media: <String>[
    'your voice',
    'a video, of you or the view',
    'photos from the day',
  ],
);

const _Layout _bottomBar = (
  layout: ShellLayout.bottomBar,
  platform: TargetPlatform.android,
  pointer: PointerDeviceKind.touch,
  surface: Size(360, 740),
  media: <String>[],
);

const List<_Layout> _layouts = <_Layout>[_sidebar, _bottomBar];

const List<(_Layout, Size)> _smallest = <(_Layout, Size)>[
  (_sidebar, Size(873, 558)),
  (_bottomBar, Size(360, 640)),
];

Future<void> _onLayout(_Layout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout.platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpMoment(
  WidgetTester tester,
  _Layout layout, {
  required NoteWriter writer,
  bool reduceMotion = false,
  Size? surface,
}) async {
  await pumpShell(
    tester,
    Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Material(child: MomentChapter(layout: layout.layout)),
      ),
    ),
    platform: layout.platform,
    surface: surface ?? layout.surface,
    overrides: <Override>[
      todayClockProvider.overrideWithValue(() => _openedAt),
      noteWriterProvider.overrideWith((Ref ref) => writer),
      onboardingControllerProvider.overrideWithBuild(
        (Ref ref, OnboardingController controller) =>
            const OnboardingFlowRunning(
              chapter: OnboardingChapter.moment,
              draft: _draft,
            ),
      ),
    ],
  );
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _flush(WidgetTester tester) async {
  for (int frame = 0; frame < 5; frame++) {
    await tester.pump();
  }
}

Future<void> _run(WidgetTester tester, Duration total) async {
  const Duration step = Duration(milliseconds: 100);
  for (Duration spent = Duration.zero; spent < total; spent += step) {
    await tester.pump(step);
  }
}

void _traditionalHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

Future<void> _settleFocus(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_focusSettle);
}

OnboardingFlow _flow(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MomentChapter)))
        .read(onboardingControllerProvider);

OnboardingDraft _draftNow(WidgetTester tester) => switch (_flow(tester)) {
  OnboardingFlowRunning(:final OnboardingDraft draft) => draft,
  OnboardingFlowHidden() ||
  OnboardingFlowMap() => throw StateError('onboarding is not running'),
};

Finder _inCard(String text) =>
    find.descendant(of: find.byKey(momentCardKey), matching: find.text(text));

Finder get _field => find.descendant(
  of: find.byKey(momentFieldKey),
  matching: find.byType(EditableText),
);

String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(_field).controller.text;

EditableTextState _editable(WidgetTester tester) =>
    tester.state<EditableTextState>(_field);

Future<void> _tabToField(WidgetTester tester, String route) async {
  for (int press = 0; press < _maxTabs; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _settleFocus(tester);
    if (_editable(tester).widget.focusNode.hasPrimaryFocus) {
      return;
    }
  }
  fail('$route: Tab never focuses the note field');
}

void _expectCaretWithoutRing(WidgetTester tester, String route) {
  final EditableTextState editable = _editable(tester);
  expect(editable.widget.focusNode.hasPrimaryFocus, isTrue, reason: route);
  expect(find.byKey(focusRingKey), findsNothing, reason: route);
  expect(editable.renderEditable.selection?.isCollapsed, isTrue, reason: route);
  expect(editable.renderEditable.showCursor.value, isTrue, reason: route);
  expect(editable.cursorCurrentlyVisible, isTrue, reason: route);
}

BoxShadow _cardShadow(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.byKey(momentCardKey),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .boxShadow!
        .single;

ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .ancestor(
            of: find.byKey(momentCardKey),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void _expectEmptyCard(WidgetTester tester, _Layout layout) {
  expect(find.text(_kicker), findsOneWidget);
  expect(find.text(_title), findsOneWidget);
  expect(_inCard(_clockLine), findsOneWidget);
  expect(
    _inCard('Note'),
    layout.layout == ShellLayout.sidebar ? findsOneWidget : findsNothing,
  );
  expect(
    tester
        .widget<FlowerBloom>(
          find.descendant(
            of: find.byKey(momentCardKey),
            matching: find.byType(FlowerBloom),
          ),
        )
        .kind,
    Mood.calm.flower,
  );
  expect(_inCard(_placeholder), findsOneWidget);
  expect(_inCard(_waitingHint), findsOneWidget);
  expect(find.text(_savedHint), findsNothing);
  expect(find.byKey(momentMediaKey), findsNothing);
  expect(find.text(_sidebarLead), findsNothing);
  expect(find.textContaining(_phoneTilesLead), findsNothing);
}

void _expectMediaRow(WidgetTester tester, _Layout layout) {
  expect(_inCard(_savedHint), findsOneWidget);
  expect(_inCard(_waitingHint), findsNothing);
  expect(find.textContaining(_phoneTilesLead), findsNothing);
  if (layout.layout == ShellLayout.bottomBar) {
    expect(find.byKey(momentMediaKey), findsNothing);
    for (final Key key in _mediaKeys) {
      expect(find.byKey(key), findsNothing);
    }
    expect(find.text(_sidebarLead), findsNothing);
    expect(find.text(_sidebarFoot), findsNothing);
    return;
  }
  expect(find.byKey(momentMediaKey), findsOneWidget);
  expect(find.text(_sidebarLead), findsOneWidget);
  for (final String label in layout.media) {
    expect(
      find.descendant(
        of: find.byKey(momentMediaKey),
        matching: find.text(label),
      ),
      findsOneWidget,
      reason: label,
    );
  }
  expect(find.text(_sidebarFoot), findsOneWidget);
}

void main() {
  testWidgets(
    'a moment shows the empty card, caps at 280 and reveals the mac media row once saved',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          final FakeNoteWriter writer = FakeNoteWriter();
          await _pumpMoment(tester, layout, writer: writer);
          await _run(tester, const Duration(seconds: 1));
          _expectEmptyCard(tester, layout);

          final String typed = List<String>.generate(
            300,
            (int index) => 'field notes '[index % 12],
          ).join();
          final String kept = typed.substring(0, 280);
          await tester.enterText(_field, typed);
          await tester.pump();
          expect(_fieldText(tester), kept);
          expect(_draftNow(tester).noteText, kept);
          expect(_inCard(_waitingHint), findsOneWidget);
          expect(find.byKey(momentMediaKey), findsNothing);

          await tester.pump(_pause);
          await _flush(tester);
          expect(writer.saves, hasLength(1));
          expect(writer.saves.single.source, kept);
          expect(_draftNow(tester).noteSave, NoteSaveState.saved);
          await _run(tester, const Duration(seconds: 2));
          _expectMediaRow(tester, layout);

          final OnboardingFlow before = _flow(tester);
          if (layout.layout == ShellLayout.sidebar) {
            for (final Key key in _mediaKeys) {
              expect(find.byKey(key), findsOneWidget);
              await tester.tap(find.byKey(key));
              await _run(tester, const Duration(milliseconds: 700));
            }
          }
          for (final String label in layout.media) {
            expect(
              tester.getSemantics(find.text(label)),
              isSemantics(
                isButton: false,
                hasTapAction: false,
                hasLongPressAction: false,
              ),
              reason: label,
            );
          }
          expect(_flow(tester), before);
          expect(_fieldText(tester), kept);
          expect(writer.saves, hasLength(1));
          expect(find.byType(MomentChapter), findsOneWidget);
          _expectMediaRow(tester, layout);
          await _unmount(tester);
        });
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'a later save keeps the saved hint and the media row until it lands',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          final FakeNoteWriter writer = FakeNoteWriter(delay: _slowSave);
          await _pumpMoment(tester, layout, writer: writer);
          await tester.enterText(_field, 'The ferry');
          await tester.pump(_pause);
          await _flush(tester);
          expect(_draftNow(tester).noteSave, NoteSaveState.saving);
          expect(_inCard(_waitingHint), findsOneWidget);
          expect(find.byKey(momentMediaKey), findsNothing);

          await tester.pump(_slowSave);
          await _flush(tester);
          await _run(tester, const Duration(seconds: 2));
          _expectMediaRow(tester, layout);

          await tester.enterText(_field, 'The ferry was late');
          await tester.pump(_pause);
          await _flush(tester);
          expect(_draftNow(tester).noteSave, NoteSaveState.saving);
          _expectMediaRow(tester, layout);

          await tester.pump(_slowSave);
          await _flush(tester);
          expect(_draftNow(tester).noteSave, NoteSaveState.saved);
          expect(writer.saves.map((NoteSaveCall save) => save.source), <String>[
            'The ferry',
            'The ferry was late',
          ]);
          _expectMediaRow(tester, layout);
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets('a failed save shows the line error in the danger ink', (
    WidgetTester tester,
  ) async {
    for (final _Layout layout in _layouts) {
      await _onLayout(layout, () async {
        final FakeNoteWriter writer = FakeNoteWriter(
          failure: const NoteWriteException('disk full'),
        );
        await _pumpMoment(tester, layout, writer: writer);
        await tester.enterText(_field, 'The ferry was late');
        await tester.pump(_pause);
        await _flush(tester);
        expect(_draftNow(tester).noteSave, NoteSaveState.failed);
        expect(_inCard(_waitingHint), findsOneWidget);
        expect(find.text(_savedHint), findsNothing);
        expect(find.byKey(momentMediaKey), findsNothing);
        expect(_inCard(_lineError), findsOneWidget);
        expect(
          tester.widget<Text>(_inCard(_lineError)).style?.color,
          FieldNotesColors.light.dangerInk,
        );
        await _unmount(tester);
      });
    }
  });

  testWidgets(
    'the saved line, and the mac media row, fit the smallest windows unscrolled',
    (WidgetTester tester) async {
      for (final (_Layout layout, Size surface) in _smallest) {
        await _onLayout(layout, () async {
          await _pumpMoment(
            tester,
            layout,
            writer: FakeNoteWriter(),
            surface: surface,
          );
          await tester.enterText(_field, 'The ferry was late');
          await tester.pump(_pause);
          await _flush(tester);
          await _run(tester, const Duration(seconds: 2));
          _expectMediaRow(tester, layout);
          expect(tester.takeException(), isNull);
          if (layout.layout == ShellLayout.sidebar) {
            expect(_scroll(tester).maxScrollExtent, 0, reason: '$surface');
          } else {
            expect(
              find.ancestor(
                of: find.byKey(momentCardKey),
                matching: find.byType(Scrollable),
              ),
              findsNothing,
            );
            final Rect card = tester.getRect(find.byKey(momentCardKey));
            expect(card.bottom, lessThanOrEqualTo(surface.height - 72 - 12));
            expect(
              tester.getRect(find.byKey(momentFieldKey)).height,
              greaterThan(32 * 3),
            );
          }
          await _unmount(tester);
        });
      }
    },
  );

  testWidgets('the note field shows no outline when it has focus', (
    WidgetTester tester,
  ) async {
    _traditionalHighlight();
    for (final _Layout layout in _layouts) {
      await _onLayout(layout, () async {
        final String pressed = '${layout.layout} by ${layout.pointer.name}';
        await _pumpMoment(tester, layout, writer: FakeNoteWriter());
        await _run(tester, const Duration(seconds: 1));
        await tester.tap(_field, kind: layout.pointer);
        await _settleFocus(tester);
        _expectCaretWithoutRing(tester, pressed);
        await _unmount(tester);

        final String tabbed = '${layout.layout} by Tab';
        await _pumpMoment(tester, layout, writer: FakeNoteWriter());
        await _run(tester, const Duration(seconds: 1));
        await _tabToField(tester, tabbed);
        _expectCaretWithoutRing(tester, tabbed);
        await _unmount(tester);
      });
    }
  });

  testWidgets('the empty card glows softly unless animations are disabled', (
    WidgetTester tester,
  ) async {
    for (final _Layout layout in _layouts) {
      await _onLayout(layout, () async {
        await _pumpMoment(tester, layout, writer: FakeNoteWriter());
        await tester.pump(const Duration(milliseconds: 2500));
        expect(_cardShadow(tester).spreadRadius, closeTo(6, 0.01));
        expect(_cardShadow(tester).color.a, closeTo(0.28, 0.01));
        await _unmount(tester);

        await _pumpMoment(
          tester,
          layout,
          writer: FakeNoteWriter(),
          reduceMotion: true,
        );
        final Opacity heading = tester.widget<Opacity>(
          find
              .ancestor(of: find.text(_title), matching: find.byType(Opacity))
              .first,
        );
        expect(heading.opacity, 1);
        for (int frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(_cardShadow(tester).spreadRadius, 0);
        }
        expect(tester.binding.hasScheduledFrame, isFalse);
        await _unmount(tester);
      });
    }
  });
}
