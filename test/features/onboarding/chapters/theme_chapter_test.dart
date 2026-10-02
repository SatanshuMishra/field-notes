import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const String _kicker = 'and you';
const String _title = 'Daylight or lamplight?';
const String _failure = 'Could not save your appearance.';

typedef _Option = ({
  Appearance appearance,
  String label,
  String caption,
  String semantics,
});

const List<_Option> _sidebarOptions = <_Option>[
  (
    appearance: Appearance.light,
    label: 'Light',
    caption: 'daylight',
    semantics: 'Light, daylight',
  ),
  (
    appearance: Appearance.dark,
    label: 'Dark',
    caption: 'lamplight',
    semantics: 'Dark, lamplight',
  ),
  (
    appearance: Appearance.system,
    label: 'System',
    caption: 'follows device',
    semantics: 'System, follows device',
  ),
];

const List<_Option> _bottomBarOptions = <_Option>[
  (
    appearance: Appearance.light,
    label: 'Light',
    caption: 'Daylight · warm paper',
    semantics: 'Light, Daylight, warm paper',
  ),
  (
    appearance: Appearance.dark,
    label: 'Dark',
    caption: 'Lamplight · easy at night',
    semantics: 'Dark, Lamplight, easy at night',
  ),
  (
    appearance: Appearance.system,
    label: 'System',
    caption: 'Follows your phone',
    semantics: 'System, Follows your phone',
  ),
];

List<_Option> _optionsFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarOptions,
  ShellLayout.bottomBar => _bottomBarOptions,
};

class _FailingAppearanceWrites extends FakeSettingsRepository {
  _FailingAppearanceWrites() : super(storedValues: false);

  @override
  Future<void> setAppearance(Appearance value) async {
    throw StateError('The appearance could not be saved.');
  }
}

Future<void> _onLayout(ShellLayout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void _onLightDevice(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

void _sizeFor(WidgetTester tester, ShellLayout layout) {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<Override> _overrides(FakeSettingsRepository settings) {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(settings),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    onboardingCountryCodeProvider.overrideWithValue('US'),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openTheme(
  WidgetTester tester,
  ShellLayout layout,
  FakeSettingsRepository settings,
) async {
  _sizeFor(tester, layout);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(settings),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  expect(find.byType(OpeningChapter), findsOneWidget);
  _container(tester).read(onboardingControllerProvider.notifier).skipToSetup();
  await _settle(tester);
  expect(find.byType(ThemeChapter), findsOneWidget);
}

Future<void> _pumpStill(WidgetTester tester, ShellLayout layout) async {
  _sizeFor(tester, layout);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: shellOverrides(),
      child: MaterialApp(
        theme: fieldNotesTheme(platform: defaultTargetPlatform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Material(child: ThemeChapter(layout: layout)),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)));

MaterialApp _app(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp));

ThemeData _appTheme(WidgetTester tester) => tester
    .widget<AnimatedTheme>(
      find
          .descendant(
            of: find.byType(MaterialApp),
            matching: find.byType(AnimatedTheme),
          )
          .first,
    )
    .data;

Iterable<double> _opacitiesAbove(WidgetTester tester, Finder finder) => tester
    .widgetList<Opacity>(
      find.ancestor(of: finder, matching: find.byType(Opacity)),
    )
    .map((Opacity opacity) => opacity.opacity);

void _expectShowing(WidgetTester tester, Brightness brightness) {
  final FieldNotesColors expected = switch (brightness) {
    Brightness.light => FieldNotesColors.light,
    Brightness.dark => FieldNotesColors.dark,
  };
  for (final Finder place in <Finder>[
    find.byType(ThemeChapter),
    find.byType(AppShell),
  ]) {
    final BuildContext context = tester.element(place);
    final FieldNotesColors colors = FieldNotesColors.of(context);
    expect(Theme.of(context).brightness, brightness);
    expect(colors.page, expected.page);
    expect(colors.panelTop, expected.panelTop);
    expect(colors.cardWarm, expected.cardWarm);
    expect(colors.ink, expected.ink);
  }
}

void _expectSelected(
  WidgetTester tester,
  ShellLayout layout,
  Appearance selected,
) {
  for (final _Option option in _optionsFor(layout)) {
    final Finder control = find.byKey(themeChoiceKey(option.appearance));
    final bool on = option.appearance == selected;
    expect(
      find.descendant(of: control, matching: find.text(option.label)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: control, matching: find.text(option.caption)),
      findsOneWidget,
    );
    expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(control), switch (layout) {
      ShellLayout.sidebar => isSemantics(
        label: option.semantics,
        isButton: true,
        isSelected: on,
        hasTapAction: true,
      ),
      ShellLayout.bottomBar => isSemantics(
        label: option.semantics,
        hasCheckedState: true,
        isChecked: on,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    });
  }
}

Future<void> _choose(WidgetTester tester, Appearance appearance) async {
  await tester.tap(find.byKey(themeChoiceKey(appearance)));
  await tester.idle();
  await tester.pump();
}

void main() {
  testWidgets('theme saves the choice and the app recolours at once', (
    WidgetTester tester,
  ) async {
    _onLightDevice(tester);
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final FakeSettingsRepository settings = FakeSettingsRepository(
          storedValues: false,
        );
        await _openTheme(tester, layout, settings);

        expect(find.text(_kicker), findsOneWidget);
        expect(find.text(_title), findsOneWidget);
        _expectSelected(tester, layout, Appearance.light);
        _expectShowing(tester, Brightness.light);
        expect(
          find.byKey(themePreviewKey),
          layout == ShellLayout.bottomBar ? findsOneWidget : findsNothing,
        );

        await _choose(tester, Appearance.dark);

        expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
        expect(_app(tester).themeMode, ThemeMode.dark);
        expect(_appTheme(tester).brightness, Brightness.dark);
        _expectSelected(tester, layout, Appearance.dark);
        expect(find.text(_failure), findsNothing);
        await tester.pump(const Duration(milliseconds: 300));
        _expectShowing(tester, Brightness.dark);

        expect(
          await _container(tester)
              .read(settingsControllerProvider)
              .setAppearance(Appearance.system),
          isA<SettingsWriteSucceeded>(),
        );
        await tester.idle();
        await tester.pump();

        _expectSelected(tester, layout, Appearance.system);
        expect(settings.appearanceWrites, <Appearance>[
          Appearance.dark,
          Appearance.system,
        ]);
        await tester.pump(const Duration(milliseconds: 300));
        _expectShowing(tester, Brightness.light);
        await _unmount(tester);

        final _FailingAppearanceWrites failing = _FailingAppearanceWrites();
        await _openTheme(tester, layout, failing);
        _expectSelected(tester, layout, Appearance.light);
        expect(find.text(_failure), findsNothing);

        await _choose(tester, Appearance.dark);

        expect(find.text(_failure), findsOneWidget);
        expect(failing.appearanceWrites, isEmpty);
        _expectSelected(tester, layout, Appearance.light);
        expect(_app(tester).themeMode, ThemeMode.light);
        await tester.pump(const Duration(milliseconds: 300));
        _expectShowing(tester, Brightness.light);
        await _unmount(tester);
      });
    }
  });

  testWidgets('theme skips every entrance with reduce motion', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpStill(tester, layout);

        expect(tester.hasRunningAnimations, isFalse);
        expect(_opacitiesAbove(tester, find.text(_title)), everyElement(1));
        for (final _Option option in _optionsFor(layout)) {
          expect(
            _opacitiesAbove(
              tester,
              find.byKey(themeChoiceKey(option.appearance)),
            ),
            everyElement(1),
          );
        }
        _expectSelected(tester, layout, Appearance.light);
        await _unmount(tester);
      });
    }
  });
}
