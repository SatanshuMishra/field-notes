import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/domain/settings/settings_repository.dart';
import 'package:field_notes/features/capture/audio/anchored_dropdown.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/microphone_glyph.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/audio/recorder_input_ring.dart';
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
const String outputDeviceTitle = 'Output device';
const String outputVolumeTitle = 'Output volume';
const String voiceSettingsLabel = 'Voice settings';
const String chosenByAndroidLabel = 'Chosen by Android';
const String recorderInputLabel = 'Input';
const int inputVolumeMaximum = 200;
const int outputVolumeMaximum = 100;
const double inputPanelWidth = 300;

const Key recorderInputKey = ValueKey<String>('recorder-input');
const Key inputDeviceRowKey = ValueKey<String>('input-device-row');
const Key inputProfileRowKey = ValueKey<String>('input-profile-row');
const Key inputVolumeRowKey = ValueKey<String>('input-volume-row');
const Key outputDeviceRowKey = ValueKey<String>('output-device-row');
const Key outputVolumeRowKey = ValueKey<String>('output-volume-row');
const Key inputDeviceMenuKey = ValueKey<String>('input-device-menu');
const Key inputProfileMenuKey = ValueKey<String>('input-profile-menu');
const Key outputDeviceMenuKey = ValueKey<String>('output-device-menu');
const Key voiceSettingsRowKey = ValueKey<String>('voice-settings-row');

const double _rowHeight = 44;
const double _panelRadius = 18;
const EdgeInsets _panelPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 8,
);
const EdgeInsets _rowPadding = EdgeInsets.symmetric(horizontal: 6);
const double _rowRadius = 10;
const double _glyphSize = 18;
const double _glyphGap = 6;
const double _mutedAlpha = 0.68;
const double _heldDuringTakeOpacity = 0.4;
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

Key outputChoiceKey(String? id) =>
    ValueKey<String>('output-choice-${id ?? ''}');

final Provider<AudioRecorderFactory> inputLevelRecorderProvider =
    Provider<AudioRecorderFactory>((Ref ref) => AudioRecorder.new);

AppSettings _settingsOf(WidgetRef ref) =>
    ref.watch(appSettingsProvider).value ?? AppSettings.defaults;

Future<void> _store(
  Future<void> Function() write, {
  VoidCallback? onFailed,
}) async {
  try {
    await write();
  } catch (error, stackTrace) {
    debugPrint('An audio setting was not saved: $error\n$stackTrace');
    onFailed?.call();
  }
}

typedef DropdownRowBuilder = Widget Function(
  BuildContext context,
  String title,
  String value,
  bool open,
  VoidCallback toggle,
);

Widget _dropdownGlyph(bool open) =>
    _Glyph(open ? Icons.expand_less : Icons.expand_more);

class RecorderInputButton extends StatefulWidget {
  const RecorderInputButton({
    super.key,
    this.androidVideo = false,
    this.onVoiceSettings,
    this.takeLevels,
    this.ringLevels,
    this.ringHearing = MicrophoneHearing.hearing,
  });

  final bool androidVideo;
  final VoidCallback? onVoiceSettings;
  final Stream<double>? takeLevels;
  final Stream<double>? ringLevels;
  final MicrophoneHearing ringHearing;

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
                    takeLevels: widget.takeLevels,
                    tapRegionGroupId: _tapGroup,
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
    final Widget button = RecorderGlassButton(
      key: recorderInputKey,
      label: recorderInputLabel,
      glyph: const MicrophoneGlyph(),
      onPressed: _toggle,
    );
    final Stream<double>? ringLevels = widget.ringLevels;
    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (PointerDownEvent event) => _close(),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _panel,
          child: ringLevels == null
              ? button
              : RecorderInputRing(
                  levels: ringLevels,
                  hearing: widget.ringHearing,
                  child: button,
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
    this.tapRegionGroupId,
    this.takeLevels,
  });

  final bool androidVideo;
  final VoidCallback? onVoiceSettings;
  final Object? tapRegionGroupId;
  final Stream<double>? takeLevels;

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
                _HeldDuringTake(
                  held: takeLevels != null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      InputDeviceRow(
                        androidVideo: androidVideo,
                        heldDuringTake: takeLevels != null,
                        ink: Palette.mediaInk,
                        tone: GlassTone.media,
                        tapRegionGroupId: tapRegionGroupId,
                      ),
                      InputProfileRow(
                        ink: Palette.mediaInk,
                        tone: GlassTone.media,
                        tapRegionGroupId: tapRegionGroupId,
                      ),
                      const InputVolumeRow(ink: Palette.mediaInk),
                    ],
                  ),
                ),
                Padding(
                  padding: _meterPadding,
                  child: InputLevelRow(
                    ink: Palette.mediaInk,
                    takeLevels: takeLevels,
                  ),
                ),
                if (desktop)
                  OutputDeviceRow(
                    ink: Palette.mediaInk,
                    tone: GlassTone.media,
                    tapRegionGroupId: tapRegionGroupId,
                  ),
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

class _HeldDuringTake extends StatelessWidget {
  const _HeldDuringTake({required this.held, required this.child});

  final bool held;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!held) {
      return child;
    }
    return ExcludeFocus(
      child: IgnorePointer(
        child: Opacity(opacity: _heldDuringTakeOpacity, child: child),
      ),
    );
  }
}

class InputLevelRow extends ConsumerWidget {
  const InputLevelRow({super.key, this.ink, this.takeLevels});

  final Color? ink;
  final Stream<double>? takeLevels;

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
          levels: takeLevels,
        ),
      ],
    );
  }
}

class InputDeviceRow extends ConsumerStatefulWidget {
  const InputDeviceRow({
    super.key,
    this.androidVideo = false,
    this.ink,
    this.tone = GlassTone.paper,
    this.tapRegionGroupId,
    this.heldDuringTake = false,
  });

  final bool androidVideo;
  final Color? ink;
  final GlassTone tone;
  final Object? tapRegionGroupId;
  final bool heldDuringTake;

  @override
  ConsumerState<InputDeviceRow> createState() => _InputDeviceRowState();
}

class _InputDeviceRowState extends ConsumerState<InputDeviceRow> {
  List<AudioInput>? _inputs;
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

  void _refresh() {
    ref.invalidate(selectedAudioInputProvider);
    unawaited(_list());
  }

  Future<void> _choose(AudioInput chosen) async {
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
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
    if (widget.heldDuringTake) {
      return _PanelRow(
        key: inputDeviceRowKey,
        title: inputDeviceTitle,
        value:
            resolved?.label ??
            ref.watch(selectedAudioInputProvider).value?.label ??
            (storedId == null ? systemDefaultInputLabel : ''),
        ink: ink,
      );
    }
    final String label =
        resolved?.label ?? (storedId == null ? systemDefaultInputLabel : '');
    return AnchoredDropdown<AudioInput>(
      menuKey: inputDeviceMenuKey,
      tone: widget.tone,
      ink: ink,
      tapRegionGroupId: widget.tapRegionGroupId,
      choices: <AnchoredDropdownChoice<AudioInput>>[
        if (resolved != null)
          for (final AudioInput input in inputs ?? const <AudioInput>[])
            AnchoredDropdownChoice<AudioInput>(
              key: inputChoiceKey(input.id),
              value: input,
              label: input.label,
            ),
      ],
      current: resolved,
      onOpen: _refresh,
      onSelected: (AudioInput input) => unawaited(_choose(input)),
      builder: (BuildContext context, bool open, VoidCallback toggle) =>
          _PanelRow(
            key: inputDeviceRowKey,
            title: inputDeviceTitle,
            value: label,
            ink: ink,
            trailing: _dropdownGlyph(open),
            expanded: open,
            onTap: toggle,
          ),
    );
  }
}

class InputProfileRow extends ConsumerWidget {
  const InputProfileRow({
    super.key,
    this.ink,
    this.tone = GlassTone.paper,
    this.tapRegionGroupId,
    this.describe,
    this.onSaveFailed,
    this.rowBuilder,
  });

  final Color? ink;
  final GlassTone tone;
  final Object? tapRegionGroupId;
  final String Function(InputProfile profile)? describe;
  final VoidCallback? onSaveFailed;
  final DropdownRowBuilder? rowBuilder;

  void _choose(WidgetRef ref, InputProfile profile) {
    final SettingsRepository repository = ref.read(settingsRepositoryProvider);
    final InputProfile current =
        (ref.read(appSettingsProvider).value ?? AppSettings.defaults)
            .inputProfile;
    if (profile == current) {
      return;
    }
    unawaited(
      _store(() => repository.setInputProfile(profile), onFailed: onSaveFailed),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color ink = this.ink ?? context.colors.ink;
    final InputProfile current = _settingsOf(ref).inputProfile;
    final String Function(InputProfile profile)? describe = this.describe;
    final DropdownRowBuilder? rowBuilder = this.rowBuilder;
    return AnchoredDropdown<InputProfile>(
      menuKey: inputProfileMenuKey,
      tone: tone,
      ink: ink,
      tapRegionGroupId: tapRegionGroupId,
      choices: <AnchoredDropdownChoice<InputProfile>>[
        for (final InputProfile profile in InputProfile.values)
          AnchoredDropdownChoice<InputProfile>(
            key: inputProfileChoiceKey(profile),
            value: profile,
            label: profile.label,
            description: describe?.call(profile),
          ),
      ],
      current: current,
      onSelected: (InputProfile profile) => _choose(ref, profile),
      builder: (BuildContext context, bool open, VoidCallback toggle) =>
          rowBuilder == null
          ? _PanelRow(
              key: inputProfileRowKey,
              title: inputProfileTitle,
              value: current.label,
              ink: ink,
              trailing: _dropdownGlyph(open),
              expanded: open,
              onTap: toggle,
            )
          : KeyedSubtree(
              key: inputProfileRowKey,
              child: rowBuilder(
                context,
                inputProfileTitle,
                current.label,
                open,
                toggle,
              ),
            ),
    );
  }
}

class OutputDeviceRow extends ConsumerWidget {
  const OutputDeviceRow({
    super.key,
    this.ink,
    this.tone = GlassTone.paper,
    this.tapRegionGroupId,
  });

  final Color? ink;
  final GlassTone tone;
  final Object? tapRegionGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color ink = this.ink ?? context.colors.ink;
    final String? storedId = _settingsOf(ref).audioOutputId;
    final List<AudioOutputDevice>? outputs = ref
        .watch(audioOutputsProvider)
        .value;
    final AudioOutputDevice? resolved = outputs == null
        ? null
        : resolveAudioOutput(outputs, storedId);
    final String label =
        resolved?.name ?? (storedId == null ? systemOutputLabel : '');
    return AnchoredDropdown<AudioOutputDevice>(
      menuKey: outputDeviceMenuKey,
      tone: tone,
      ink: ink,
      tapRegionGroupId: tapRegionGroupId,
      choices: <AnchoredDropdownChoice<AudioOutputDevice>>[
        for (final AudioOutputDevice output
            in outputs ?? const <AudioOutputDevice>[])
          AnchoredDropdownChoice<AudioOutputDevice>(
            key: outputChoiceKey(output.id),
            value: output,
            label: output.name,
          ),
      ],
      current: resolved,
      onOpen: () => ref.invalidate(audioOutputsProvider),
      onSelected: (AudioOutputDevice output) {
        final SettingsRepository repository = ref.read(
          settingsRepositoryProvider,
        );
        unawaited(_store(() => repository.setAudioOutputId(output.id)));
      },
      builder: (BuildContext context, bool open, VoidCallback toggle) =>
          _PanelRow(
            key: outputDeviceRowKey,
            title: outputDeviceTitle,
            value: label,
            ink: ink,
            trailing: _dropdownGlyph(open),
            expanded: open,
            onTap: toggle,
          ),
    );
  }
}

class InputVolumeRow extends StatelessWidget {
  const InputVolumeRow({super.key, this.ink});

  final Color? ink;

  @override
  Widget build(BuildContext context) {
    return _VolumeRow(
      key: inputVolumeRowKey,
      title: inputVolumeTitle,
      maximum: inputVolumeMaximum,
      ink: ink,
      read: (AppSettings settings) => settings.inputVolume,
      write: (SettingsRepository repository, int volume) =>
          repository.setInputVolume(volume),
    );
  }
}

class OutputVolumeRow extends StatelessWidget {
  const OutputVolumeRow({super.key, this.ink});

  final Color? ink;

  @override
  Widget build(BuildContext context) {
    return _VolumeRow(
      key: outputVolumeRowKey,
      title: outputVolumeTitle,
      maximum: outputVolumeMaximum,
      ink: ink,
      read: (AppSettings settings) => settings.outputVolume,
      write: (SettingsRepository repository, int volume) =>
          repository.setOutputVolume(volume),
    );
  }
}

class _VolumeRow extends ConsumerStatefulWidget {
  const _VolumeRow({
    super.key,
    required this.title,
    required this.maximum,
    required this.read,
    required this.write,
    this.ink,
  });

  final String title;
  final int maximum;
  final int Function(AppSettings settings) read;
  final Future<void> Function(SettingsRepository repository, int volume) write;
  final Color? ink;

  @override
  ConsumerState<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends ConsumerState<_VolumeRow> {
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
      await widget.write(repository, volume);
    } catch (error, stackTrace) {
      debugPrint('${widget.title} was not saved: $error\n$stackTrace');
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
      final AppSettings? settings = next.value;
      if (released != null &&
          settings != null &&
          widget.read(settings) == released) {
        setState(() {
          _dragging = null;
          _released = null;
        });
      }
    });
    final Color ink = widget.ink ?? context.colors.ink;
    final double maximum = widget.maximum.toDouble();
    final double value = (_dragging ?? widget.read(_settingsOf(ref)).toDouble())
        .clamp(0, maximum)
        .toDouble();
    final String shown = '${value.round()}%';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: _PanelRow(title: widget.title, value: shown, ink: ink),
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
            label: widget.title,
            child: Slider(
              value: value,
              max: maximum,
              divisions: widget.maximum,
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

class _Glyph extends StatelessWidget {
  const _Glyph(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(child: Icon(icon));
  }
}
