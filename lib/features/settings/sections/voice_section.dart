import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
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
const String _speakerGroupLabel = 'speaker';
const double _valueGlyphSize = 18;
const double _valueGlyphGap = 6;
const double _rowMinHeight = 48;

const Set<TargetPlatform> _speakerPlatforms = <TargetPlatform>{
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.android,
};

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
    final bool speaker = _speakerPlatforms.contains(Theme.of(context).platform);
    return SettingsSection.grouped(
      groups: <SettingsGroup>[
        SettingsGroup(
          label: _profileGroupLabel,
          rows: <Widget>[
            InputProfileRow(
              describe: voiceProfileDescription,
              onSaveFailed: () => onFeedback(inputProfileSaveFailed),
              rowBuilder:
                  (
                    BuildContext context,
                    String title,
                    String value,
                    bool open,
                    VoidCallback toggle,
                  ) => ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: _rowMinHeight),
                    child: SettingsFieldRow(
                      label: title,
                      control: _DropdownValue(value: value, open: open),
                      onPressed: toggle,
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
        if (active && speaker)
          const SettingsGroup(
            label: _speakerGroupLabel,
            rows: <Widget>[OutputDeviceRow(), OutputVolumeRow()],
          ),
      ],
    );
  }
}

class _DropdownValue extends StatelessWidget {
  const _DropdownValue({required this.value, required this.open});

  final String value;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: context.textStyles.captionSans.copyWith(color: colors.muted),
          ),
        ),
        const SizedBox(width: _valueGlyphGap),
        ExcludeSemantics(
          child: Icon(
            open ? Icons.expand_less : Icons.expand_more,
            size: _valueGlyphSize,
            color: colors.ink,
          ),
        ),
      ],
    );
  }
}
