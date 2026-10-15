import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/domain/settings/settings_repository.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/microphone_glyph.dart';
import 'package:field_notes/features/capture/immersive/recorder_glass_button.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

const String inputDeviceTitle = 'Input device';
const String inputProfileTitle = 'Input profile';
const String inputVolumeTitle = 'Input volume';
const String audioOutputTitle = 'Output';
const String systemOutputLabel = 'System output';
const String voiceSettingsLabel = 'Voice settings';
const String chosenByAndroidLabel = 'Chosen by Android';
const String recorderInputLabel = 'Input';
const int inputVolumeMaximum = 200;
const double inputPanelWidth = 300;

const Key recorderInputKey = ValueKey<String>('recorder-input');
const Key inputDeviceRowKey = ValueKey<String>('input-device-row');
const Key inputProfileRowKey = ValueKey<String>('input-profile-row');
const Key inputVolumeRowKey = ValueKey<String>('input-volume-row');
const Key audioOutputRowKey = ValueKey<String>('audio-output-row');
const Key voiceSettingsRowKey = ValueKey<String>('voice-settings-row');

const double _rowHeight = 44;
const double _choiceHeight = 44;
const double _panelRadius = 18;
const EdgeInsets _panelPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 8,
);
const EdgeInsets _rowPadding = EdgeInsets.symmetric(horizontal: 6);
const double _rowRadius = 10;
const double _choiceIndent = 10;
const double _glyphSize = 18;
const double _glyphGap = 6;
const double _mutedAlpha = 0.68;
const double _trackAlpha = 0.24;
const double _overlayAlpha = 0.12;
const double _meterGap = 6;
const EdgeInsets _meterPadding = EdgeInsets.fromLTRB(6, 4, 6, 10);
const double _anchorGap = 8;
const double _screenMargin = 16;

final Set<LogicalKeyboardKey> _panelActivationKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
};

final Map<ShortcutActivator, Intent> _panelActivation =
    <ShortcutActivator, Intent>{
      for (final LogicalKeyboardKey key in _panelActivationKeys)
        SingleActivator(key): const ActivateIntent(),
    };

KeyEventResult _keepActivationInPanel(FocusNode node, KeyEvent event) =>
    _panelActivationKeys.contains(event.logicalKey)
    ? KeyEventResult.skipRemainingHandlers
    : KeyEventResult.ignored;

Key inputChoiceKey(String? id) => ValueKey<String>('input-choice-${id ?? ''}');

Key inputProfileChoiceKey(InputProfile profile) =>
    ValueKey<String>('input-profile-choice-${profile.id}');

final Provider<AudioRecorderFactory> inputLevelRecorderProvider =
    Provider<AudioRecorderFactory>((Ref ref) => AudioRecorder.new);

AppSettings _settingsOf(WidgetRef ref) =>
    ref.watch(appSettingsProvider).value ?? AppSettings.defaults;

Future<void> _store(Future<void> Function() write) async {
  try {
    await write();
  } catch (error, stackTrace) {
    debugPrint('An input setting was not saved: $error\n$stackTrace');
  }
}

class RecorderInputButton extends StatefulWidget {
  const RecorderInputButton({
    super.key,
    this.androidVideo = false,
    this.onVoiceSettings,
  });

  final bool androidVideo;
  final VoidCallback? onVoiceSettings;

  @override
  State<RecorderInputButton> createState() => _RecorderInputButtonState();
}

class _RecorderInputButtonState extends State<RecorderInputButton> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final FocusNode _panelFocus = FocusNode(
    debugLabel: 'input panel',
    skipTraversal: true,
  );
  final Object _tapGroup = Object();
  FocusNode? _returnFocus;

  @override
  void dispose() {
    _panelFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_portal.isShowing) {
      _close();
      return;
    }
    _open();
  }

  void _open() {
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(_portal.show);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && _portal.isShowing) {
        _panelFocus.requestFocus();
      }
    });
  }

  void _close() {
    if (!_portal.isShowing) {
      return;
    }
    setState(_portal.hide);
    final FocusNode? previous = _returnFocus;
    _returnFocus = null;
    if (previous != null &&
        previous.context != null &&
        previous.canRequestFocus) {
      previous.requestFocus();
    }
  }

  void _openVoiceSettings() {
    _close();
    widget.onVoiceSettings?.call();
  }

  double _panelHeightLimit(BuildContext context) {
    final double screen = MediaQuery.sizeOf(context).height;
    final RenderObject? button = this.context.findRenderObject();
    if (button is! RenderBox || !button.hasSize || !button.attached) {
      return screen;
    }
    final double top = button.localToGlobal(Offset(0, button.size.height)).dy;
    return math.max(
      0,
      screen -
          top -
          _anchorGap -
          _screenMargin -
          MediaQuery.paddingOf(context).bottom,
    );
  }

  Widget _panel(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomRight,
        followerAnchor: Alignment.topRight,
        offset: const Offset(0, _anchorGap),
        child: TapRegion(
          groupId: _tapGroup,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): _close,
            },
            child: Focus(
              focusNode: _panelFocus,
              onKeyEvent: _keepActivationInPanel,
              child: Shortcuts(
                shortcuts: _panelActivation,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: _panelHeightLimit(context),
                  ),
                  child: InputPanel(
                    androidVideo: widget.androidVideo,
                    onVoiceSettings: widget.onVoiceSettings == null
                        ? null
                        : _openVoiceSettings,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (PointerDownEvent event) => _close(),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _panel,
          child: RecorderGlassButton(
            key: recorderInputKey,
            label: recorderInputLabel,
            glyph: const MicrophoneGlyph(),
            onPressed: _toggle,
          ),
        ),
      ),
    );
  }
}

class InputPanel extends ConsumerWidget {
  const InputPanel({
    super.key,
    this.androidVideo = false,
    this.onVoiceSettings,
  });

  final bool androidVideo;
  final VoidCallback? onVoiceSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool desktop = isDesktopPlatform(Theme.of(context).platform);
    return SizedBox(
      width: inputPanelWidth,
      child: GlassSurface(
        tone: GlassTone.media,
        borderRadius: BorderRadius.circular(_panelRadius),
        padding: _panelPadding,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InputDeviceRow(
                  androidVideo: androidVideo,
                  ink: Palette.mediaInk,
                ),
                const InputProfileRow(ink: Palette.mediaInk),
                const InputVolumeRow(ink: Palette.mediaInk),
                const Padding(
                  padding: _meterPadding,
                  child: InputLevelRow(ink: Palette.mediaInk),
                ),
                if (desktop) const AudioOutputRow(ink: Palette.mediaInk),
                _PanelRow(
                  key: voiceSettingsRowKey,
                  title: voiceSettingsLabel,
                  ink: Palette.mediaInk,
                  trailing: const _Glyph(Icons.chevron_right),
                  onTap: onVoiceSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InputLevelRow extends ConsumerWidget {
  const InputLevelRow({super.key, this.ink});

  final Color? ink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color ink = this.ink ?? context.colors.ink;
    final AudioInput input =
        ref.watch(selectedAudioInputProvider).value ??
        const AudioInput(id: null, label: systemDefaultInputLabel);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            inputLevelLabel,
            style: context.textStyles.captionSans.copyWith(
              color: ink.withValues(alpha: _mutedAlpha),
            ),
          ),
        ),
        const SizedBox(height: _meterGap),
        InputLevelMeter(
          input: input,
          volume: _settingsOf(ref).inputVolume,
          recorderFactory: ref.watch(inputLevelRecorderProvider),
          ink: ink,
        ),
      ],
    );
  }
}

class InputDeviceRow extends ConsumerStatefulWidget {
  const InputDeviceRow({super.key, this.androidVideo = false, this.ink});

  final bool androidVideo;
  final Color? ink;

  @override
  ConsumerState<InputDeviceRow> createState() => _InputDeviceRowState();
}

class _InputDeviceRowState extends ConsumerState<InputDeviceRow> {
  List<AudioInput>? _inputs;
  bool _open = false;
  int _listing = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.androidVideo) {
      unawaited(_list());
    }
  }

  Future<List<AudioInput>> _list() async {
    final int listing = ++_listing;
    final List<AudioInput> inputs = await listAudioInputs(
      ref.read(audioInputListerProvider),
    );
    if (mounted && listing == _listing) {
      setState(() => _inputs = inputs);
    }
    return inputs;
  }

  void _toggle() {
    if (_open) {
      setState(() => _open = false);
      return;
    }
    setState(() => _open = true);
    ref.invalidate(selectedAudioInputProvider);
    unawaited(_list());
  }

  Future<void> _choose(AudioInput chosen) async {
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
    setState(() => _open = false);
    final List<AudioInput> inputs = await _list();
    final AudioInput resolved = resolveAudioInput(inputs, chosen.id);
    await _store(() => repository.setAudioInputId(resolved.id));
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = widget.ink ?? context.colors.ink;
    if (widget.androidVideo) {
      return _PanelRow(
        key: inputDeviceRowKey,
        title: inputDeviceTitle,
        value: chosenByAndroidLabel,
        ink: ink,
      );
    }
    final String? storedId = _settingsOf(ref).audioInputId;
    final List<AudioInput>? inputs = _inputs;
    final AudioInput? resolved = inputs == null
        ? null
        : resolveAudioInput(inputs, storedId);
    final String label =
        resolved?.label ?? (storedId == null ? systemDefaultInputLabel : '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PanelRow(
          key: inputDeviceRowKey,
          title: inputDeviceTitle,
          value: label,
          ink: ink,
          trailing: _Glyph(_open ? Icons.expand_less : Icons.expand_more),
          expanded: _open,
          onTap: _toggle,
        ),
        if (_open && inputs != null && resolved != null)
          for (final AudioInput input in inputs)
            _ChoiceRow(
              key: inputChoiceKey(input.id),
              label: input.label,
              chosen: input.id == resolved.id,
              ink: ink,
              onTap: () => unawaited(_choose(input)),
            ),
      ],
    );
  }
}

class InputProfileRow extends ConsumerStatefulWidget {
  const InputProfileRow({super.key, this.ink});

  final Color? ink;

  @override
  ConsumerState<InputProfileRow> createState() => _InputProfileRowState();
}

class _InputProfileRowState extends ConsumerState<InputProfileRow> {
  bool _open = false;

  void _choose(InputProfile profile) {
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
    final InputProfile current =
        (ref.read(appSettingsProvider).value ?? AppSettings.defaults)
            .inputProfile;
    setState(() => _open = false);
    if (profile == current) {
      return;
    }
    unawaited(_store(() => repository.setInputProfile(profile)));
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = widget.ink ?? context.colors.ink;
    final InputProfile current = _settingsOf(ref).inputProfile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PanelRow(
          key: inputProfileRowKey,
          title: inputProfileTitle,
          value: current.label,
          ink: ink,
          trailing: _Glyph(_open ? Icons.expand_less : Icons.expand_more),
          expanded: _open,
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          for (final InputProfile profile in InputProfile.values)
            _ChoiceRow(
              key: inputProfileChoiceKey(profile),
              label: profile.label,
              chosen: profile == current,
              ink: ink,
              onTap: () => _choose(profile),
            ),
      ],
    );
  }
}

class InputVolumeRow extends ConsumerStatefulWidget {
  const InputVolumeRow({super.key, this.ink});

  final Color? ink;

  @override
  ConsumerState<InputVolumeRow> createState() => _InputVolumeRowState();
}

class _InputVolumeRowState extends ConsumerState<InputVolumeRow> {
  double? _dragging;
  int? _released;

  void _start(double value) {
    setState(() {
      _released = null;
      _dragging = value;
    });
  }

  void _release(double value) {
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
    final int volume = value.round();
    setState(() {
      _dragging = volume.toDouble();
      _released = volume;
    });
    unawaited(_save(repository, volume));
  }

  Future<void> _save(SettingsRepository repository, int volume) async {
    try {
      await repository.setInputVolume(volume);
    } catch (error, stackTrace) {
      debugPrint('The input volume was not saved: $error\n$stackTrace');
      if (mounted && _released == volume) {
        setState(() {
          _dragging = null;
          _released = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (
      AsyncValue<AppSettings>? previous,
      AsyncValue<AppSettings> next,
    ) {
      final int? released = _released;
      if (released != null && next.value?.inputVolume == released) {
        setState(() {
          _dragging = null;
          _released = null;
        });
      }
    });
    final Color ink = widget.ink ?? context.colors.ink;
    final double value = (_dragging ?? _settingsOf(ref).inputVolume.toDouble())
        .clamp(0, inputVolumeMaximum.toDouble())
        .toDouble();
    final String shown = '${value.round()}%';
    return Column(
      key: inputVolumeRowKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: _PanelRow(title: inputVolumeTitle, value: shown, ink: ink),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: ink,
            inactiveTrackColor: ink.withValues(alpha: _trackAlpha),
            thumbColor: ink,
            overlayColor: ink.withValues(alpha: _overlayAlpha),
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Semantics(
            label: inputVolumeTitle,
            child: Slider(
              value: value,
              max: inputVolumeMaximum.toDouble(),
              divisions: inputVolumeMaximum,
              semanticFormatterCallback: (double value) => '${value.round()}%',
              onChangeStart: _start,
              onChanged: (double next) => setState(() => _dragging = next),
              onChangeEnd: _release,
            ),
          ),
        ),
      ],
    );
  }
}

class AudioOutputRow extends ConsumerStatefulWidget {
  const AudioOutputRow({super.key, this.ink});

  final Color? ink;

  @override
  ConsumerState<AudioOutputRow> createState() => _AudioOutputRowState();
}

class _AudioOutputRowState extends ConsumerState<AudioOutputRow> {
  String? _name;
  bool _named = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final String? name = await ref
        .read(audioOutputProvider)
        .defaultOutputName();
    if (!mounted) {
      return;
    }
    setState(() {
      _name = name;
      _named = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AudioOutput output = ref.watch(audioOutputProvider);
    return _PanelRow(
      key: audioOutputRowKey,
      title: audioOutputTitle,
      value: _named ? _name ?? systemOutputLabel : '',
      ink: widget.ink ?? context.colors.ink,
      trailing: const _Glyph(Icons.open_in_new),
      onTap: () => unawaited(output.openSoundSettings()),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    super.key,
    required this.title,
    required this.ink,
    this.value,
    this.trailing,
    this.expanded,
    this.onTap,
  });

  final String title;
  final Color ink;
  final String? value;
  final Widget? trailing;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String? shown = value;
    final Widget? glyph = trailing;
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Padding(
        padding: _rowPadding,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.bodySans.copyWith(color: ink),
              ),
            ),
            if (shown != null)
              Flexible(
                child: Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.textStyles.captionSans.copyWith(
                    color: ink.withValues(alpha: _mutedAlpha),
                  ),
                ),
              ),
            if (glyph != null) ...<Widget>[
              const SizedBox(width: _glyphGap),
              IconTheme.merge(
                data: IconThemeData(color: ink, size: _glyphSize),
                child: glyph,
              ),
            ],
          ],
        ),
      ),
    );
    final VoidCallback? tap = onTap;
    return MergeSemantics(
      child: Semantics(
        button: tap != null,
        expanded: expanded,
        child: tap == null
            ? content
            : InkWell(
                onTap: tap,
                borderRadius: BorderRadius.circular(_rowRadius),
                child: content,
              ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.chosen,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final bool chosen;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: chosen,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_rowRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _choiceHeight),
            child: Padding(
              padding: _rowPadding.add(
                const EdgeInsetsDirectional.only(start: _choiceIndent),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: _glyphSize,
                    child: chosen
                        ? Icon(Icons.check, size: _glyphSize, color: ink)
                        : null,
                  ),
                  const SizedBox(width: _glyphGap),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.captionSans.copyWith(
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(child: Icon(icon));
  }
}
