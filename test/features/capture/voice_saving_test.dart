import 'dart:async';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/journal_capture_service.dart'
    show entryWriteMessage, mediaWriteMessage;
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice/voice_test_support.dart';

const Size _sidebarWindow = Size(1280, 800);
const Size _bottomBarWindow = Size(360, 740);
const Key _openKey = ValueKey<String>('open-voice');
const String _date = '2026-09-28';
const String _keepLabel = 'Keep this';
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);

final TargetPlatformVariant _platforms = TargetPlatformVariant(
  const <TargetPlatform>{
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  },
);

Future<void> _openVoice(WidgetTester tester, FakeCaptureService service) async {
  final TargetPlatform platform = defaultTargetPlatform;
  tester.view.physicalSize = resolveShellLayout(platform) == ShellLayout.sidebar
      ? _sidebarWindow
      : _bottomBarWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        voiceRecorderProvider.overrideWith((Ref ref) => FakeVoiceRecorder()),
        captureServiceProvider.overrideWith((Ref ref) => service),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (BuildContext context) => TextButton(
                key: _openKey,
                onPressed: () => showVoiceComposer(context, _date),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_openKey));
  await tester.pump();
  await tester.pump(_fade);
  await startVoiceTake(tester);
}

Future<void> _keep(WidgetTester tester) async {
  await tester.tap(find.byKey(voiceSavePillKey), warnIfMissed: false);
  await tester.pump();
  await tester.pump(_step);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(_fade);
}

void main() {
  testWidgets('keep this shows a spinner while saving', (
    WidgetTester tester,
  ) async {
    final Completer<void> held = Completer<void>();
    final FakeCaptureService service = FakeCaptureService(gate: held.future);
    await _openVoice(tester, service);
    final Rect keepBefore = tester.getRect(find.byKey(voiceSavePillKey));

    await _keep(tester);

    final Finder spinner = find.descendant(
      of: find.byKey(voiceSavePillKey),
      matching: find.bySubtype<ProgressIndicator>(),
    );
    expect(spinner, findsOneWidget);
    expect(
      (tester.getCenter(spinner) - keepBefore.center).distance,
      lessThan(1),
    );
    expect(find.text(_keepLabel).hitTestable(), findsNothing);
    expect(
      tester.getSemantics(find.byKey(voiceSavePillKey)),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );

    await _keep(tester);
    expect(service.requests, hasLength(1));

    held.complete();
    await tester.pump();
    await tester.pump(_fade);
    await _finish(tester);
  }, variant: _platforms);

  testWidgets('a failed save names the next step', (WidgetTester tester) async {
    for (final String message in <String>[
      entryWriteMessage,
      mediaWriteMessage,
    ]) {
      await _openVoice(
        tester,
        FakeCaptureService(failure: CaptureException(message)),
      );
      await _keep(tester);

      final Finder error = find.byKey(voiceErrorKey);
      final String shown = tester.widget<Text>(error).data!;
      final String words = shown.toLowerCase();
      expect(words, contains('try again'));
      expect(words, contains('log'));
      expect(words, contains('keep'));
      expect(words, isNot(contains('entry')));
      expect(words, isNot(contains('save')));
      expect(
        tester.getSemantics(error),
        isSemantics(label: shown, isLiveRegion: true),
      );

      final Rect shownAt = tester.getRect(error);
      expect(
        shownAt.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(voiceOrbZoneKey)).bottom,
        ),
      );
      expect(
        shownAt.bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(voiceActionsKey)).top),
      );
      await _finish(tester);
    }
  }, variant: _platforms);
}
