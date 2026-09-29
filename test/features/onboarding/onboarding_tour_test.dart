import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/tour/onboarding_tour.dart';
import 'package:field_notes/features/onboarding/tour/tour_spotlight.dart';
import 'package:field_notes/features/onboarding/tour/tour_tips.dart';
import 'package:field_notes/features/onboarding/tour_anchor.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _resizedSidebarSurface = Size(1000, 700);
const Size _bottomBarSurface = Size(360, 740);
const Size _smallPhoneSurface = Size(360, 640);
const double _largeText = 1.15;
const double _tolerance = 1;

const List<String> _titles = <String>[
  'Four pages, one journal',
  'Plant a bloom each day',
  'Capture a moment',
  'What a note can hold',
  'Past days stay open',
  'Settings live here',
];

const String _moodLine = 'One mood per day · 10 to choose from';
const String _captureLine = 'Tap + from any page.';
const String _calendarLine = 'Open any day in Calendar to add or edit.';
const String _firstRunSettingsLine = 'We’ll set these up next.';
const String _replaySettingsLine = 'Change these anytime.';

const List<String> _allLines = <String>[
  _moodLine,
  _captureLine,
  _calendarLine,
  _firstRunSettingsLine,
  _replaySettingsLine,
];

const Map<TourTarget, double> _sidebarPadding = <TourTarget, double>{
  TourTarget.nav: 7,
  TourTarget.mood: 6,
  TourTarget.capture: 8,
  TourTarget.calendar: 5,
  TourTarget.settings: 6,
};

const Map<TourTarget, double> _bottomBarPadding = <TourTarget, double>{
  TourTarget.nav: 5,
  TourTarget.mood: 5,
  TourTarget.capture: 5,
  TourTarget.calendar: 5,
  TourTarget.settings: 5,
};

Finder get _card => find.byKey(tourCardKey);

Finder _inCard(Finder finder) => find.descendant(of: _card, matching: finder);

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<List<String>> _pumpTour(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size surface,
  TourMode mode = TourMode.firstRun,
  int initialTip = 0,
  ValueListenable<double>? textScale,
}) async {
  final List<String> calls = <String>[];
  final Widget stack = Stack(
    key: UniqueKey(),
    fit: StackFit.expand,
    children: <Widget>[
      const AppShell(),
      OnboardingTour(
        layout: resolveShellLayout(platform),
        mode: mode,
        initialTip: initialTip,
        onBackOut: () => calls.add('backOut'),
        onFinish: () => calls.add('finish'),
        onSkip: () => calls.add('skip'),
      ),
    ],
  );
  final ValueListenable<double>? scale = textScale;
  await pumpShell(
    tester,
    scale == null
        ? stack
        : ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (BuildContext context, double value, Widget? child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(value)),
                child: child!,
              );
            },
            child: stack,
          ),
    platform: platform,
    surface: surface,
  );
  await _settle(tester);
  return calls;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await _settle(tester);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

Future<void> _expectFocusTrapped(WidgetTester tester) async {
  for (int press = 0; press < 5; press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<OnboardingTour>(),
      isNotNull,
      reason: 'Tab press ${press + 1} left the tour',
    );
  }
}

Future<void> _expectAppBehindIgnoresTaps(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key), warnIfMissed: false);
  await _settle(tester);
  expect(
    ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    ).read(shellNavigationProvider),
    ShellDestination.today,
  );
}

void _expectTip(WidgetTester tester, int index) {
  expect(
    _inCard(find.text(_titles[index])),
    findsOneWidget,
    reason: 'expected tip ${index + 1}',
  );
}

String _nextLabel(WidgetTester tester) {
  return tester.getSemantics(find.byKey(tourNextKey)).label;
}

void _expectLine(String? line) {
  for (final String candidate in _allLines) {
    expect(
      _inCard(find.text(candidate)),
      candidate == line ? findsOneWidget : findsNothing,
      reason: candidate,
    );
  }
}

void _expectTexts(List<String> texts) {
  for (final String text in texts) {
    expect(_inCard(find.text(text)), findsOneWidget, reason: text);
  }
}

List<FlowerKind> _flowers(WidgetTester tester) {
  return tester
      .widgetList<FlowerBloom>(_inCard(find.byType(FlowerBloom)))
      .map((FlowerBloom bloom) => bloom.kind)
      .toList();
}

void _expectContent(
  WidgetTester tester,
  int index,
  ShellLayout layout,
  TourMode mode,
) {
  _expectTip(tester, index);
  switch (index) {
    case 0:
      _expectTexts(<String>[
        'Today',
        'this day',
        'Calendar',
        'past days',
        'Garden',
        'your year',
        'Search',
        'find anything',
      ]);
      expect(
        tester
            .widgetList<NavIcon>(_inCard(find.byType(NavIcon)))
            .map((NavIcon icon) => icon.glyph)
            .toList(),
        <NavGlyph>[
          NavGlyph.home,
          NavGlyph.calendar,
          NavGlyph.garden,
          NavGlyph.search,
        ],
      );
      _expectLine(null);
    case 1:
      _expectTexts(<String>['Happy', 'Calm', 'Tired', 'Sad', 'Angry']);
      expect(_flowers(tester), <FlowerKind>[
        Mood.happy.flower,
        Mood.calm.flower,
        Mood.tired.flower,
        Mood.sad.flower,
        Mood.angry.flower,
      ]);
      _expectLine(_moodLine);
    case 2:
      _expectTexts(<String>[
        'Write',
        'words + photos',
        'Voice',
        'speak it',
        'Video',
        'film it',
      ]);
      expect(
        tester
            .widgetList<CaptureIcon>(_inCard(find.byType(CaptureIcon)))
            .map((CaptureIcon icon) => icon.glyph)
            .toList(),
        <CaptureGlyph>[
          CaptureGlyph.pencil,
          CaptureGlyph.mic,
          CaptureGlyph.video,
        ],
      );
      _expectLine(layout == ShellLayout.bottomBar ? _captureLine : null);
    case 3:
      _expectTexts(<String>[
        'WORKS IN NOTES',
        'Headings',
        'Lists',
        'Steps',
        'To-dos',
        'Quotes',
        'Styles',
        'Tables',
        'Code blocks',
        'Photos',
        'NOT SUPPORTED',
        'Files & PDFs',
        'Editing voice or video',
      ]);
      _expectLine(null);
    case 4:
      _expectTexts(<String>['Today', '← open & edit', 'closed →']);
      expect(_flowers(tester), <FlowerKind>[
        Mood.warm.flower,
        Mood.calm.flower,
        Mood.happy.flower,
      ]);
      _expectLine(_calendarLine);
    case 5:
      _expectTexts(<String>['Reminders', 'Week start', 'Storage']);
      _expectLine(
        mode == TourMode.firstRun ? _firstRunSettingsLine : _replaySettingsLine,
      );
  }
  for (int bar = 0; bar < _titles.length; bar++) {
    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(find.byKey(tourProgressKey(bar))).decoration
            as BoxDecoration;
    expect(
      decoration.color,
      bar == index
          ? Palette.coral
          : bar < index
          ? const Color(0xFFDBA493)
          : FieldNotesColors.light.ink18,
      reason: 'progress bar ${bar + 1} on tip ${index + 1}',
    );
  }
}

TourSpotlightPainter _painter(WidgetTester tester) {
  return tester.widget<CustomPaint>(find.byKey(tourScrimKey)).painter!
      as TourSpotlightPainter;
}

void _expectSpotlightLands(
  WidgetTester tester,
  int index,
  ShellLayout layout,
  String where,
) {
  final String reason = '$where, tip ${index + 1}';
  _expectTip(tester, index);
  final RenderBox overlay = tester.renderObject<RenderBox>(
    find.byType(OnboardingTour),
  );
  final TourAnchors anchors = ProviderScope.containerOf(
    tester.element(find.byType(OnboardingTour)),
  ).read(tourAnchorsProvider);
  final RenderBox cardBox = tester.renderObject<RenderBox>(_card);
  final Rect card =
      cardBox.localToGlobal(Offset.zero, ancestor: overlay) & cardBox.size;
  final Rect window = Offset.zero & overlay.size;
  final bool sidebar = layout == ShellLayout.sidebar;
  final double inset = sidebar ? 16 : 12;
  final double topInset = sidebar
      ? 16
      : MediaQuery.paddingOf(tester.element(find.byType(OnboardingTour))).top +
            8;

  expect(
    tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: _card, matching: find.byType(AnimatedOpacity)),
        )
        .opacity,
    1,
    reason: reason,
  );
  expect(card.left, greaterThanOrEqualTo(inset - _tolerance), reason: reason);
  expect(card.top, greaterThanOrEqualTo(topInset - _tolerance), reason: reason);
  expect(
    card.right,
    lessThanOrEqualTo(window.width - inset + _tolerance),
    reason: reason,
  );
  expect(
    card.bottom,
    lessThanOrEqualTo(window.height - inset + _tolerance),
    reason: reason,
  );
  if (layout == ShellLayout.bottomBar) {
    expect(card.width, closeTo(window.width - 24, _tolerance), reason: reason);
    final Rect controls = tester.getRect(find.byKey(tourControlsKey));
    expect(
      card.bottom,
      lessThanOrEqualTo(controls.top - 12 + _tolerance),
      reason: reason,
    );
    final Rect? nav = anchors.rectOf(TourTarget.nav, overlay);
    expect(controls.bottom, closeTo(nav!.top - 12, _tolerance), reason: reason);
  }

  final TourTarget? target = tourTips[index].target;
  final Rect? hole = _painter(tester).hole;
  if (target == null) {
    expect(hole, isNull, reason: reason);
    return;
  }
  final Rect? anchor = anchors.rectOf(target, overlay);
  expect(anchor, isNotNull, reason: '$reason has no anchor');
  final double padding = switch (layout) {
    ShellLayout.sidebar => _sidebarPadding[target]!,
    ShellLayout.bottomBar => _bottomBarPadding[target]!,
  };
  final Rect expected = anchor!.inflate(padding);
  expect(hole, isNotNull, reason: '$reason painted no hole');
  expect(hole!.left, closeTo(expected.left, _tolerance), reason: reason);
  expect(hole.top, closeTo(expected.top, _tolerance), reason: reason);
  expect(hole.right, closeTo(expected.right, _tolerance), reason: reason);
  expect(hole.bottom, closeTo(expected.bottom, _tolerance), reason: reason);
  expect(card.overlaps(hole), isFalse, reason: '$reason card covers the hole');
}

Future<void> _walkForward(
  WidgetTester tester,
  ShellLayout layout,
  String where,
) async {
  for (int index = 0; index < _titles.length; index++) {
    _expectSpotlightLands(tester, index, layout, where);
    if (index < _titles.length - 1) {
      await _tap(tester, tourNextKey);
    }
  }
}

Future<void> _walkBackward(
  WidgetTester tester,
  ShellLayout layout,
  String where,
) async {
  for (int index = _titles.length - 1; index >= 0; index--) {
    _expectSpotlightLands(tester, index, layout, where);
    if (index > 0) {
      await _tap(tester, tourBackKey);
    }
  }
}

Iterable<SemanticsNode> _semanticsNodes(SemanticsNode node) sync* {
  yield node;
  for (final SemanticsNode child in node.debugListChildrenInOrder(
    DebugSemanticsDumpOrder.traversalOrder,
  )) {
    yield* _semanticsNodes(child);
  }
}

List<String> _semanticsLabels(WidgetTester tester) {
  final SemanticsNode root = tester
      .binding
      .renderViews
      .first
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  return _semanticsNodes(root).map((SemanticsNode node) => node.label).toList();
}

void main() {
  testWidgets('the six tips show their titles, visuals and lines in order', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      await _pumpTour(
        tester,
        platform: TargetPlatform.macOS,
        surface: _sidebarSurface,
      );
      for (int index = 0; index < _titles.length; index++) {
        _expectContent(tester, index, ShellLayout.sidebar, TourMode.firstRun);
        if (index < _titles.length - 1) {
          await _tap(tester, tourNextKey);
        }
      }
      expect(find.text('← → keys'), findsOneWidget);
    });

    await _onPlatform(TargetPlatform.android, () async {
      await _pumpTour(
        tester,
        platform: TargetPlatform.android,
        surface: _bottomBarSurface,
      );
      for (int index = 0; index < _titles.length; index++) {
        _expectContent(tester, index, ShellLayout.bottomBar, TourMode.firstRun);
        if (index < _titles.length - 1) {
          await _tap(tester, tourNextKey);
        }
      }
      expect(find.text('← → keys'), findsNothing);
    });

    await _onPlatform(TargetPlatform.macOS, () async {
      await _pumpTour(
        tester,
        platform: TargetPlatform.macOS,
        surface: _sidebarSurface,
        mode: TourMode.replay,
        initialTip: 5,
      );
      _expectContent(tester, 5, ShellLayout.sidebar, TourMode.replay);
    });
  });

  testWidgets('What a note can hold lists tables and code blocks as working', (
    WidgetTester tester,
  ) async {
    Future<void> expectLists() async {
      _expectTip(tester, 3);
      final Finder works = find.byKey(tourWorksInNotesKey);
      final Finder unsupported = find.byKey(tourNotSupportedKey);
      expect(
        find.descendant(of: works, matching: find.text('WORKS IN NOTES')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: unsupported, matching: find.text('NOT SUPPORTED')),
        findsOneWidget,
      );
      for (final String working in <String>[
        '|',
        'Tables',
        '```',
        'Code blocks',
        'B I',
        'Styles',
      ]) {
        expect(
          find.descendant(of: works, matching: find.text(working)),
          findsOneWidget,
          reason: working,
        );
        expect(
          find.descendant(of: unsupported, matching: find.text(working)),
          findsNothing,
          reason: working,
        );
      }
      for (final String missing in <String>[
        'Files & PDFs',
        'Editing voice or video',
      ]) {
        expect(
          find.descendant(of: unsupported, matching: find.text(missing)),
          findsOneWidget,
          reason: missing,
        );
        expect(
          find.descendant(of: works, matching: find.text(missing)),
          findsNothing,
          reason: missing,
        );
      }
      expect(find.textContaining('Underline'), findsNothing);
      expect(find.text('B I U'), findsNothing);
      final TextStyle? codeStyle = tester
          .widget<Text>(find.descendant(of: works, matching: find.text('```')))
          .style;
      expect(codeStyle?.fontFamily, TypographyTokens.mono);
      expect(codeStyle?.color, FieldNotesColors.light.accentInk);
    }

    await _onPlatform(TargetPlatform.macOS, () async {
      await _pumpTour(
        tester,
        platform: TargetPlatform.macOS,
        surface: _sidebarSurface,
        initialTip: 3,
      );
      await expectLists();
    });

    await _onPlatform(TargetPlatform.android, () async {
      await _pumpTour(
        tester,
        platform: TargetPlatform.android,
        surface: _bottomBarSurface,
        initialTip: 3,
      );
      await expectLists();
    });
  });

  testWidgets(
    'Next, Back, Skip tour and the keyboard move through the tips in first-run and replay modes',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final List<String> calls = await _pumpTour(
          tester,
          platform: TargetPlatform.macOS,
          surface: _sidebarSurface,
        );
        _expectTip(tester, 0);
        await _expectAppBehindIgnoresTaps(
          tester,
          const ValueKey<String>('settings-button'),
        );
        _expectTip(tester, 0);
        await _tap(tester, tourBackKey);
        expect(calls, <String>['backOut']);
        _expectTip(tester, 0);

        for (int index = 1; index < _titles.length; index++) {
          expect(_nextLabel(tester), 'Next');
          await _tap(tester, tourNextKey);
          _expectTip(tester, index);
        }
        expect(_nextLabel(tester), 'Set up');
        await _tap(tester, tourNextKey);
        expect(calls, <String>['backOut', 'finish']);
        _expectTip(tester, 5);

        await _tap(tester, tourBackKey);
        _expectTip(tester, 4);
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        _expectTip(tester, 3);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        _expectTip(tester, 4);
        await _press(tester, LogicalKeyboardKey.enter);
        _expectTip(tester, 5);
        await _press(tester, LogicalKeyboardKey.enter);
        expect(calls, <String>['backOut', 'finish', 'finish']);
        await _press(tester, LogicalKeyboardKey.escape);
        expect(calls, <String>['backOut', 'finish', 'finish', 'skip']);
        await _tap(tester, tourSkipKey);
        expect(calls, <String>['backOut', 'finish', 'finish', 'skip', 'skip']);

        for (int index = 4; index >= 0; index--) {
          await _press(tester, LogicalKeyboardKey.arrowLeft);
          _expectTip(tester, index);
        }
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(calls.last, 'backOut');
        _expectTip(tester, 0);
        await _expectFocusTrapped(tester);
      });

      await _onPlatform(TargetPlatform.android, () async {
        final List<String> calls = await _pumpTour(
          tester,
          platform: TargetPlatform.android,
          surface: _bottomBarSurface,
          mode: TourMode.replay,
        );
        _expectTip(tester, 0);
        await _expectAppBehindIgnoresTaps(
          tester,
          const ValueKey<String>('gear-button'),
        );
        await _tap(tester, tourBackKey);
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(calls, isEmpty);
        _expectTip(tester, 0);
        expect(
          tester.getSemantics(find.byKey(tourBackKey)),
          isSemantics(
            label: 'Back',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );

        for (int index = 1; index < _titles.length; index++) {
          await _tap(tester, tourNextKey);
          _expectTip(tester, index);
        }
        expect(_nextLabel(tester), 'Done');
        await _tap(tester, tourNextKey);
        expect(calls, <String>['finish']);

        await _tap(tester, tourBackKey);
        _expectTip(tester, 4);
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        _expectTip(tester, 3);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        _expectTip(tester, 4);
        await _press(tester, LogicalKeyboardKey.enter);
        _expectTip(tester, 5);
        await _press(tester, LogicalKeyboardKey.enter);
        expect(calls, <String>['finish', 'finish']);
        await _press(tester, LogicalKeyboardKey.escape);
        expect(calls, <String>['finish', 'finish', 'skip']);
        await _tap(tester, tourSkipKey);
        expect(calls, <String>['finish', 'finish', 'skip', 'skip']);
        await _expectFocusTrapped(tester);
      });
    },
  );

  testWidgets(
    'the spotlight lands on each target after a window resize, on a small phone and at Large text',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final ValueNotifier<double> scale = ValueNotifier<double>(1);
        addTearDown(scale.dispose);
        await _pumpTour(
          tester,
          platform: TargetPlatform.macOS,
          surface: _sidebarSurface,
          textScale: scale,
        );
        await _walkForward(tester, ShellLayout.sidebar, '1280 x 800');

        tester.view.physicalSize = _resizedSidebarSurface;
        await _settle(tester);
        await _walkBackward(tester, ShellLayout.sidebar, '1000 x 700');

        scale.value = _largeText;
        await _settle(tester);
        await _walkForward(tester, ShellLayout.sidebar, 'Large text sidebar');
      });

      await _onPlatform(TargetPlatform.android, () async {
        final ValueNotifier<double> scale = ValueNotifier<double>(1);
        addTearDown(scale.dispose);
        await _pumpTour(
          tester,
          platform: TargetPlatform.android,
          surface: _smallPhoneSurface,
          textScale: scale,
        );
        await _walkForward(tester, ShellLayout.bottomBar, '360 x 640');

        scale.value = _largeText;
        await _settle(tester);
        await _walkBackward(tester, ShellLayout.bottomBar, 'Large text phone');
      });
    },
  );

  testWidgets(
    'the tip card is a dialog named by its title and the scrim is hidden from screen readers',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpTour(
          tester,
          platform: TargetPlatform.macOS,
          surface: _sidebarSurface,
        );
        expect(
          tester.getSemantics(_card),
          isSemantics(label: _titles[0], scopesRoute: true, namesRoute: true),
        );
        await _tap(tester, tourNextKey);
        expect(
          tester.getSemantics(_card),
          isSemantics(label: _titles[1], scopesRoute: true, namesRoute: true),
        );
        expect(
          find.ancestor(
            of: find.byKey(tourScrimKey),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );
        final List<String> labels = _semanticsLabels(tester);
        expect(labels, contains(_titles[1]));
        expect(labels, containsAll(<String>['Skip tour', 'Back', 'Next']));
        expect(labels, isNot(contains('Settings')));
      });

      await _onPlatform(TargetPlatform.android, () async {
        await _pumpTour(
          tester,
          platform: TargetPlatform.android,
          surface: _bottomBarSurface,
        );
        expect(
          tester.getSemantics(_card),
          isSemantics(label: _titles[0], scopesRoute: true, namesRoute: true),
        );
        final List<String> labels = _semanticsLabels(tester);
        expect(labels, containsAll(<String>['Skip tour', 'Back', 'Next']));
        expect(labels, isNot(contains('Settings')));
        expect(labels, isNot(contains('New entry')));
      });
      semantics.dispose();
    },
  );

  testWidgets(
    'the sidebar tip card is 344 wide and the spotlight ring is cream inside coral',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpTour(
          tester,
          platform: TargetPlatform.macOS,
          surface: _sidebarSurface,
        );
        expect(tester.getSize(_card).width, 344);

        final TourSpotlightPainter painter = _painter(tester);
        final Rect hole = painter.hole!;
        expect(painter.radius, 16);
        final RRect inner = RRect.fromRectAndRadius(
          hole,
          const Radius.circular(16),
        );
        final RRect cream = RRect.fromRectAndRadius(
          hole.inflate(2),
          const Radius.circular(18),
        );
        final RRect coral = RRect.fromRectAndRadius(
          hole.inflate(4.5),
          const Radius.circular(20.5),
        );
        expect(
          tester.renderObject(find.byKey(tourScrimKey)),
          paints
            ..path(
              color: const Color(0x8F211810),
              includes: <Offset>[const Offset(2, 2), const Offset(1270, 790)],
              excludes: <Offset>[hole.center],
            )
            ..drrect(outer: cream, inner: inner, color: const Color(0xFFFFF5EA))
            ..drrect(outer: coral, inner: cream, color: Palette.coral),
        );
      });
    },
  );
}
