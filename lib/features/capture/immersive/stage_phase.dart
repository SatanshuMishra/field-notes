import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';

const Duration stageBreathDuration = Duration(seconds: 4);

const String stageIdleStatus = 'Tap when you’re ready.';
const String stageIdleSidebarTail = ' There’s no wrong way to say it.';
const String stageBreathingStatus = 'Breathe in… and slowly out.';
const String stageRecordingStatus = 'I’m listening. Take your time.';
const String stagePausedStatus = 'Paused. Nothing’s lost.';
const String stageSavingFallbackStatus = 'Saving…';

enum StagePhase {
  idle(announcement: 'Ready to record'),
  breathing(announcement: 'Breathing before recording'),
  recording(announcement: 'Recording'),
  paused(announcement: 'Paused'),
  saving(announcement: 'Saving');

  const StagePhase({required this.announcement});

  final String announcement;

  bool get isTaking => this == recording || this == paused;

  bool get showsTimer => isTaking;

  bool get isUnderway => index >= recording.index;

  String statusText({required ShellLayout layout, String? savingText}) {
    return switch (this) {
      StagePhase.idle =>
        layout == ShellLayout.sidebar
            ? '$stageIdleStatus$stageIdleSidebarTail'
            : stageIdleStatus,
      StagePhase.breathing => stageBreathingStatus,
      StagePhase.recording => stageRecordingStatus,
      StagePhase.paused => stagePausedStatus,
      StagePhase.saving => savingText ?? stageSavingFallbackStatus,
    };
  }
}

ShellLayout stageLayoutOf(BuildContext context) =>
    resolveShellLayout(Theme.of(context).platform);
