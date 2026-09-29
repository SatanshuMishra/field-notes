import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/onboarding/setup/setup_reminder_step.dart';
import 'package:field_notes/features/onboarding/setup/setup_storage_step.dart';
import 'package:field_notes/features/onboarding/setup/setup_week_step.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show shellOverrides;
import '../../features/settings/support/fake_settings_repository.dart';
import '../support/a11y_state.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const List<ShellLayout> _layouts = <ShellLayout>[
  ShellLayout.sidebar,
  ShellLayout.bottomBar,
];

const String _beginLabel = 'Let’s begin';
const String _skipTourLabel = 'Skip how it works';
const String _reminderTitle = 'A gentle daily nudge?';
const String _weekTitle = 'Your week starts on';
const String _storageTitle = 'Where should entries live?';
const String _summaryTitle = 'You’re all set';
const String _saveError = 'Couldn’t save your choices. Try again.';
const String _setUpLabel = 'Set up';
const String _doneLabel = 'Done';

const List<String> _tipTitles = <String>[
  'Four pages, one journal',
  'Plant a bloom each day',
  'Capture a moment',
  'What a note can hold',
  'Past days stay open',
  'Settings live here',
];

class _FailingSetupWrites extends FakeSettingsRepository {
  _FailingSetupWrites() : super(storedValues: false);

  @override
  Future<void> setReminderEnabled(bool value) async {
    throw StateError('disk full');
  }
}

FakeSettingsRepository _freshInstall() =>
    FakeSettingsRepository(storedValues: false);

FakeSettingsRepository _onboarded() => FakeSettingsRepository(
  initial: AppSettings.defaults.copyWith(
    onboardingStatus: OnboardingStatus.done,
  ),
);

class _Screen {
  const _Screen(
    this.name, {
    required this.reach,
    required this.proof,
    this.stateful = const <A11yStatefulControl>[],
    this.settings = _freshInstall,
  });

  final String name;
  final Future<void> Function(WidgetTester tester) reach;
  final List<A11yProof> Function(ShellLayout layout) proof;
  final List<A11yStatefulControl> stateful;
  final FakeSettingsRepository Function() settings;
}

String _layoutName(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => 'sidebar',
  ShellLayout.bottomBar => 'bottom-bar',
};

List<Override> _overrides(FakeSettingsRepository settings) => <Override>[
  for (final Override override in shellOverrides())
    if (override.origin != settingsRepositoryProvider) override,
  settingsRepositoryProvider.overrideWithValue(settings),
];

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ShellLayout layout,
  _Screen screen,
) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(screen.settings()),
        child: const FieldNotesApp(),
      ),
    );
    await _settle(tester);
    await screen.reach(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _stay(WidgetTester tester) async {}

Future<void> _walkTips(WidgetTester tester, int tip) async {
  for (int step = 0; step < tip; step++) {
    await _tap(tester, find.byKey(tourNextKey));
  }
}

Future<void> _toTip(WidgetTester tester, int tip) async {
  await _tap(tester, find.text(_beginLabel));
  await _walkTips(tester, tip);
}

Future<void> _toReplayLastTip(WidgetTester tester) async {
  ProviderScope.containerOf(
    tester.element(find.byType(AppShell)),
  ).read(onboardingControllerProvider.notifier).replayTour();
  await _settle(tester);
  await _walkTips(tester, _tipTitles.length - 1);
}

Future<void> _toReminder(WidgetTester tester) =>
    _tap(tester, find.text(_skipTourLabel));

Future<void> _toOther(WidgetTester tester) async {
  await _toReminder(tester);
  await _tap(tester, find.byKey(setupReminderPresetKey(ReminderPreset.other)));
  await tester.ensureVisible(find.byType(SettingsTimeField));
  await _settle(tester);
}

Future<void> _toWeek(WidgetTester tester) async {
  await _toReminder(tester);
  await _tap(tester, find.byKey(setupPrimaryKey));
}

Future<void> _toStorage(WidgetTester tester) async {
  await _toWeek(tester);
  await _tap(tester, find.byKey(setupPrimaryKey));
}

Future<void> _toSummary(WidgetTester tester) async {
  await _toStorage(tester);
  await _tap(tester, find.byKey(setupPrimaryKey));
}

Future<void> _toSaveError(WidgetTester tester) async {
  await _toSummary(tester);
  await _tap(tester, find.byKey(setupPrimaryKey));
}

A11yProof _shellProof(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => A11yProof(find.byType(SidebarShell)),
  ShellLayout.bottomBar => A11yProof(find.byType(BottomBarShell)),
};

A11yProof _surfaceProof(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => A11yProof(find.byKey(onboardingCardKey)),
  ShellLayout.bottomBar => A11yProof(find.byKey(onboardingPageKey)),
};

final Finder _shownTourCard = find.ancestor(
  of: find.byKey(tourCardKey),
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is AnimatedOpacity && widget.opacity == 1,
    description: 'a fully shown tour card',
  ),
);

List<A11yProof> Function(ShellLayout layout) _tipProof(
  int tip, {
  String? next,
}) =>
    (ShellLayout layout) => <A11yProof>[
      _shellProof(layout),
      A11yProof(_shownTourCard),
      A11yProof(
        find.descendant(
          of: find.byKey(tourCardKey),
          matching: find.text(_tipTitles[tip]),
        ),
      ),
      if (next != null)
        A11yProof(
          find.descendant(
            of: find.byKey(tourNextKey),
            matching: find.text(next),
          ),
        ),
    ];

List<A11yProof> Function(ShellLayout layout) _setupProof(String text) =>
    (ShellLayout layout) => <A11yProof>[
      _shellProof(layout),
      _surfaceProof(layout),
      A11yProof(find.byType(OnboardingSetup)),
      A11yProof(find.text(text)),
    ];

final List<A11yStatefulControl> _reminderStateful = <A11yStatefulControl>[
  A11yStatefulControl.finder(
    find.byType(SettingsToggle),
    A11yStateKind.toggled,
  ),
  for (final ReminderPreset preset in ReminderPreset.values)
    A11yStatefulControl.finder(
      find.byKey(setupReminderPresetKey(preset)),
      A11yStateKind.selected,
    ),
];

final List<A11yStatefulControl> _weekStateful = <A11yStatefulControl>[
  for (final WeekStart start in WeekStart.values)
    A11yStatefulControl.finder(
      find.byKey(setupWeekOptionKey(start)),
      A11yStateKind.checked,
    ),
];

final List<A11yStatefulControl> _storageStateful = <A11yStatefulControl>[
  A11yStatefulControl.finder(
    find.byKey(setupStorageDeviceKey),
    A11yStateKind.checked,
  ),
  A11yStatefulControl.finder(
    find.byKey(setupStorageServerKey),
    A11yStateKind.checked,
  ),
];

final List<_Screen> _screens = <_Screen>[
  _Screen(
    'welcome',
    reach: _stay,
    proof: (ShellLayout layout) => <A11yProof>[
      _shellProof(layout),
      _surfaceProof(layout),
      A11yProof(find.byType(OnboardingWelcome)),
      A11yProof(find.text(_beginLabel)),
    ],
  ),
  for (int tip = 0; tip < _tipTitles.length; tip++)
    _Screen(
      'tip-${tip + 1}',
      reach: (WidgetTester tester) => _toTip(tester, tip),
      proof: _tipProof(
        tip,
        next: tip == _tipTitles.length - 1 ? _setUpLabel : null,
      ),
    ),
  _Screen(
    'reminder-on',
    reach: _toReminder,
    proof: _setupProof(_reminderTitle),
    stateful: _reminderStateful,
  ),
  _Screen(
    'reminder-other',
    reach: _toOther,
    proof: (ShellLayout layout) => <A11yProof>[
      ..._setupProof(_reminderTitle)(layout),
      A11yProof(find.byType(SettingsTimeField)),
    ],
    stateful: _reminderStateful,
  ),
  _Screen(
    'week',
    reach: _toWeek,
    proof: _setupProof(_weekTitle),
    stateful: _weekStateful,
  ),
  _Screen(
    'storage',
    reach: _toStorage,
    proof: _setupProof(_storageTitle),
    stateful: _storageStateful,
  ),
  _Screen('summary', reach: _toSummary, proof: _setupProof(_summaryTitle)),
  _Screen(
    'summary-save-error',
    reach: _toSaveError,
    proof: (ShellLayout layout) => <A11yProof>[
      ..._setupProof(_summaryTitle)(layout),
      A11yProof(find.text(_saveError)),
    ],
    settings: _FailingSetupWrites.new,
  ),
  _Screen(
    'replay-last-tip',
    reach: _toReplayLastTip,
    proof: _tipProof(_tipTitles.length - 1, next: _doneLabel),
    settings: _onboarded,
  ),
];

final List<A11yState> onboardingStates = <A11yState>[
  for (final (int index, _Screen screen) in _screens.indexed)
    for (final (int side, ShellLayout layout) in _layouts.indexed)
      A11yState(
        id:
            'o${index * _layouts.length + side + 1}-'
            '${screen.name}-${_layoutName(layout)}',
        pump: (WidgetTester tester) => _pumpScreen(tester, layout, screen),
        proof: screen.proof(layout),
        stateful: screen.stateful,
      ),
];
