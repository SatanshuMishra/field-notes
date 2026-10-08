import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/capture/core/capture_test_support.dart' show FakeDraftStore;
import '../features/settings/support/fake_settings_repository.dart';
import '../support/note_editor_driver.dart';
import 'support/app_shell_harness.dart';

const Size _sidebarSurface = Size(1200, 900);
const Size _shortSidebarSurface = Size(1100, 520);
const Size _phoneSurface = Size(440, 900);
const Color _lightPanelTop = Color(0xFFEFE2CE);
const Color _darkPanelTop = Color(0xFF1C1919);

class _SlowSettingsRepository extends FakeSettingsRepository {
  _SlowSettingsRepository({required super.initial});

  @override
  Stream<AppSettings> watch() async* {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    yield* super.watch();
  }
}

FakeSettingsRepository _stored(Appearance appearance) => FakeSettingsRepository(
  initial: AppSettings.defaults.copyWith(appearance: appearance),
);

List<Override> _overrides(FakeSettingsRepository settings) {
  final Set<Object> replaced = <Object>{settingsRepositoryProvider};
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(settings),
    draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
  ];
}

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

void _setDeviceBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpApp(
  WidgetTester tester,
  FakeSettingsRepository settings, {
  Size surface = _sidebarSurface,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(settings),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
}

BuildContext _shellContext(WidgetTester tester) =>
    tester.element(find.byType(AppShell));

ThemeData _theme(WidgetTester tester) => Theme.of(_shellContext(tester));

FieldNotesColors _colors(WidgetTester tester) =>
    FieldNotesColors.of(_shellContext(tester));

void _expectTheme(WidgetTester tester, Brightness brightness) {
  final FieldNotesColors expected = switch (brightness) {
    Brightness.light => FieldNotesColors.light,
    Brightness.dark => FieldNotesColors.dark,
  };
  final FieldNotesColors colors = _colors(tester);
  expect(_theme(tester).brightness, brightness);
  expect(colors.page, expected.page);
  expect(colors.panelTop, expected.panelTop);
  expect(colors.cardWarm, expected.cardWarm);
  expect(colors.ink, expected.ink);
  expect(colors.line, expected.line);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(_shellContext(tester));

Future<void> _switchTo(
  ProviderContainer container,
  Appearance appearance,
) async {
  expect(
    await container.read(settingsControllerProvider).setAppearance(appearance),
    isA<SettingsWriteSucceeded>(),
  );
}

Color? _shellBackground(WidgetTester tester) => tester
    .widget<Scaffold>(
      find
          .descendant(
            of: find.byType(SidebarShell),
            matching: find.byType(Scaffold),
          )
          .first,
    )
    .backgroundColor;

ScrollableState _settingsScrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .ancestor(
            of: find.byKey(settingsTabContentKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  testWidgets('Light and Dark force the theme whatever the device brightness', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      _setDeviceBrightness(tester, Brightness.dark);
      await _pumpApp(tester, _stored(Appearance.light));

      _expectTheme(tester, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await _pumpApp(tester, _stored(Appearance.dark));

      _expectTheme(tester, Brightness.dark);
    });
  });

  testWidgets('System follows the device brightness while the app runs', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      _setDeviceBrightness(tester, Brightness.dark);
      await _pumpApp(tester, _stored(Appearance.system));

      _expectTheme(tester, Brightness.dark);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      _expectTheme(tester, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      _expectTheme(tester, Brightness.dark);
    });
  });

  testWidgets(
    'switching appearance keeps the screen, tab, scroll and composer text',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        _setDeviceBrightness(tester, Brightness.light);
        await _pumpApp(
          tester,
          _stored(Appearance.light),
          surface: _shortSidebarSurface,
        );
        final ProviderContainer container = _container(tester);

        await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
        await _settle(tester);
        await tester.tap(find.byKey(settingsTabKey(SettingsTab.journal)));
        await _settle(tester);
        final ScrollableState scrollable = _settingsScrollable(tester);
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        final double offset = scrollable.position.maxScrollExtent / 2;
        scrollable.position.jumpTo(offset);
        await tester.pump();
        final NavigatorState navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        final Route<dynamic>? route = ModalRoute.of(_shellContext(tester));
        final State<StatefulWidget> shell = tester.state(find.byType(AppShell));
        final State<StatefulWidget> settingsScreen = tester.state(
          find.byType(SettingsScreen),
        );

        await _switchTo(container, Appearance.dark);
        await _settle(tester);

        _expectTheme(tester, Brightness.dark);
        expect(
          container.read(shellNavigationProvider),
          ShellDestination.settings,
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator).first),
          same(navigator),
        );
        expect(ModalRoute.of(_shellContext(tester)), same(route));
        expect(tester.state(find.byType(AppShell)), same(shell));
        expect(tester.state(find.byType(SettingsScreen)), same(settingsScreen));
        expect(
          tester
              .widget<SettingsTabRail>(find.byKey(settingsTabRailKey))
              .selected,
          SettingsTab.journal,
        );
        expect(_settingsScrollable(tester), same(scrollable));
        expect(scrollable.position.pixels, offset);

        await _switchTo(container, Appearance.light);
        await _settle(tester);
        _expectTheme(tester, Brightness.light);
        await tester.tap(find.byKey(const ValueKey<String>('rail-today')));
        await _settle(tester);
        await tester.tap(find.text('Write a note').first);
        await _settle(tester);
        expect(find.byType(TextComposerSheet), findsOneWidget);
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await driver.enterText('evening fog over the river');
        await tester.pump();
        final State<StatefulWidget> composer = tester.state(
          find.byType(TextComposerSheet),
        );

        await _switchTo(container, Appearance.dark);
        await _settle(tester);

        expect(find.byType(TextComposerSheet), findsOneWidget);
        expect(tester.state(find.byType(TextComposerSheet)), same(composer));
        expect(
          Theme.of(tester.element(find.byType(TextComposerSheet))).brightness,
          Brightness.dark,
        );
        _expectTheme(tester, Brightness.dark);
        expect(driver.source, 'evening fog over the river');
        expect(tester.state(find.byType(AppShell)), same(shell));
      });
    },
  );

  testWidgets(
    'the switch blends the page colour before settling on the new theme',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        _setDeviceBrightness(tester, Brightness.light);
        await _pumpApp(tester, _stored(Appearance.light));
        expect(_shellBackground(tester), _lightPanelTop);

        await _switchTo(_container(tester), Appearance.dark);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final Color? blending = _shellBackground(tester);
        expect(blending, isNot(_lightPanelTop));
        expect(blending, isNot(_darkPanelTop));

        await tester.pump(const Duration(milliseconds: 150));

        expect(_shellBackground(tester), _darkPanelTop);
      });
    },
  );

  testWidgets(
    'the first painted frame already uses the saved dark appearance',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        _setDeviceBrightness(tester, Brightness.light);
        tester.view.physicalSize = _sidebarSurface;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _overrides(
              _SlowSettingsRepository(
                initial: AppSettings.defaults.copyWith(
                  appearance: Appearance.dark,
                ),
              ),
            ),
            child: const FieldNotesApp(),
          ),
        );

        int blankFrames = 0;
        int? firstAppFrame;
        for (int frame = 0; frame < 30; frame++) {
          if (find.byType(MaterialApp).evaluate().isEmpty) {
            expect(find.byType(AppShell), findsNothing);
            blankFrames++;
          } else {
            firstAppFrame ??= frame;
            _expectTheme(tester, Brightness.dark);
            expect(_shellBackground(tester), _darkPanelTop);
          }
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(blankFrames, greaterThan(0));
        expect(firstAppFrame, isNotNull);
        _expectTheme(tester, Brightness.dark);
      });
    },
  );

  testWidgets('Android system bar icons follow the theme', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      _setDeviceBrightness(tester, Brightness.light);
      await _pumpApp(tester, _stored(Appearance.light), surface: _phoneSurface);

      SystemUiOverlayStyle region() => tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value;

      expect(_theme(tester).brightness, Brightness.light);
      _expectSystemBars(region(), Brightness.dark);
      _expectSystemBars(SystemChrome.latestStyle, Brightness.dark);

      await _switchTo(_container(tester), Appearance.dark);
      await _settle(tester);

      expect(_theme(tester).brightness, Brightness.dark);
      _expectSystemBars(region(), Brightness.light);
      _expectSystemBars(SystemChrome.latestStyle, Brightness.light);
    });
  });

  testWidgets(
    'the window channel receives the appearance on load and on change',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final List<Object?> sent = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          windowChannel,
          (MethodCall call) async {
            if (call.method == setAppearanceMethod) {
              sent.add(call.arguments);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            windowChannel,
            null,
          ),
        );
        _setDeviceBrightness(tester, Brightness.dark);

        await _pumpApp(tester, _stored(Appearance.light));

        expect(sent, <Object?>['light']);

        await _switchTo(_container(tester), Appearance.dark);
        await _settle(tester);

        expect(sent, <Object?>['light', 'dark']);

        await _switchTo(_container(tester), Appearance.system);
        await _settle(tester);

        expect(sent, <Object?>['light', 'dark', 'system']);
      });
    },
  );

  testWidgets('Windows pushes the chosen appearance to the window', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.windows, () async {
      final List<Object?> sent = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        windowChannel,
        (MethodCall call) async {
          if (call.method == setAppearanceMethod) {
            sent.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          windowChannel,
          null,
        ),
      );
      _setDeviceBrightness(tester, Brightness.light);

      await _pumpApp(tester, _stored(Appearance.dark));

      expect(sent, <Object?>['dark']);

      await _switchTo(_container(tester), Appearance.light);
      await _settle(tester);

      expect(sent, <Object?>['dark', 'light']);

      await _switchTo(_container(tester), Appearance.system);
      await _settle(tester);

      expect(sent, <Object?>['dark', 'light', 'system']);
    });
  });

  testWidgets('Android sends no appearance to a window', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      final List<String> calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        windowChannel,
        (MethodCall call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          windowChannel,
          null,
        ),
      );
      _setDeviceBrightness(tester, Brightness.light);

      await _pumpApp(tester, _stored(Appearance.dark), surface: _phoneSurface);
      await _switchTo(_container(tester), Appearance.light);
      await _settle(tester);

      expect(calls, isEmpty);
    });
  });
}

void _expectSystemBars(SystemUiOverlayStyle? style, Brightness icons) {
  expect(style?.statusBarIconBrightness, icons);
  expect(style?.systemNavigationBarIconBrightness, icons);
  expect(style?.systemNavigationBarColor, isNull);
}
