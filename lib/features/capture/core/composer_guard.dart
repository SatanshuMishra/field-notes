import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

const String composerDiscardTitle = 'Discard this note?';
const String composerDiscardMessage =
    'Your unsaved changes will be lost.';
const String composerKeepEditingLabel = 'Keep editing';
const String composerDiscardLabel = 'Discard';
const Key composerKeepEditingKey = ValueKey<String>('composer-keep-editing');
const Key composerDiscardKey = ValueKey<String>('composer-discard');

const double _confirmMaxWidth = 420;
const double _confirmTitleGap = 8;
const double _confirmActionsGap = 20;
const double _confirmActionSpacing = 12;

typedef ComposerGuardBuilder = Widget Function(
  BuildContext context,
  VoidCallback requestClose,
);

class ComposerGuard extends StatefulWidget {
  const ComposerGuard({
    super.key,
    required this.isDirty,
    required this.onDiscard,
    required this.builder,
    this.popResult,
    this.locked = false,
    this.onClose,
  });

  final ValueGetter<bool> isDirty;
  final Future<void> Function() onDiscard;
  final ComposerGuardBuilder builder;
  final Object? popResult;
  final bool locked;
  final ValueChanged<Object?>? onClose;

  @override
  State<ComposerGuard> createState() => _ComposerGuardState();
}

class _ComposerGuardState extends State<ComposerGuard> {
  bool _confirming = false;

  Future<void> _requestClose() async {
    if (widget.locked || _confirming) {
      return;
    }
    if (!widget.isDirty()) {
      await _discardAndPop();
      return;
    }
    _confirming = true;
    final bool? discard = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => const _DiscardConfirmDialog(),
    );
    _confirming = false;
    if (discard != true || !mounted) {
      return;
    }
    await _discardAndPop();
  }

  Future<void> _discardAndPop() async {
    final Future<void> discarding = widget.onDiscard();
    final ValueChanged<Object?>? onClose = widget.onClose;
    if (onClose == null) {
      Navigator.of(context).pop(widget.popResult);
    } else {
      onClose(widget.popResult);
    }
    await discarding;
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    _requestClose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: widget.builder(context, _requestClose),
    );
  }
}

class _DiscardConfirmDialog extends StatelessWidget {
  const _DiscardConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _confirmMaxWidth),
          child: StickerCard(
            surface: Palette.cardBright,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  composerDiscardTitle,
                  style: TypographyTokens.titleSerif,
                ),
                const SizedBox(height: _confirmTitleGap),
                Text(
                  composerDiscardMessage,
                  style: TypographyTokens.bodySans,
                ),
                const SizedBox(height: _confirmActionsGap),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: _confirmActionSpacing,
                  runSpacing: _confirmActionSpacing,
                  children: <Widget>[
                    StickerButton(
                      key: composerKeepEditingKey,
                      label: composerKeepEditingLabel,
                      variant: StickerButtonVariant.secondary,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      key: composerDiscardKey,
                      label: composerDiscardLabel,
                      variant: StickerButtonVariant.danger,
                      labelStyle: TypographyTokens.captureLabelSans,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(true),
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
