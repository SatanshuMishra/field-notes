import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart'
    show shellSidebarWidth;
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding_surface.dart';

const Key onboardingAppearanceKey = ValueKey<String>('onboarding-appearance');
const Key onboardingAppearanceHandleKey = ValueKey<String>(
  'onboarding-appearance-handle',
);
const Key onboardingAppearanceBackKey = ValueKey<String>(
  'onboarding-appearance-back',
);
const Key onboardingAppearanceContinueKey = ValueKey<String>(
  'onboarding-appearance-continue',
);

Key onboardingAppearanceOptionKey(Appearance appearance) =>
    ValueKey<String>('onboarding-appearance-${appearance.id}');

const String _kicker = 'look & feel';
const String _title = 'Light or dark?';
const String _sidebarNote =
    'Preview it on the journal behind. Change anytime in Settings.';
const String _bottomBarNote = 'Preview it above. Change anytime in Settings.';
const String _backLabel = 'Back';
const String _continueLabel = 'Continue';
const String _continueHint = '↵ to continue';

const double _dockedWidth = 560;
const double _dockedBottom = 24;
const double _dockedInset = 49;
const double _dockedSideInset = 16;
const double _dockedTopRoom = 24;
const double _dockedNoteWidth = 210;
const double _sheetRadius = 26;
const double _sheetBorderWidth = 2;
const double _sheetTopRoom = 24;
const double _handleWidth = 36;
const double _handleHeight = 4;
const double _sidebarControlHeight = 40;
const double _bottomBarControlHeight = 48;
const double _minTapTarget = 48;
const double _backGlyphSize = 22;
const double _optionBorderWidth = 2;
const double _tileBorderWidth = 1.5;
const double _tileBarOpacity = 0.75;

const EdgeInsets _dockedPadding = EdgeInsets.fromLTRB(22, 20, 22, 18);
const EdgeInsets _sheetPadding = EdgeInsets.fromLTRB(16, 10, 16, 22);

const BoxShadow _sheetLift = BoxShadow(
  color: Color(0x8C140C06),
  offset: Offset(0, -18),
  blurRadius: 40,
  spreadRadius: -18,
);

const TextStyle _sidebarContinueStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: Palette.onAccent,
);

TextStyle _kickerStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: colors.accentInk,
);

TextStyle _titleStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.serif,
  fontSize: 26,
  fontWeight: FontWeight.w500,
  height: 1.1,
  color: colors.ink,
);

TextStyle _noteStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.4,
  color: colors.muted,
);

TextStyle _hintStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  color: colors.placeholder,
);

TextStyle _backStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: colors.ink,
);

TextStyle _optionLabelStyle(
  FieldNotesColors colors, {
  required bool selected,
}) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: selected ? colors.accentInk : colors.ink,
);

TextStyle _optionSublabelStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11,
  fontWeight: FontWeight.w400,
  color: colors.muted,
);

const List<({Appearance appearance, String label, String sublabel})> _options =
    <({Appearance appearance, String label, String sublabel})>[
      (appearance: Appearance.light, label: 'Light', sublabel: 'warm paper'),
      (appearance: Appearance.dark, label: 'Dark', sublabel: 'evening ink'),
      (
        appearance: Appearance.system,
        label: 'System',
        sublabel: 'match device',
      ),
    ];

class OnboardingAppearance extends ConsumerWidget {
  const OnboardingAppearance({
    super.key,
    required this.layout,
    required this.onContinue,
    required this.onBack,
  });

  final ShellLayout layout;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  bool get _sidebar => layout == ShellLayout.sidebar;

  bool _optionFocused() {
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    return focused?.findAncestorWidgetOfExactType<_AppearanceOption>() != null;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      onContinue();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      onBack();
      return KeyEventResult.handled;
    }
    if (_optionFocused()) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.arrowRight) {
      onContinue();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    Appearance selected,
    Appearance appearance,
  ) async {
    if (appearance == selected) {
      return;
    }
    final SettingsWriteResult result = await ref
        .read(settingsControllerProvider)
        .setAppearance(appearance);
    if (result is SettingsWriteFailed && context.mounted) {
      showTransientToast(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FieldNotesColors colors = context.colors;
    final Appearance selected = ref.watch(appearanceProvider);
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!_sidebar) ...<Widget>[
          Center(
            child: SizedBox(
              key: onboardingAppearanceHandleKey,
              width: _handleWidth,
              height: _handleHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.ink30,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(colors),
                SizedBox(height: _sidebar ? 16 : 14),
                _optionRow(context, ref, selected),
              ],
            ),
          ),
        ),
        SizedBox(height: _sidebar ? 16 : 14),
        _footer(colors),
      ],
    );
    return BlockSemantics(
      child: FocusScope(
        onKeyEvent: _handleKey,
        child: FocusTraversalGroup(
          child: _sidebar ? _docked(colors, body) : _sheet(context, body),
        ),
      ),
    );
  }

  Widget _docked(FieldNotesColors colors, Widget body) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double column = math.max(
          0,
          constraints.maxWidth - shellSidebarWidth,
        );
        final double width = math.min(
          _dockedWidth,
          math.max(0, column - 2 * _dockedSideInset),
        );
        final double inset = math.min(_dockedInset, (column - width) / 2);
        return Stack(
          children: <Widget>[
            Positioned(
              left: shellSidebarWidth + inset,
              bottom: _dockedBottom,
              width: width,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(
                    0,
                    constraints.maxHeight - _dockedBottom - _dockedTopRoom,
                  ),
                ),
                child: Container(
                  key: onboardingAppearanceKey,
                  clipBehavior: Clip.antiAlias,
                  decoration: onboardingCardDecoration(
                    colors,
                    radius: Shapes.radiusXl,
                  ),
                  padding: _dockedPadding,
                  child: body,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sheet(BuildContext context, Widget body) {
    final FieldNotesColors colors = context.colors;
    final EdgeInsets safeArea = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(
                0,
                constraints.maxHeight - safeArea.top - _sheetTopRoom,
              ),
            ),
            child: Container(
              key: onboardingAppearanceKey,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.composerPaper,
                border: Border(
                  top: BorderSide(color: colors.line, width: _sheetBorderWidth),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_sheetRadius),
                ),
                boxShadow: const <BoxShadow>[_sheetLift],
              ),
              padding: _sheetPadding.copyWith(
                bottom: _sheetPadding.bottom + safeArea.bottom,
              ),
              child: body,
            ),
          ),
        );
      },
    );
  }

  Widget _header(FieldNotesColors colors) {
    final Widget heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _kicker,
          style: _sidebar
              ? _kickerStyle(colors)
              : _kickerStyle(colors).copyWith(fontSize: 15),
        ),
        Semantics(
          header: true,
          child: Text(
            _title,
            style: _sidebar
                ? _titleStyle(colors)
                : _titleStyle(colors).copyWith(fontSize: 23),
          ),
        ),
      ],
    );
    if (!_sidebar) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          heading,
          const SizedBox(height: 4),
          Text(
            _bottomBarNote,
            style: _noteStyle(colors).copyWith(fontSize: 11.5),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: heading),
        const SizedBox(width: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _dockedNoteWidth),
          child: Text(
            _sidebarNote,
            textAlign: TextAlign.right,
            style: _noteStyle(colors),
          ),
        ),
      ],
    );
  }

  Widget _optionRow(BuildContext context, WidgetRef ref, Appearance selected) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (
                int index,
                ({Appearance appearance, String label, String sublabel}) option,
              )
              in _options.indexed) ...<Widget>[
            if (index > 0) SizedBox(width: _sidebar ? 10 : 7),
            Expanded(
              child: _AppearanceOption(
                key: onboardingAppearanceOptionKey(option.appearance),
                appearance: option.appearance,
                label: option.label,
                sublabel: option.sublabel,
                selected: option.appearance == selected,
                compact: !_sidebar,
                onPressed: () =>
                    _choose(context, ref, selected, option.appearance),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer(FieldNotesColors colors) {
    if (_sidebar) {
      return Row(
        children: <Widget>[
          _OutlinedBackButton(onPressed: onBack),
          const Spacer(),
          ExcludeSemantics(
            child: Text(_continueHint, style: _hintStyle(colors)),
          ),
          const SizedBox(width: 10),
          OnboardingPrimaryButton(
            key: onboardingAppearanceContinueKey,
            label: _continueLabel,
            onPressed: onContinue,
            height: _sidebarControlHeight,
            borderRadius: const BorderRadius.all(
              Radius.circular(Shapes.radiusControl),
            ),
            labelStyle: _sidebarContinueStyle,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            autofocus: true,
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        _SquareBackButton(onPressed: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: OnboardingPrimaryButton(
            key: onboardingAppearanceContinueKey,
            label: _continueLabel,
            onPressed: onContinue,
            height: _bottomBarControlHeight,
            borderRadius: const BorderRadius.all(
              Radius.circular(Shapes.radiusMd),
            ),
            expand: true,
            autofocus: true,
          ),
        ),
      ],
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    super.key,
    required this.appearance,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final Appearance appearance;
  final String label;
  final String sublabel;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(Shapes.radiusMd),
    );
    final TextStyle labelStyle = _optionLabelStyle(colors, selected: selected);
    final TextStyle sublabelStyle = _optionSublabelStyle(colors);
    return Semantics(
      button: true,
      enabled: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$label, $sublabel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minTapTarget),
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? colors.cardLight : colors.cardWarm,
                  border: Border.all(
                    color: selected ? Palette.coral : colors.ink22,
                    width: _optionBorderWidth,
                  ),
                  borderRadius: radius,
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: colors.shadow,
                            offset: const Offset(2, 2),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 7 : 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _AppearanceTile(appearance: appearance, compact: compact),
                      SizedBox(height: compact ? 7 : 8),
                      Text(
                        label,
                        style: compact
                            ? labelStyle.copyWith(fontSize: 13)
                            : labelStyle,
                      ),
                      SizedBox(height: compact ? 3 : 4),
                      Text(
                        sublabel,
                        style: compact
                            ? sublabelStyle.copyWith(fontSize: 10)
                            : sublabelStyle,
                      ),
                    ],
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

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({required this.appearance, required this.compact});

  final Appearance appearance;
  final bool compact;

  Color get _barColor => switch (appearance) {
    Appearance.light => FieldNotesColors.light.ink,
    Appearance.dark => FieldNotesColors.dark.ink,
    Appearance.system => FieldNotesColors.dark.line,
  }.withValues(alpha: _tileBarOpacity);

  Color? get _fill => switch (appearance) {
    Appearance.light => FieldNotesColors.light.panelTop,
    Appearance.dark => FieldNotesColors.dark.panelTop,
    Appearance.system => null,
  };

  Gradient? get _split => switch (appearance) {
    Appearance.system => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        FieldNotesColors.light.panelTop,
        FieldNotesColors.light.panelTop,
        FieldNotesColors.dark.panelTop,
        FieldNotesColors.dark.panelTop,
      ],
      stops: const <double>[0, 0.5, 0.5, 1],
    ),
    Appearance.light || Appearance.dark => null,
  };

  Widget _bar(double widthFactor) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: SizedBox(
        height: compact ? 4 : 5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _barColor,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double dot = compact ? 10 : 12;
    return SizedBox(
      height: compact ? 46 : 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fill,
          gradient: _split,
          border: Border.all(
            color: FieldNotesColors.light.ink35,
            width: _tileBorderWidth,
          ),
          borderRadius: const BorderRadius.all(
            Radius.circular(Shapes.radiusThumb),
          ),
        ),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _bar(0.62),
                  SizedBox(height: compact ? 5 : 6),
                  _bar(0.4),
                ],
              ),
            ),
            Positioned(
              right: compact ? 7 : 10,
              top: compact ? 7 : 9,
              child: SizedBox.square(
                dimension: dot,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.coral,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedBackButton extends StatelessWidget {
  const _OutlinedBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(Shapes.radiusControl),
    );
    return Semantics(
      key: onboardingAppearanceBackKey,
      button: true,
      enabled: true,
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
              onPressed: onPressed,
              borderRadius: radius,
              child: SizedBox(
                height: _sidebarControlHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colors.ink35,
                      width: Shapes.outlineWidth,
                    ),
                    borderRadius: radius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      child: ExcludeSemantics(
                        child: Text(_backLabel, style: _backStyle(colors)),
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

class _SquareBackButton extends StatelessWidget {
  const _SquareBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(Shapes.radiusMd),
    );
    return Semantics(
      key: onboardingAppearanceBackKey,
      button: true,
      enabled: true,
      label: _backLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: radius,
          child: SizedBox.square(
            dimension: _bottomBarControlHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.ink35,
                  width: Shapes.outlineWidth,
                ),
                borderRadius: radius,
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                size: _backGlyphSize,
                color: colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
