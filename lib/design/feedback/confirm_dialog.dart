import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/phone_sheet.dart';
import 'dialog_host.dart';

const Key confirmDialogConfirmKey = ValueKey<String>('confirm-dialog-confirm');
const Key confirmDialogCancelKey = ValueKey<String>('confirm-dialog-cancel');

const String confirmDialogCancelLabel = 'Cancel';

const double _maxWidth = 370;
const double _borderWidth = 2;
const double _radius = 18;
const double _padding = 22;
const double _titleGap = 7;
const double _actionsGap = 20;
const double _buttonGap = 9;
const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(11));
const double _buttonBorderWidth = 1.5;
const double _buttonMinTarget = 48;

const EdgeInsets _sheetBodyPadding = EdgeInsets.fromLTRB(20, 10, 20, 4);
const EdgeInsets _sheetFooterPadding = EdgeInsets.fromLTRB(12, 14, 12, 12);
const double _sheetTitleSize = 20;
const double _sheetMessageGap = 6;

const double phoneSheetButtonHeight = 48;
const BorderRadius phoneSheetButtonRadius = BorderRadius.all(
  Radius.circular(14),
);
const double _phoneSheetButtonBorderWidth = 1.5;

const List<BoxShadow> _panelShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x99322314),
    offset: Offset(0, 22),
    blurRadius: 54,
    spreadRadius: -16,
  ),
];

const TextStyle _messageStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.55,
);

const TextStyle _sheetMessageStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.5,
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
  bool danger = false,
  String cancelLabel = confirmDialogCancelLabel,
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

  Color get confirmColor => danger ? Palette.danger : Palette.coral;
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
    return PhoneSheet(
      footerDirection: Axis.vertical,
      footerPadding: _sheetFooterPadding,
      actions: <Widget>[
        PhoneSheetButton(
          key: content.confirmKey,
          label: content.confirmLabel,
          background: content.confirmColor,
          foreground: Palette.onAccent,
          shadows: context.shadows.emphasis,
          onPressed: () => resolve(true),
        ),
        PhoneSheetButton(
          key: content.cancelKey,
          label: content.cancelLabel,
          background: colors.cardLight,
          foreground: colors.ink,
          autofocus: true,
          onPressed: () => resolve(false),
        ),
      ],
      child: Padding(
        padding: _sheetBodyPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              content.title,
              style: context.textStyles.headlineSerif.copyWith(
                fontSize: _sheetTitleSize,
              ),
            ),
            const SizedBox(height: _sheetMessageGap),
            Text(
              content.message,
              style: _sheetMessageStyle.copyWith(color: colors.mutedDeep),
            ),
          ],
        ),
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
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          height: phoneSheetButtonHeight,
          child: FocusRing(
            autofocus: autofocus,
            onPressed: onPressed,
            borderRadius: phoneSheetButtonRadius,
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
              child: Center(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _phoneSheetButtonStyle.copyWith(color: foreground),
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
    final FieldNotesColors colors = context.colors;
    final _ConfirmContent content = widget.content;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardWarm,
            border: Border.all(color: colors.line, width: _borderWidth),
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: _panelShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  content.title,
                  style: context.textStyles.headlineSerif.copyWith(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: _titleGap),
                Text(
                  content.message,
                  style: _messageStyle.copyWith(color: colors.mutedDeep),
                ),
                const SizedBox(height: _actionsGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _ConfirmDialogButton(
                      buttonKey: content.cancelKey,
                      label: content.cancelLabel,
                      background: colors.cardBright,
                      foreground: colors.ink,
                      boxShadow: null,
                      autofocus: true,
                      onTap: () => resolve(false),
                    ),
                    const SizedBox(width: _buttonGap),
                    _ConfirmDialogButton(
                      buttonKey: content.confirmKey,
                      label: content.confirmLabel,
                      background: content.confirmColor,
                      foreground: Palette.onAccent,
                      boxShadow: context.shadows.control,
                      onTap: () => resolve(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialogButton extends StatelessWidget {
  const _ConfirmDialogButton({
    required this.buttonKey,
    required this.label,
    required this.background,
    required this.foreground,
    required this.boxShadow,
    required this.onTap,
    this.autofocus = false,
  });

  final Key buttonKey;
  final String label;
  final Color background;
  final Color foreground;
  final List<BoxShadow>? boxShadow;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _buttonMinTarget,
            minHeight: _buttonMinTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              autofocus: autofocus,
              onPressed: onTap,
              borderRadius: _buttonRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(
                    color: context.colors.line,
                    width: _buttonBorderWidth,
                  ),
                  borderRadius: _buttonRadius,
                  boxShadow: boxShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 16,
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: TypographyTokens.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: foreground,
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
