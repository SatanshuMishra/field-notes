import 'dart:ui' show PlatformDispatcher;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_surface.dart';
import 'setup_reminder_step.dart';
import 'setup_storage_step.dart';
import 'setup_summary.dart';
import 'setup_week_step.dart';
import 'week_start_suggestion.dart';

enum SetupOutcome { finished, skipped }

const String setupSaveErrorMessage = 'Couldn’t save your choices. Try again.';

const Key setupPrimaryKey = ValueKey<String>('setup-primary');
const Key setupBackKey = ValueKey<String>('setup-back');
const Key setupSkipKey = ValueKey<String>('setup-skip');

Key setupProgressKey(int index) => ValueKey<String>('setup-progress-$index');

const String _sidebarSkipLabel = 'Skip · use defaults';
const String _bottomBarSkipLabel = 'Use defaults';
const String _backLabel = 'Back';
const String _continueHint = '↵ to continue';

const Color _progressDone = Color(0xFFDBA493);
const double _progressHeight = 5;
const double _progressGap = 4;
const double _sidebarBackHeight = 40;
const double _sidebarPrimaryHeight = 40;
const double _bottomBarControlHeight = 48;
const double _minTapTarget = 48;
const double _backGlyphSize = 22;

const WeekStart _skipWeekStart = WeekStart.monday;

const TextStyle _titleStyle = TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 28,
  fontWeight: FontWeight.w500,
  height: 1.1,
  color: Palette.ink,
);

const TextStyle _subtitleStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12.5,
  fontWeight: FontWeight.w400,
  height: 1.45,
  color: Palette.muted,
);

const TextStyle _skipStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: Palette.mutedDeep,
);

const TextStyle _hintStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  color: Palette.placeholder,
);

const TextStyle _backStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: Palette.ink,
);

const TextStyle _sidebarPrimaryStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: Palette.onAccent,
);

const TextStyle _errorStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: Palette.danger,
);

enum _SetupStep {
  reminder('A gentle daily nudge?', null, 'Continue'),
  week(
    'Your week starts on',
    'Used by Calendar and your weekly garden.',
    'Continue',
  ),
  storage(
    'Where should entries live?',
    'Everything stays on this device for now.',
    'Finish',
  ),
  summary(
    'You’re all set',
    'Change any of this later in Settings.',
    'Start journaling',
  );

  const _SetupStep(this.title, this.subtitle, this.primaryLabel);

  final String title;
  final String? subtitle;
  final String primaryLabel;

  bool get skippable => this != _SetupStep.summary;
}

class _SetupChoices {
  const _SetupChoices({
    required this.reminderEnabled,
    required this.preset,
    required this.time,
    required this.weekStart,
  });

  final bool reminderEnabled;
  final ReminderPreset preset;
  final ReminderTime time;
  final WeekStart weekStart;

  _SetupChoices copyWith({
    bool? reminderEnabled,
    ReminderPreset? preset,
    ReminderTime? time,
    WeekStart? weekStart,
  }) {
    return _SetupChoices(
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      preset: preset ?? this.preset,
      time: time ?? this.time,
      weekStart: weekStart ?? this.weekStart,
    );
  }
}

class OnboardingSetup extends ConsumerStatefulWidget {
  const OnboardingSetup({
    super.key,
    required this.layout,
    required this.onBackOut,
    required this.onDone,
    this.countryCode,
  });

  final ShellLayout layout;
  final VoidCallback onBackOut;
  final ValueChanged<SetupOutcome> onDone;
  final String? countryCode;

  @override
  ConsumerState<OnboardingSetup> createState() => _OnboardingSetupState();
}

class _OnboardingSetupState extends ConsumerState<OnboardingSetup> {
  late final WeekStart _suggestion = suggestWeekStart(
    widget.countryCode ?? PlatformDispatcher.instance.locale.countryCode,
  );
  late _SetupChoices _choices = _SetupChoices(
    reminderEnabled: true,
    preset: ReminderPreset.evening,
    time: ReminderTime.defaultTime,
    weekStart: _suggestion,
  );
  final FocusNode _primaryFocus = FocusNode(debugLabel: 'setup-primary');
  _SetupStep _step = _SetupStep.reminder;
  bool _permissionAsked = false;
  bool _asking = false;
  bool _writing = false;
  bool _saveFailed = false;

  bool get _sidebar => widget.layout == ShellLayout.sidebar;

  bool get _busy => _asking || _writing;

  @override
  void dispose() {
    _primaryFocus.dispose();
    super.dispose();
  }

  void _goTo(_SetupStep step) {
    setState(() {
      _step = step;
      _saveFailed = false;
    });
  }

  void _choose(_SetupChoices choices) {
    setState(() => _choices = choices);
  }

  Future<void> _primary() async {
    if (_busy) {
      return;
    }
    switch (_step) {
      case _SetupStep.reminder:
        await _continueFromReminder();
      case _SetupStep.week:
        _goTo(_SetupStep.storage);
      case _SetupStep.storage:
        _goTo(_SetupStep.summary);
      case _SetupStep.summary:
        await _commit(
          reminderEnabled: _choices.reminderEnabled,
          time: _choices.time,
          weekStart: _choices.weekStart,
          outcome: SetupOutcome.finished,
        );
    }
  }

  void _back() {
    if (_busy) {
      return;
    }
    switch (_step) {
      case _SetupStep.reminder:
        widget.onBackOut();
      case _SetupStep.week:
        _goTo(_SetupStep.reminder);
      case _SetupStep.storage:
        _goTo(_SetupStep.week);
      case _SetupStep.summary:
        _goTo(_SetupStep.storage);
    }
  }

  Future<void> _skip() async {
    if (_busy) {
      return;
    }
    await _commit(
      reminderEnabled: true,
      time: ReminderTime.defaultTime,
      weekStart: _skipWeekStart,
      outcome: SetupOutcome.skipped,
    );
  }

  Future<void> _continueFromReminder() async {
    if (!_choices.reminderEnabled || _permissionAsked) {
      _goTo(_SetupStep.week);
      return;
    }
    setState(() {
      _asking = true;
      _permissionAsked = true;
    });
    final bool denied = await _requestPermission();
    if (!mounted) {
      return;
    }
    setState(() {
      _asking = false;
      _choices = denied ? _choices.copyWith(reminderEnabled: false) : _choices;
      _step = _SetupStep.week;
      _saveFailed = false;
    });
  }

  Future<bool> _requestPermission() async {
    try {
      await ref
          .read(reminderPermissionStatusProvider.notifier)
          .requestUnlessGranted();
      final ReminderPermission status = await ref.read(
        reminderPermissionStatusProvider.future,
      );
      return status == ReminderPermission.denied;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return true;
    }
  }

  Future<void> _commit({
    required bool reminderEnabled,
    required ReminderTime time,
    required WeekStart weekStart,
    required SetupOutcome outcome,
  }) async {
    final SettingsController controller = ref.read(settingsControllerProvider);
    setState(() {
      _writing = true;
      _saveFailed = false;
    });
    final bool saved = await _writeAll(<Future<SettingsWriteResult> Function()>[
      () => controller.setReminderEnabled(reminderEnabled),
      () => controller.setReminderTime(time),
      () => controller.setWeekStart(weekStart),
    ]);
    if (!mounted) {
      return;
    }
    if (saved) {
      widget.onDone(outcome);
      return;
    }
    setState(() {
      _writing = false;
      _saveFailed = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _primaryFocus.requestFocus();
      }
    });
  }

  static Future<bool> _writeAll(
    List<Future<SettingsWriteResult> Function()> writes,
  ) async {
    for (final Future<SettingsWriteResult> Function() write in writes) {
      if (await write() is! SettingsWriteSucceeded) {
        return false;
      }
    }
    return true;
  }

  bool _typingInField() {
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) {
      return false;
    }
    return focused.findAncestorWidgetOfExactType<EditableText>() != null ||
        focused.findAncestorWidgetOfExactType<SettingsTimeField>() != null;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _skip();
      return KeyEventResult.handled;
    }
    if (_typingInField()) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.arrowRight) {
      _primary();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingSurface(
      layout: widget.layout,
      child: FocusScope(
        onKeyEvent: _handleKey,
        child: FocusTraversalGroup(
          child: _sidebar ? _sidebarFrame() : _bottomBarFrame(),
        ),
      ),
    );
  }

  Widget _sidebarFrame() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 14, 6),
          child: _header(),
        ),
        const DashedDivider(color: Palette.ink20),
        Flexible(
          child: SingleChildScrollView(
            key: ValueKey<_SetupStep>(_step),
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 10),
            child: _body(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: _footer(),
        ),
      ],
    );
  }

  Widget _bottomBarFrame() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey<_SetupStep>(_step),
              padding: const EdgeInsets.only(top: 18, bottom: 12),
              child: _body(),
            ),
          ),
          const SizedBox(height: 10),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minTapTarget),
      child: Row(
        children: <Widget>[
          Expanded(child: _progress()),
          if (_step.skippable) ...<Widget>[
            SizedBox(width: _sidebar ? 18 : 12),
            OnboardingTextButton(
              key: setupSkipKey,
              label: _sidebar ? _sidebarSkipLabel : _bottomBarSkipLabel,
              onPressed: _busy ? null : _skip,
              style: _sidebar ? _skipStyle : _skipStyle.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _progress() {
    final bool complete = _step == _SetupStep.summary;
    final int current = _step.index;
    return Semantics(
      label: complete ? 'Setup complete' : 'Step ${current + 1} of 3',
      child: Row(
        children: <Widget>[
          for (int index = 0; index < 3; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: _progressGap),
            Expanded(
              child: SizedBox(
                height: _progressHeight,
                child: DecoratedBox(
                  key: setupProgressKey(index),
                  decoration: BoxDecoration(
                    color: complete || index < current
                        ? _progressDone
                        : index == current
                        ? Palette.coral
                        : Palette.ink18,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    final String? subtitle = _step.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _step == _SetupStep.summary ? 'all done' : 'basic setup',
          style: TypographyTokens.pageEyebrowAccent,
        ),
        Semantics(
          header: true,
          child: Text(
            _step.title,
            style: _sidebar ? _titleStyle : _titleStyle.copyWith(fontSize: 25),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: _sidebar
                ? _subtitleStyle
                : _subtitleStyle.copyWith(fontSize: 12),
          ),
        ],
        SizedBox(height: _step == _SetupStep.summary ? 20 : 18),
        _content(),
      ],
    );
  }

  Widget _content() {
    return switch (_step) {
      _SetupStep.reminder => SetupReminderStep(
        layout: widget.layout,
        enabled: _choices.reminderEnabled,
        preset: _choices.preset,
        time: _choices.time,
        onEnabledChanged: (bool value) =>
            _choose(_choices.copyWith(reminderEnabled: value)),
        onPresetChanged: (ReminderPreset preset) => _choose(
          _choices.copyWith(preset: preset, time: preset.time ?? _choices.time),
        ),
        onTimeChanged: (ReminderTime time) =>
            _choose(_choices.copyWith(time: time)),
      ),
      _SetupStep.week => SetupWeekStep(
        layout: widget.layout,
        suggestion: _suggestion,
        selected: _choices.weekStart,
        onChanged: (WeekStart start) =>
            _choose(_choices.copyWith(weekStart: start)),
      ),
      _SetupStep.storage => SetupStorageStep(layout: widget.layout),
      _SetupStep.summary => SetupSummary(
        layout: widget.layout,
        reminderEnabled: _choices.reminderEnabled,
        time: _choices.time,
        weekStart: _choices.weekStart,
        onChangeReminder: () => _goTo(_SetupStep.reminder),
        onChangeWeek: () => _goTo(_SetupStep.week),
        onChangeStorage: () => _goTo(_SetupStep.storage),
      ),
    };
  }

  Widget _footer() {
    final VoidCallback? primary = _writing ? null : _primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_saveFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                setupSaveErrorMessage,
                textAlign: _sidebar ? TextAlign.end : TextAlign.center,
                style: _errorStyle,
              ),
            ),
          ),
        Row(
          children: <Widget>[
            if (_sidebar) ...<Widget>[
              _OutlinedBackButton(onPressed: _busy ? null : _back),
              const Spacer(),
              const ExcludeSemantics(
                child: Text(_continueHint, style: _hintStyle),
              ),
              const SizedBox(width: 10),
              OnboardingPrimaryButton(
                key: setupPrimaryKey,
                label: _step.primaryLabel,
                onPressed: primary,
                focusNode: _primaryFocus,
                height: _sidebarPrimaryHeight,
                borderRadius: const BorderRadius.all(
                  Radius.circular(Shapes.radiusControl),
                ),
                labelStyle: _sidebarPrimaryStyle,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                autofocus: true,
              ),
            ] else ...<Widget>[
              _RoundBackButton(onPressed: _busy ? null : _back),
              const SizedBox(width: 10),
              Expanded(
                child: OnboardingPrimaryButton(
                  key: setupPrimaryKey,
                  label: _step.primaryLabel,
                  onPressed: primary,
                  focusNode: _primaryFocus,
                  height: _bottomBarControlHeight,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(Shapes.radiusMd),
                  ),
                  expand: true,
                  autofocus: true,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _OutlinedBackButton extends StatelessWidget {
  const _OutlinedBackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(Shapes.radiusControl),
    );
    return Semantics(
      key: setupBackKey,
      button: true,
      enabled: onPressed != null,
      label: _backLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              enabled: onPressed != null,
              onPressed: onPressed,
              borderRadius: radius,
              child: SizedBox(
                height: _sidebarBackHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Palette.ink35,
                      width: Shapes.outlineWidth,
                    ),
                    borderRadius: radius,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      child: ExcludeSemantics(
                        child: Text(_backLabel, style: _backStyle),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: setupBackKey,
      button: true,
      enabled: onPressed != null,
      label: _backLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          enabled: onPressed != null,
          onPressed: onPressed,
          borderRadius: const BorderRadius.all(
            Radius.circular(_bottomBarControlHeight / 2),
          ),
          child: SizedBox.square(
            dimension: _bottomBarControlHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Palette.ink35,
                  width: Shapes.outlineWidth,
                ),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                size: _backGlyphSize,
                color: Palette.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
