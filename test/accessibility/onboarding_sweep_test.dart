import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'states/onboarding_states.dart';
import 'support/a11y_state.dart';
import 'support/reading_order.dart';

const Size _smallestSidebar = Size(873, 600);
const Size _smallestBottomBar = Size(360, 640);
const List<double> _textScales = <double>[1, 1.3];
const int _maxPresses = 60;
const String _sidebarSuffix = '-sidebar';

const List<String> _layoutNames = <String>['sidebar', 'bottom-bar'];

final Map<String, bool Function(OnboardingFlow flow)> _v7States =
    <String, bool Function(OnboardingFlow flow)>{
      'opening-unplanted': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.opening,
        (OnboardingDraft draft) => !draft.planted,
      ),
      'opening-grown': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.opening,
        (OnboardingDraft draft) => draft.planted && draft.grown,
      ),
      'day-happy': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.day,
        (OnboardingDraft draft) => draft.mood == Mood.happy,
      ),
      'day-calm': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.day,
        (OnboardingDraft draft) => draft.mood != Mood.happy,
      ),
      'moment-empty': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.moment,
        (OnboardingDraft draft) => draft.noteText.isEmpty,
      ),
      'moment-saved': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.moment,
        (OnboardingDraft draft) =>
            draft.noteText.isNotEmpty && draft.noteSave == NoteSaveState.saved,
      ),
      'moment-failed': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.moment,
        (OnboardingDraft draft) =>
            draft.noteSave == NoteSaveState.failed && draft.noteError != null,
      ),
      'month-empty': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.month,
        (OnboardingDraft draft) => draft.monthFill == 0,
      ),
      'month-full': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.month,
        (OnboardingDraft draft) => draft.monthFill == 1,
      ),
      'year-playing': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.year,
        (OnboardingDraft draft) => draft.yearDay > 0 && draft.yearDay < 365,
      ),
      'year-finished': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.year,
        (OnboardingDraft draft) => draft.yearDay == 365,
      ),
      'theme': (OnboardingFlow flow) =>
          _running(flow, OnboardingChapter.theme, (OnboardingDraft _) => true),
      'reminder-time': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.reminder,
        (OnboardingDraft draft) => draft.reminder.time != null,
      ),
      'reminder-off': (OnboardingFlow flow) => _running(
        flow,
        OnboardingChapter.reminder,
        (OnboardingDraft draft) => draft.reminder == ReminderChoice.off,
      ),
      'week': (OnboardingFlow flow) =>
          _running(flow, OnboardingChapter.week, (OnboardingDraft _) => true),
      'map-end': (OnboardingFlow flow) =>
          _running(flow, OnboardingChapter.tour, (OnboardingDraft _) => true),
      'map-replay': (OnboardingFlow flow) => flow is OnboardingFlowMap,
    };

bool _running(
  OnboardingFlow flow,
  OnboardingChapter chapter,
  bool Function(OnboardingDraft draft) holds,
) => switch (flow) {
  OnboardingFlowRunning(
    chapter: final OnboardingChapter shown,
    :final OnboardingDraft draft,
  ) =>
    shown == chapter && holds(draft),
  OnboardingFlowHidden() || OnboardingFlowMap() => false,
};

OnboardingFlow _flowOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(onboardingControllerProvider);

void _keyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

List<SemanticsNode> _inReadingOrder(WidgetTester tester) {
  final List<SemanticsNode> order = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    if (node.isMergedIntoParent) {
      return;
    }
    order.add(node);
    if (node.mergeAllDescendantsIntoThisNode) {
      return;
    }
    for (final SemanticsNode child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      walk(child);
    }
  }

  for (final RenderView view in tester.binding.renderViews) {
    final SemanticsNode? root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) {
      walk(root);
    }
  }
  return order;
}

bool _isControl(SemanticsNode node) {
  final SemanticsData data = node.getSemanticsData();
  return !data.flagsCollection.isHidden &&
      !node.isInvisible &&
      (data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress) ||
          data.hasAction(SemanticsAction.increase) ||
          data.hasAction(SemanticsAction.decrease) ||
          data.flagsCollection.isTextField ||
          data.flagsCollection.isSlider);
}

String _name(SemanticsNode node) {
  final String label = node.getSemanticsData().label.replaceAll('\n', ' ');
  return label.isEmpty ? '#${node.id}' : label;
}

final class _Stop {
  const _Stop({required this.node, required this.ringed});

  final SemanticsNode node;
  final bool ringed;
}

SemanticsNode _semanticsOf(WidgetTester tester, FocusNode focus) {
  final BuildContext? context = focus.context;
  if (context == null) {
    throw StateError('${focus.debugLabel} is focused without a context');
  }
  return tester.getSemantics(
    find.byElementPredicate((Element element) => identical(element, context)),
  );
}

bool _showsRing(FocusNode focus) {
  final BuildContext? context = focus.context;
  final State<FocusRing>? ring = context
      ?.findAncestorStateOfType<State<FocusRing>>();
  if (ring == null) {
    return false;
  }
  return find
      .descendant(
        of: find.byElementPredicate(
          (Element element) => identical(element, ring.context),
        ),
        matching: find.byKey(focusRingKey),
      )
      .evaluate()
      .isNotEmpty;
}

Future<_Stop> _tab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final FocusNode focus = FocusManager.instance.primaryFocus!;
  return _Stop(node: _semanticsOf(tester, focus), ringed: _showsRing(focus));
}

Future<List<_Stop>> _lap(WidgetTester tester) async {
  final _Stop anchor = await _tab(tester);
  final List<_Stop> lap = <_Stop>[anchor];
  for (int press = 0; press < _maxPresses; press++) {
    final _Stop next = await _tab(tester);
    if (identical(next.node, anchor.node)) {
      return lap;
    }
    lap.add(next);
  }
  fail(
    'Tab never came back to ${_name(anchor.node)} within $_maxPresses '
    'presses: ${lap.map((_Stop stop) => _name(stop.node)).join(', ')}',
  );
}

List<SemanticsNode> _rotated(List<SemanticsNode> nodes, SemanticsNode first) {
  final int start = nodes.indexOf(first);
  return <SemanticsNode>[...nodes.sublist(start), ...nodes.sublist(0, start)];
}

void _expectLapInReadingOrder(WidgetTester tester, List<_Stop> lap) {
  final List<SemanticsNode> order = _inReadingOrder(tester);
  final List<SemanticsNode> visited = <SemanticsNode>[
    for (final _Stop stop in lap) stop.node,
  ];
  final List<String> visitedNames = visited.map(_name).toList();
  expect(
    visited.toSet(),
    hasLength(visited.length),
    reason: 'one Tab lap visits a control twice: $visitedNames',
  );
  expect(
    <String>[
      for (final SemanticsNode node in order)
        if (_isControl(node) && !visited.contains(node)) _name(node),
    ],
    isEmpty,
    reason: 'Tab never reaches these controls; it visits $visitedNames',
  );
  expect(
    <String>[
      for (final _Stop stop in lap)
        if (!stop.ringed) _name(stop.node),
    ],
    isEmpty,
    reason: 'these controls show no FocusRing while focused',
  );
  final List<SemanticsNode> readingOrder = <SemanticsNode>[
    for (final SemanticsNode node in order)
      if (visited.contains(node)) node,
  ];
  expect(
    visitedNames,
    _rotated(readingOrder, visited.first).map(_name).toList(),
    reason: 'Tab leaves reading order',
  );
}

void main() {
  a11ySweepArea(
    area: 'onboarding',
    groupName: 'every onboarding state loads and matches its baseline',
    states: onboardingStates,
  );

  group('every onboarding state keeps each node in reading order', () {
    for (final A11yState state in onboardingStates) {
      testWidgets(state.id, (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await state.pump(tester);
        expect(
          readingOrderOrphans(tester),
          isEmpty,
          reason:
              '${state.id}: these nodes are in the hit-test tree but no '
              'node lists them in reading order',
        );
        handle.dispose();
      });
    }
  });

  group('on macOS Tab reaches every onboarding control with a focus ring', () {
    for (final A11yState state in onboardingStates) {
      if (!state.id.endsWith(_sidebarSuffix)) {
        continue;
      }
      testWidgets(state.id, (WidgetTester tester) async {
        _keyboardHighlight();
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await state.pump(tester);
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          final List<_Stop> lap = await _lap(tester);
          _expectLapInReadingOrder(tester, lap);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          handle.dispose();
        }
      });
    }
  });

  group('the onboarding sweep covers every v7 state on both layouts', () {
    test('and holds no other state', () {
      expect(<String>[
        for (final A11yState state in onboardingStates) state.id,
      ], hasLength(_v7States.length * _layoutNames.length));
    });

    for (final String layout in _layoutNames) {
      for (final MapEntry<String, bool Function(OnboardingFlow flow)> wanted
          in _v7States.entries) {
        testWidgets('${wanted.key} on $layout', (WidgetTester tester) async {
          final RegExp id = RegExp('^o[0-9]+-${wanted.key}-$layout\$');
          final List<A11yState> named = <A11yState>[
            for (final A11yState state in onboardingStates)
              if (id.hasMatch(state.id)) state,
          ];
          expect(named, hasLength(1), reason: 'no single state ${id.pattern}');
          await named.single.pump(tester);
          final OnboardingFlow flow = _flowOf(tester);
          expect(
            wanted.value(flow),
            isTrue,
            reason: '${named.single.id} shows $flow',
          );
        });
      }
    }
  });

  group('every onboarding chapter fits the smallest windows', () {
    final List<A11yState> smallest = onboardingStatesAt(
      sidebar: _smallestSidebar,
      bottomBar: _smallestBottomBar,
    );
    for (final double scale in _textScales) {
      for (final A11yState state in smallest) {
        testWidgets('${state.id} at text scale $scale', (
          WidgetTester tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final List<String> problems = <String>[];
          final FlutterExceptionHandler? report = FlutterError.onError;
          FlutterError.onError = (FlutterErrorDetails details) =>
              problems.add(details.exceptionAsString().split('\n').first);
          try {
            await state.pump(tester);
          } finally {
            FlutterError.onError = report;
          }
          expect(tester.takeException(), isNull);
          expect(
            problems,
            isEmpty,
            reason: '${state.id} at text scale $scale does not lay out',
          );
          expect(find.byType(OnboardingFrame), findsOneWidget);
        });
      }
    }
  });
}
