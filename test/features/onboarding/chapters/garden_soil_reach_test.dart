import 'dart:ui' as ui;

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../capture/core/capture_test_support.dart' show FakeNoteWriter;
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _bottomRow = 4;
const double _maximumSoilLuminance = 0.3;

List<Override> _overrides() {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(
      FakeSettingsRepository(storedValues: false),
    ),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    onboardingCountryCodeProvider.overrideWithValue('US'),
    noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
  ];
}

Future<void> _rest(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
}

Future<double> _luminanceAt(WidgetTester tester, Offset point) async {
  final OffsetLayer layer =
      tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final double luminance = (await tester.runAsync(() async {
    final ui.Image image = await layer.toImage(Offset.zero & _phone);
    final ByteData? rgba = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final int offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    image.dispose();
    return Color.fromARGB(
      255,
      rgba!.getUint8(offset),
      rgba.getUint8(offset + 1),
      rgba.getUint8(offset + 2),
    ).computeLuminance();
  }))!;
  return luminance;
}

void main() {
  testWidgets('on the phone Mood step the soil still reaches the bottom edge', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides(), child: const FieldNotesApp()),
    );
    await _rest(tester);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    container.read(onboardingControllerProvider.notifier)
      ..plant()
      ..markGrown()
      ..next();
    await _rest(tester);

    final OnboardingFlowRunning flow =
        container.read(onboardingControllerProvider) as OnboardingFlowRunning;
    expect(flow.chapter, OnboardingChapter.day);
    for (final double x in <double>[24, _phone.width / 2, _phone.width - 24]) {
      expect(
        await _luminanceAt(tester, Offset(x, _phone.height - _bottomRow)),
        lessThan(_maximumSoilLuminance),
        reason: 'the bottom edge at x $x shows paper, not soil',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
