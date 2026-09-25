import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'dialog_host.dart';

const Key confirmDialogConfirmKey = ValueKey<String>('confirm-dialog-confirm');
const Key confirmDialogCancelKey = ValueKey<String>('confirm-dialog-cancel');

const double _maxWidth = 370;
const double _borderWidth = 2;
const double _radius = 18;
const double _padding = 22;
const double _titleGap = 7;
const double _actionsGap = 20;
const double _buttonGap = 9;
const double _buttonRadius = 11;
const double _buttonBorderWidth = 1.5;
const double _buttonMinTarget = 48;

const List<BoxShadow> _panelShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x99322314),
    offset: Offset(0, 22),
    blurRadius: 54,
    spreadRadius: -16,
  ),
];

const List<BoxShadow> _confirmButtonShadow = <BoxShadow>[
  BoxShadow(
    color: Palette.ink,
    offset: Offset(1.5, 1.5),
  ),
];

const TextStyle _messageStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.55,
  color: Palette.mutedDeep,
);

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Palette.toolbarInk.withValues(alpha: 0.42),
    builder: (BuildContext dialogContext) => DialogHost(
      child: _ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        danger: danger,
      ),
    ),
  );
  return confirmed ?? false;
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.danger,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _resolved = false;

  void _resolve(bool result) {
    if (_resolved) {
      return;
    }
    _resolved = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.cardWarm,
            border: Border.all(color: Palette.ink, width: _borderWidth),
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
                  widget.title,
                  style: TypographyTokens.headlineSerif.copyWith(fontSize: 20),
                ),
                const SizedBox(height: _titleGap),
                Text(widget.message, style: _messageStyle),
                const SizedBox(height: _actionsGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _ConfirmDialogButton(
                      buttonKey: confirmDialogCancelKey,
                      label: 'Cancel',
                      background: Palette.cardBright,
                      foreground: Palette.ink,
                      boxShadow: null,
                      onTap: () => _resolve(false),
                    ),
                    const SizedBox(width: _buttonGap),
                    _ConfirmDialogButton(
                      buttonKey: confirmDialogConfirmKey,
                      label: widget.confirmLabel,
                      background: widget.danger ? Palette.danger : Palette.coral,
                      foreground: Palette.onAccent,
                      boxShadow: _confirmButtonShadow,
                      onTap: () => _resolve(true),
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
  });

  final Key buttonKey;
  final String label;
  final Color background;
  final Color foreground;
  final List<BoxShadow>? boxShadow;
  final VoidCallback onTap;

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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: Palette.ink,
                  width: _buttonBorderWidth,
                ),
                borderRadius: BorderRadius.circular(_buttonRadius),
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
    );
  }
}
