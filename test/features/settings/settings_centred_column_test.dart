import 'dart:typed_data';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../app/support/app_shell_harness.dart';
import '../../support/sync_overrides.dart';
import 'support/settings_harness.dart';

const Key _settingsButton = ValueKey<String>('settings-button');
const double _centreTolerance = 4;

class _FakeRecorder extends Fake implements AudioRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      const Stream<Uint8List>.empty();

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

List<Override> _overrides(DateTime now) {
  final List<Override> sync = syncOnOverrides(
    status: SyncedStatus(now),
    devices: const [],
  );
  final Set<Object> replaced = <Object>{
    for (final Override override in sync) override.origin,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    ...sync,
    appSettingsProvider.overrideWith(
      (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
    ),
    settingsDataControllerProvider.overrideWith(
      (Ref ref) async => FakeSettingsDataController(),
    ),
    audioInputListerProvider.overrideWithValue(
      () async => const <InputDevice>[],
    ),
    inputLevelRecorderProvider.overrideWithValue(_FakeRecorder.new),
  ];
}

Future<void> _pumpMacSettings(WidgetTester tester, Size window) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(DateTime.now().toUtc()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_settingsButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the settings content column is centred right of the section tabs in a wide Mac window',
    (WidgetTester tester) async {
      for (final Size window in const <Size>[
        Size(1440, 900),
        Size(2560, 1440),
      ]) {
        await _pumpMacSettings(tester, window);
        final Finder rule = find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is DashedDivider && widget.axis == Axis.vertical,
          ),
        );
        expect(rule, findsOneWidget);
        for (final SettingsTab tab in SettingsTab.values) {
          final String page = '${tab.label} at ${window.width.round()}';
          await tester.tap(find.byKey(settingsTabKey(tab)));
          await tester.pumpAndSettle();
          final Rect column = tester.getRect(
            find.byKey(settingsContentColumnKey),
          );
          final double spaceLeft = tester.getRect(rule).right;
          final double spaceRight = tester
              .getRect(find.byType(SettingsScreen))
              .right;
          expect(column.width, settingsContentMaxWidth, reason: page);
          expect(
            column.center.dx,
            closeTo((spaceLeft + spaceRight) / 2, _centreTolerance),
            reason: page,
          );
        }
      }
    },
  );
}
