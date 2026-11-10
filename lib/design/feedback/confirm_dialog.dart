import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/phone_sheet.dart';
import '../widgets/sticker_button.dart';
import '../widgets/sticker_card.dart';
import 'dialog_host.dart';

const Key confirmDialogConfirmKey = ValueKey<String>('confirm-dialog-confirm');
const Key confirmDialogCancelKey = ValueKey<String>('confirm-dialog-cancel');

const double _dialogWidth = 440;
const double _windowGutter = 16;
const double _dialogPadding = 24;
const double _messageGap = 8;
const double _actionsGap = 22;
const double _actionSpacing = 10;

const EdgeInsets _sheetBodyPadding = EdgeInsets.fromLTRB(20, 10, 20, 4);
const EdgeInsets _sheetFooterPadding = EdgeInsets.fromLTRB(12, 14, 12, 12);

const double phoneSheetButtonHeight = 48;
const BorderRadius phoneSheetButtonRadius = BorderRadius.all(
  Radius.circular(14),
);
const double _phoneSheetButtonBorderWidth = 1.5;
const EdgeInsets _phoneSheetButtonPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 8,
);
const double _lightForegroundLuminance = 0.5;

const TextStyle _messageStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 15,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const TextStyle _choiceLabelStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13.5,
  fontWeight: FontWeight.w600,
  height: 1,
);

const TextStyle _phoneSheetButtonStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
  Key confirmKey = confirmDialogConfirmKey,
  Key cancelKey = confirmDialogCancelKey,
}) async {
  final _ConfirmContent content = _ConfirmContent(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    danger: danger,
    confirmKey: confirmKey,
    cancelKey: cancelKey,
  );
  final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
  final bool? confirmed = layout == ShellLayout.bottomBar
      ? await showPhoneSheet<bool>(
          context,
          builder: (BuildContext sheetContext) =>
              _ConfirmSheet(content: content),
        )
      : await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierColor: Palette.toolbarInk.withValues(alpha: 0.42),
          builder: (BuildContext dialogContext) =>
              DialogHost(child: _ConfirmDialog(content: content)),
        );
  return confirmed ?? false;
}

@immutable
class _ConfirmContent {
  const _ConfirmContent({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.danger,
    required this.confirmKey,
    required this.cancelKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final Key confirmKey;
  final Key cancelKey;
}

List<Widget> confirmChoicesInOrder(
  TargetPlatform platform, {
  required Widget safe,
  required Widget action,
}) {
  final bool actionLeads =
      platform == TargetPlatform.windows ||
      resolveShellLayout(platform) == ShellLayout.bottomBar;
  return actionLeads ? <Widget>[action, safe] : <Widget>[safe, action];
}

class ConfirmChoiceButton extends StatelessWidget {
  const ConfirmChoiceButton.safe({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.ground = StickerGround.page,
  }) : danger = false,
       takesFocus = true;

  const ConfirmChoiceButton.action({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.ground = StickerGround.page,
    this.danger = true,
  }) : takesFocus = false;

  final String label;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final StickerGround ground;
  final bool danger;
  final bool takesFocus;

  StickerButtonVariant get _variant => switch ((takesFocus, danger, ground)) {
    (true, _, StickerGround.page) => StickerButtonVariant.secondary,
    (true, _, StickerGround.media) => StickerButtonVariant.stageSoft,
    (false, true, _) => StickerButtonVariant.danger,
    (false, false, _) => StickerButtonVariant.primary,
  };

  @override
  Widget build(BuildContext context) {
    return MinTarget.button(
      child: StickerButton(
        key: buttonKey,
        label: label,
        variant: _variant,
        ground: ground,
        focusSurface: switch (ground) {
          StickerGround.page => FocusRingSurface.light,
          StickerGround.media => FocusRingSurface.dark,
        },
        labelStyle: _choiceLabelStyle,
        autofocus: takesFocus,
        onPressed: onPressed,
      ),
    );
  }
}

class _ConfirmWords extends StatelessWidget {
  const _ConfirmWords({required this.content});

  final _ConfirmContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(content.title, style: context.textStyles.title),
        const SizedBox(height: _messageGap),
        Text(
          content.message,
          style: _messageStyle.copyWith(color: context.colors.inkSoft),
        ),
      ],
    );
  }
}

mixin _ResolvesOnce<T extends StatefulWidget> on State<T> {
  bool _resolved = false;

  void resolve(bool result) {
    if (_resolved) {
      return;
    }
    _resolved = true;
    Navigator.of(context).pop(result);
  }
}

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.content});

  final _ConfirmContent content;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet>
    with _ResolvesOnce<_ConfirmSheet> {
  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final _ConfirmContent content = widget.content;
    final Widget action = content.danger
        ? ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: phoneSheetButtonHeight,
            ),
            child: StickerButton(
              key: content.confirmKey,
              label: content.confirmLabel,
              variant: StickerButtonVariant.danger,
              labelStyle: _phoneSheetButtonStyle,
              borderRadius: phoneSheetButtonRadius,
              onPressed: () => resolve(true),
            ),
          )
        : PhoneSheetButton(
            key: content.confirmKey,
            label: content.confirmLabel,
            background: Palette.coral,
            foreground: Palette.onAccent,
            shadows: context.shadows.emphasis,
            onPressed: () => resolve(true),
          );
    return PhoneSheet(
      footerDirection: Axis.vertical,
      footerPadding: _sheetFooterPadding,
      actions: confirmChoicesInOrder(
        Theme.of(context).platform,
        safe: PhoneSheetButton(
          key: content.cancelKey,
          label: content.cancelLabel,
          background: colors.cardLight,
          foreground: colors.ink,
          autofocus: true,
          onPressed: () => resolve(false),
        ),
        action: action,
      ),
      child: Padding(
        padding: _sheetBodyPadding,
        child: _ConfirmWords(content: content),
      ),
    );
  }
}

class PhoneSheetButton extends StatelessWidget {
  const PhoneSheetButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.shadows,
    this.autofocus = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;
  final List<BoxShadow>? shadows;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: label,
      onPressed: onPressed,
      autofocus: autofocus,
      borderRadius: phoneSheetButtonRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: phoneSheetButtonHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: context.colors.line,
              width: _phoneSheetButtonBorderWidth,
            ),
            borderRadius: phoneSheetButtonRadius,
            boxShadow: shadows,
          ),
          child: _HoverVeil(
            hovered: hovered,
            foreground: foreground,
            borderRadius: phoneSheetButtonRadius,
            child: Center(
              child: Padding(
                padding: _phoneSheetButtonPadding,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _phoneSheetButtonStyle.copyWith(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverVeil extends StatelessWidget {
  const _HoverVeil({
    required this.hovered,
    required this.foreground,
    required this.borderRadius,
    required this.child,
  });

  final bool hovered;
  final Color foreground;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FocusRingSurface surface =
        foreground.computeLuminance() > _lightForegroundLuminance
        ? FocusRingSurface.dark
        : FocusRingSurface.light;
    return HoverFill(
      hovered: hovered,
      surface: surface,
      borderRadius: borderRadius,
      position: DecorationPosition.background,
      child: child,
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.content});

  final _ConfirmContent content;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog>
    with _ResolvesOnce<_ConfirmDialog> {
  @override
  Widget build(BuildContext context) {
    final _ConfirmContent content = widget.content;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _windowGutter),
        child: SizedBox(
          width: _dialogWidth,
          child: StickerCard(
            surface: context.colors.cardBright,
            padding: const EdgeInsets.all(_dialogPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ConfirmWords(content: content),
                const SizedBox(height: _actionsGap),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: _actionSpacing,
                  runSpacing: _actionSpacing,
                  children: confirmChoicesInOrder(
                    Theme.of(context).platform,
                    safe: ConfirmChoiceButton.safe(
                      buttonKey: content.cancelKey,
                      label: content.cancelLabel,
                      onPressed: () => resolve(false),
                    ),
                    action: ConfirmChoiceButton.action(
                      buttonKey: content.confirmKey,
                      label: content.confirmLabel,
                      danger: content.danger,
                      onPressed: () => resolve(true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
