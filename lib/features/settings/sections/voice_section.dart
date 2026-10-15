import 'dart:async';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_feedback.dart';

const String voiceIsolationDescription =
    'Clears background noise like fans, traffic and typing from your voice.';
const String studioDescription =
    'Your microphone as it is, with no processing.';
const String inputProfileSaveFailed = 'Could not save your input profile.';

const String _profileGroupLabel = 'input profile';
const String _microphoneGroupLabel = 'microphone';
const double _radioSize = 18;
const double _radioRing = 1.6;
const double _radioDot = 8;
const double _choiceMinHeight = 48;

ValueKey<String> voiceProfileChoiceKey(InputProfile profile) =>
    ValueKey<String>('voice-profile-${profile.id}');

String voiceProfileDescription(InputProfile profile) => switch (profile) {
  InputProfile.voiceIsolation => voiceIsolationDescription,
  InputProfile.studio => studioDescription,
};

class VoiceSection extends ConsumerWidget {
  const VoiceSection({
    super.key,
    required this.settings,
    required this.onFeedback,
    this.active = true,
  });

  final AppSettings settings;
  final SettingsFeedbackSink onFeedback;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection.grouped(
      groups: <SettingsGroup>[
        SettingsGroup(
          label: _profileGroupLabel,
          rows: <Widget>[
            for (final InputProfile profile in InputProfile.values)
              MergeSemantics(
                key: voiceProfileChoiceKey(profile),
                child: Semantics(
                  checked: profile == settings.inputProfile,
                  inMutuallyExclusiveGroup: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _choiceMinHeight,
                    ),
                    child: SettingsFieldRow(
                      label: profile.label,
                      description: voiceProfileDescription(profile),
                      control: _ProfileRadio(
                        selected: profile == settings.inputProfile,
                      ),
                      onPressed: () => unawaited(_choose(ref, profile)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (active)
          const SettingsGroup(
            label: _microphoneGroupLabel,
            rows: <Widget>[InputDeviceRow(), InputVolumeRow(), InputLevelRow()],
          ),
      ],
    );
  }

  Future<void> _choose(WidgetRef ref, InputProfile profile) async {
    if (profile == settings.inputProfile) {
      return;
    }
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
    try {
      await repository.setInputProfile(profile);
    } catch (error, stackTrace) {
      debugPrint('The input profile was not saved: $error\n$stackTrace');
      onFeedback(inputProfileSaveFailed);
    }
  }
}

class _ProfileRadio extends StatelessWidget {
  const _ProfileRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: _radioSize,
        height: _radioSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Palette.coral : context.colors.ink35,
            width: _radioRing,
          ),
        ),
        child: selected
            ? const SizedBox.square(
                dimension: _radioDot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.coral,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
