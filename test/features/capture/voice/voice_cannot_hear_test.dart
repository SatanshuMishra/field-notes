import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/audio/cannot_hear_notice.dart';
import 'package:field_notes/features/capture/audio/microphone_glyph.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/immersive/stage_phase.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Calls {
  int starts = 0;
  int stops = 0;
}

Future<void> _pump(
  WidgetTester tester, {
  required VoiceRecorderPhase phase,
  required ValueNotifier<MicrophoneHearing> hearing,
  required _Calls calls,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: ValueListenableBuilder<MicrophoneHearing>(
            valueListenable: hearing,
            builder:
                (BuildContext context, MicrophoneHearing heard, Widget? _) =>
                    VoiceRecorderSheet(
                      phase: phase,
                      hearing: heard,
                      onStart: () => calls.starts++,
                      onStop: () => calls.stops++,
                      onCancel: () {},
                      onPause: () {},
                      onDiscard: () {},
                    ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _orbOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(voiceRecordButtonKey),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  testWidgets(
    "the voice recorder does not start and shows the can't-hear-you notice",
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final ValueNotifier<MicrophoneHearing> hearing =
          ValueNotifier<MicrophoneHearing>(MicrophoneHearing.cannotHear);
      addTearDown(hearing.dispose);
      final _Calls calls = _Calls();
      await _pump(
        tester,
        phase: VoiceRecorderPhase.idle,
        hearing: hearing,
        calls: calls,
      );

      await tester.tap(find.byKey(voiceRecordButtonKey), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(calls.starts, 0);
      expect(find.text(cannotHearMessage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(cannotHearNoticeKey),
          matching: find.byType(MicrophoneGlyph),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(cannotHearNoticeLabel), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(voiceRecordButtonKey)),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      expect(_orbOpacity(tester), voiceSavingOrbOpacity);
      expect(find.textContaining(stageIdleStatus), findsNothing);

      hearing.value = MicrophoneHearing.hearing;
      await tester.pump();
      expect(find.byKey(cannotHearNoticeKey), findsNothing);
      expect(find.textContaining(stageIdleStatus), findsOneWidget);
      expect(_orbOpacity(tester), 1);
      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      expect(calls.starts, 1);
      semantics.dispose();
    },
  );

  testWidgets('a voice take that loses sound shows the reconnecting warning', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<MicrophoneHearing> hearing =
        ValueNotifier<MicrophoneHearing>(MicrophoneHearing.hearing);
    addTearDown(hearing.dispose);
    final _Calls calls = _Calls();
    await _pump(
      tester,
      phase: VoiceRecorderPhase.recording,
      hearing: hearing,
      calls: calls,
    );
    expect(find.text(soundLostMessage), findsNothing);

    hearing.value = MicrophoneHearing.lost;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(soundLostMessage), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(soundLostMessage), findsOneWidget);

    await tester.tap(find.byKey(voiceSavePillKey));
    await tester.pump();
    expect(calls.stops, 1);

    hearing.value = MicrophoneHearing.hearing;
    await tester.pump();
    expect(find.text(soundLostMessage), findsNothing);
  });
}
