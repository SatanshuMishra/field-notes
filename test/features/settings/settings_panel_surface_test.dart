import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';

const Size _desktop = Size(1140, 726);
const Size _phone = Size(384, 832);
const Offset _desktopPoint = Offset(1128, 380);
const Offset _phonePoint = Offset(4, 420);
const int _tolerance = 2;

final GlobalKey _boundaryKey = GlobalKey();

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  @override
  String toString() => 'rgb($r, $g, $b)';
}

void _holdStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pumpDesktop(
  WidgetTester tester,
  Brightness brightness, {
  List<Override> overrides = const <Override>[],
}) async {
  _holdStill(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpShell(
    tester,
    RepaintBoundary(key: _boundaryKey, child: const AppShell()),
    surface: _desktop,
    brightness: brightness,
    overrides: overrides,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPhone(
  WidgetTester tester,
  Brightness brightness, {
  List<Override> overrides = const <Override>[],
}) async {
  _holdStill(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpShell(
    tester,
    RepaintBoundary(key: _boundaryKey, child: const AppShell()),
    platform: TargetPlatform.android,
    surface: _phone,
    brightness: brightness,
    overrides: overrides,
  );
  await tester.pumpAndSettle();
}

Future<_Rgb> _pixel(WidgetTester tester, Offset at) async {
  final RenderRepaintBoundary boundary =
      _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final _Rgb? rgb = await tester.runAsync<_Rgb>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    final int offset = (at.dy.toInt() * image.width + at.dx.toInt()) * 4;
    final _Rgb result = _Rgb(
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
    image.dispose();
    return result;
  });
  return rgb!;
}

void _expectSame(_Rgb actual, _Rgb today, String reason) {
  expect(
    (actual.r - today.r).abs(),
    lessThanOrEqualTo(_tolerance),
    reason: '$reason: red $actual against Today $today',
  );
  expect(
    (actual.g - today.g).abs(),
    lessThanOrEqualTo(_tolerance),
    reason: '$reason: green $actual against Today $today',
  );
  expect(
    (actual.b - today.b).abs(),
    lessThanOrEqualTo(_tolerance),
    reason: '$reason: blue $actual against Today $today',
  );
}

Future<void> _openDesktopSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Settings').first);
  await tester.pumpAndSettle();
}

Future<void> _openPhoneSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
  await tester.pumpAndSettle();
}

List<Override> _neverLoads() => <Override>[
  appSettingsProvider.overrideWith(
    (Ref ref) => StreamController<AppSettings>().stream,
  ),
];

List<Override> _failsToLoad() => <Override>[
  appSettingsProvider.overrideWith(
    (Ref ref) => Stream<AppSettings>.error(StateError('no settings')),
  ),
];

void main() {
  testWidgets('desktop settings sit on the panel like Today', (
    WidgetTester tester,
  ) async {
    for (final Brightness brightness in Brightness.values) {
      await _pumpDesktop(tester, brightness);
      final _Rgb today = await _pixel(tester, _desktopPoint);
      await _openDesktopSettings(tester);
      for (final SettingsTab tab in SettingsTab.values) {
        await tester.tap(find.byKey(settingsTabKey(tab)));
        await tester.pumpAndSettle();
        _expectSame(
          await _pixel(tester, _desktopPoint),
          today,
          'desktop ${tab.name} tab',
        );
      }
    }
  });

  testWidgets('phone settings sit on the panel like Today', (
    WidgetTester tester,
  ) async {
    for (final Brightness brightness in Brightness.values) {
      await _pumpPhone(tester, brightness);
      final _Rgb today = await _pixel(tester, _phonePoint);
      await _openPhoneSettings(tester);
      _expectSame(
        await _pixel(tester, _phonePoint),
        today,
        'phone section list',
      );
      await tester.tap(find.byKey(settingsTabKey(SettingsTab.data)));
      await tester.pumpAndSettle();
      _expectSame(
        await _pixel(tester, _phonePoint),
        today,
        'phone section page',
      );
    }
  });

  testWidgets('loading and failed settings sit on the panel too', (
    WidgetTester tester,
  ) async {
    for (final Brightness brightness in Brightness.values) {
      for (final bool desktop in <bool>[true, false]) {
        for (final List<Override> overrides in <List<Override>>[
          _neverLoads(),
          _failsToLoad(),
        ]) {
          if (desktop) {
            await _pumpDesktop(tester, brightness, overrides: overrides);
          } else {
            await _pumpPhone(tester, brightness, overrides: overrides);
          }
          final Offset point = desktop ? _desktopPoint : _phonePoint;
          final _Rgb today = await _pixel(tester, point);
          if (desktop) {
            await _openDesktopSettings(tester);
          } else {
            await _openPhoneSettings(tester);
          }
          _expectSame(
            await _pixel(tester, point),
            today,
            '${desktop ? 'desktop' : 'phone'} settings not loaded',
          );
        }
      }
    }
  });
}
