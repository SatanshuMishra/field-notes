import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:field_notes/features/today/today_mood_dock.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import '../support/app_shell_harness.dart';

const double _windowHeight = 860;
const double _openSidebar = 176;
const double _collapsedRail = 68;
const Size _smallestWindow = Size(720, 600);

const List<TargetPlatform> _desktops = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.windows,
];

const List<({double width, bool column, double sidebar})> _widths =
    <({double width, bool column, double sidebar})>[
      (width: 1360, column: true, sidebar: _openSidebar),
      (width: 1120, column: true, sidebar: _openSidebar),
      (width: 1119, column: false, sidebar: _openSidebar),
      (width: 860, column: false, sidebar: _openSidebar),
      (width: 859, column: false, sidebar: _collapsedRail),
    ];

Finder get _rightColumn => find.byType(TodayRightRail);
Finder get _newLog => find.text('New log');
Finder get _sidebar => find.byKey(sidebarRailKey);
Finder get _toggle => find.byKey(sidebarToggleKey);

double _sidebarWidth(WidgetTester tester) => tester.getSize(_sidebar).width;

void _holdStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _on(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<FakeSettingsRepository> _pumpShell(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  bool collapsed = false,
}) async {
  final FakeSettingsRepository settings = FakeSettingsRepository(
    initial: AppSettings.defaults.copyWith(sidebarCollapsed: collapsed),
  );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (override.origin != settingsRepositoryProvider) override,
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _pressToggleShortcut(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final LogicalKeyboardKey modifier = platform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.backslash);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.backslash);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  for (final TargetPlatform platform in _desktops) {
    for (final (:double width, :bool column, :double sidebar) in _widths) {
      testWidgets(
        'a $width wide ${platform.name} window lays out by its width',
        (WidgetTester tester) async {
          await _on(platform, () async {
            _holdStill(tester);
            final FakeSettingsRepository settings = await _pumpShell(
              tester,
              platform: platform,
              size: Size(width, _windowHeight),
            );

            expect(_rightColumn, column ? findsOneWidget : findsNothing);
            expect(_newLog, column ? findsNothing : findsOneWidget);
            expect(_sidebarWidth(tester), sidebar);
            expect(settings.sidebarCollapsedWrites, isEmpty);
            expect(tester.takeException(), isNull);
          });
        },
      );
    }

    testWidgets(
      'narrowing a ${platform.name} window takes the rail without touching '
      'the stored preference, and widening brings the open sidebar back',
      (WidgetTester tester) async {
        await _on(platform, () async {
          _holdStill(tester);
          final FakeSettingsRepository settings = await _pumpShell(
            tester,
            platform: platform,
            size: const Size(1360, _windowHeight),
          );
          expect(_sidebarWidth(tester), _openSidebar);

          await _resize(tester, const Size(859, _windowHeight));
          expect(_sidebarWidth(tester), _collapsedRail);

          await _resize(tester, const Size(1360, _windowHeight));
          expect(_sidebarWidth(tester), _openSidebar);
          expect(settings.sidebarCollapsedWrites, isEmpty);
        });
      },
    );

    testWidgets(
      'a ${platform.name} preference for the rail still holds in a wide window',
      (WidgetTester tester) async {
        await _on(platform, () async {
          _holdStill(tester);
          final FakeSettingsRepository settings = await _pumpShell(
            tester,
            platform: platform,
            size: const Size(1360, _windowHeight),
            collapsed: true,
          );

          expect(_sidebarWidth(tester), _collapsedRail);
          expect(_toggle, findsOneWidget);
          expect(settings.sidebarCollapsedWrites, isEmpty);
        });
      },
    );

    testWidgets(
      'below 860 a ${platform.name} window offers no sidebar toggle and its '
      'shortcut leaves the stored preference alone',
      (WidgetTester tester) async {
        await _on(platform, () async {
          _holdStill(tester);
          final FakeSettingsRepository settings = await _pumpShell(
            tester,
            platform: platform,
            size: const Size(859, _windowHeight),
          );

          expect(_toggle, findsNothing);
          await _pressToggleShortcut(tester, platform);

          expect(settings.sidebarCollapsedWrites, isEmpty);
          expect(_sidebarWidth(tester), _collapsedRail);
        });
      },
    );

    testWidgets('New log on ${platform.name} opens the capture chooser', (
      WidgetTester tester,
    ) async {
      await _on(platform, () async {
        _holdStill(tester);
        await _pumpShell(
          tester,
          platform: platform,
          size: const Size(1119, _windowHeight),
        );

        await tester.tap(_newLog);
        await tester.pumpAndSettle();

        expect(find.byType(CaptureChooserSheet), findsOneWidget);
      });
    });

    testWidgets(
      'every ${platform.name} page lays out in the smallest window allowed',
      (WidgetTester tester) async {
        await _on(platform, () async {
          _holdStill(tester);
          await _pumpShell(tester, platform: platform, size: _smallestWindow);
          expect(tester.takeException(), isNull);

          for (final Key target in <Key>[
            for (final ShellDestination destination in ShellDestination.primary)
              ValueKey<String>('rail-${destination.name}'),
            const ValueKey<String>('settings-button'),
          ]) {
            await tester.tap(find.byKey(target));
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: '$target');
          }
        });
      },
    );
  }

  for (final TargetPlatform platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    for (final double width in <double>[1360, 859]) {
      testWidgets('${platform.name} keeps its phone layout at $width wide', (
        WidgetTester tester,
      ) async {
        await _on(platform, () async {
          _holdStill(tester);
          await _pumpShell(
            tester,
            platform: platform,
            size: Size(width, _windowHeight),
          );

          expect(find.byType(TodayMoodDock), findsOneWidget);
          expect(_rightColumn, findsNothing);
          expect(_newLog, findsNothing);
          expect(_sidebar, findsNothing);
        });
      });
    }
  }
}
