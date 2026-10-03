import 'dart:ui' as ui;

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_focus_stepper.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/garden/support/garden_harness.dart' show dayOf;
import '../states/shell_states.dart';
import '../support/a11y_rules.dart';
import '../support/a11y_state.dart';

Future<List<String>> _idsIn(
  WidgetTester tester,
  List<A11yState> states,
  String id,
) async {
  final A11yStateResult result = await runA11yState(
    tester,
    states.singleWhere((A11yState state) => state.id == id),
  );
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => <String>[
      for (final A11yFinding finding in findings) finding.id,
    ],
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

void _expectNone(
  List<String> ids,
  String rule,
  String state,
  List<String> labels,
) {
  for (final String label in labels) {
    final String prefix = '$rule | $state | $label';
    expect(
      ids.where((String id) => id.startsWith(prefix)),
      isEmpty,
      reason: prefix,
    );
  }
}

List<SemanticsNode> _nodes(
  WidgetTester tester,
  bool Function(SemanticsNode node) test,
) => find.semantics.byPredicate(test).evaluate().toList();

const List<String> _dockLabels = <String>[
  meadowYearPickerLabel,
  meadowTimeButtonLabel,
  meadowDetailsLabel,
  meadowFullScreenLabel,
];

const List<Key> _dockKeys = <Key>[
  meadowYearPickerButtonKey,
  meadowTimeButtonKey,
  meadowDetailsButtonKey,
  meadowFullScreenButtonKey,
];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final List<String> _tabLabels = <String>[
  ShellDestination.today.label,
  ShellDestination.calendar.label,
  'New entry',
  ShellDestination.garden.label,
  ShellDestination.search.label,
];

void _expectPressable(WidgetTester tester, String label, double minimum) {
  final List<SemanticsNode> nodes = _nodes(
    tester,
    (SemanticsNode node) => node.label == label,
  );
  expect(nodes, hasLength(1), reason: label);
  expect(
    nodes.single.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: label,
  );
  final Size size = nodes.single.rect.size;
  expect(
    size.width >= minimum - 0.01 && size.height >= minimum - 0.01,
    isTrue,
    reason: '$label $size',
  );
}

void main() {
  testWidgets('the tabs and + are 48 dp and the settings gear is 44', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      shellStates,
      'a1-today-empty',
    );
    _expectNone(ids, 'small-target', 'a1-today-empty', <String>[
      for (final String label in _tabLabels) '$label |',
    ]);
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final String label in _tabLabels) {
      _expectPressable(tester, label, 48);
    }
    _expectPressable(tester, ShellDestination.settings.label, 44);
    handle.dispose();
  });

  testWidgets('the garden describes its plot and reads each tally once', (
    WidgetTester tester,
  ) async {
    await _idsIn(tester, shellStates, 'a7-garden-blooms');
    final SemanticsHandle handle = tester.ensureSemantics();
    final Finder stage = find.byType(MeadowStage);
    final Size meadow = tester.getSize(stage);
    expect(
      _nodes(
        tester,
        (SemanticsNode node) =>
            node.label ==
                meadowStageLabel(tester.widget<MeadowStage>(stage).year) &&
            (node.rect.width - meadow.width).abs() < 1 &&
            (node.rect.height - meadow.height).abs() < 1,
      ),
      isNotEmpty,
    );
    expect(
      _nodes(tester, (SemanticsNode node) => node.label == '1 Grateful'),
      isEmpty,
    );

    await tester.tap(find.byKey(meadowDetailsButtonKey));
    await _settle(tester);
    expect(
      _nodes(tester, (SemanticsNode node) => node.label == '1 Grateful'),
      hasLength(1),
    );
    expect(
      _nodes(tester, (SemanticsNode node) => node.label == 'Grateful'),
      isEmpty,
    );
    handle.dispose();
  });

  testWidgets('the meadow dock and stepper controls are labelled and large '
      'enough', (WidgetTester tester) async {
    final List<String> ids = await _idsIn(
      tester,
      shellStates,
      'a7-garden-blooms',
    );
    expect(ids, isEmpty);
    _expectNone(ids, 'small-target', 'a7-garden-blooms', <String>[
      for (final String label in _dockLabels) '$label |',
    ]);
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final String label in _dockLabels) {
      _expectPressable(tester, label, 48);
    }

    await tester.tap(find.byKey(meadowDetailsButtonKey));
    await _settle(tester);
    await tester.ensureVisible(find.text('Sep'));
    await tester.pump();
    await tester.tap(find.text('Sep'));
    await _settle(tester);
    expect(find.byKey(meadowFocusStepperKey), findsOneWidget);
    for (final String label in <String>[
      'Previous month',
      'Next month',
      meadowFocusCloseLabel,
    ]) {
      _expectPressable(tester, label, 48);
    }
    handle.dispose();
    await tester.pumpWidget(const SizedBox());

    tester.view.physicalSize = const Size(1140, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int retryCount, Object error) => null,
        overrides: <Override>[
          allDaysProvider.overrideWith(
            (Ref ref) => Stream<List<Day>>.value(<Day>[
              dayOf('2026-09-23'),
              dayOf('2026-09-24', mood: Mood.grateful),
            ]),
          ),
          journalEntryCountsProvider.overrideWith(
            (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{
              '2026-09-23': 1,
              '2026-09-24': 1,
            }),
          ),
          meadowKeyProvider.overrideWith((Ref ref) async => 24601),
          skyClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 9, 25, 15, 30),
          ),
          skyLocationProvider.overrideWith(
            (Ref ref) async => resolveSkyLocation(
              'America/Edmonton',
              const Duration(hours: -6),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.macOS),
          home: const Scaffold(body: GardenScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final SemanticsHandle mac = tester.ensureSemantics();
    for (final String label in _dockLabels) {
      final List<SemanticsNode> nodes = _nodes(
        tester,
        (SemanticsNode node) => node.label == label,
      );
      expect(nodes, hasLength(1), reason: label);
      final SemanticsData data = nodes.single.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: label);
      expect(data.flagsCollection.isButton, isTrue, reason: label);
      expect(
        data.flagsCollection.isFocused,
        isNot(ui.Tristate.none),
        reason: label,
      );
    }

    final Set<Key> ringed = <Key>{};
    for (int press = 0; press < 8; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      for (final Key key in _dockKeys) {
        if (find
            .descendant(of: find.byKey(key), matching: find.byKey(focusRingKey))
            .evaluate()
            .isNotEmpty) {
          ringed.add(key);
        }
      }
    }
    expect(ringed, containsAll(_dockKeys));
    mac.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
