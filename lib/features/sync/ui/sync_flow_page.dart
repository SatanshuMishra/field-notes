import 'dart:math' as math;

import 'package:field_notes/app/shell/system_bars.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'start_sync_flow.dart';

const String syncFlowCloseLabel = 'Close';

const Key syncFlowPageCloseKey = ValueKey<String>('sync-flow-page-close');
const Key syncFlowPageFooterKey = ValueKey<String>('sync-flow-page-footer');

const double _closeExtent = 48;
const double _closeGlyph = 16;
const double _closeBorderWidth = 1.5;
const double _titleSize = 26;
const double _kickerGap = 2;
const double _messageGap = 8;
const double _contentGap = 16;
const double _actionGap = 8;
const double _footerSide = 12;
const double _footerTop = 10;
const double _footerBottom = 12;
const EdgeInsets _closePadding = EdgeInsets.fromLTRB(8, 6, 8, 0);
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(20, 8, 20, 20);
const BorderRadius _closeRadius = BorderRadius.all(
  Radius.circular(_closeExtent / 2),
);

class SyncFlowPage extends StatelessWidget {
  const SyncFlowPage({
    super.key,
    required this.title,
    this.kicker,
    this.message,
    this.content = const <Widget>[],
    required this.actions,
    this.onClose,
    this.closable = true,
  });

  final String title;
  final String? kicker;
  final String? message;
  final List<Widget> content;
  final List<SyncFlowAction> actions;
  final VoidCallback? onClose;
  final bool closable;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final String? kicker = this.kicker;
    final String? message = this.message;
    final List<SyncFlowAction> ordered = <SyncFlowAction>[
      for (final SyncFlowAction action in actions)
        if (!action.primary && !action.danger) action,
      for (final SyncFlowAction action in actions)
        if (action.primary || action.danger) action,
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsOver(Theme.of(context).brightness),
      child: ColoredBox(
        color: context.colors.page,
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: _closePadding.copyWith(
                  top: padding.top + _closePadding.top,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: closable
                      ? _SyncFlowPageClose(
                          onPressed:
                              onClose ?? () => Navigator.maybePop(context),
                        )
                      : const SizedBox.square(dimension: _closeExtent),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: _bodyPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (kicker != null) ...<Widget>[
                        Text(kicker, style: textStyles.pageEyebrowAccent),
                        const SizedBox(height: _kickerGap),
                      ],
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: textStyles.headlineSerif.copyWith(
                            fontSize: _titleSize,
                          ),
                        ),
                      ),
                      if (message != null) ...<Widget>[
                        const SizedBox(height: _messageGap),
                        Text(
                          message,
                          style: textStyles.bodySans.copyWith(
                            color: context.colors.mutedDeep,
                          ),
                        ),
                      ],
                      for (final Widget child in content) ...<Widget>[
                        const SizedBox(height: _contentGap),
                        child,
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _footerSide,
                  ordered.isEmpty ? 0 : _footerTop,
                  _footerSide,
                  (ordered.isEmpty ? 0 : _footerBottom) +
                      math.max(keyboard, padding.bottom),
                ),
                child: Row(
                  key: syncFlowPageFooterKey,
                  children: <Widget>[
                    for (
                      int index = 0;
                      index < ordered.length;
                      index++
                    ) ...<Widget>[
                      if (index > 0) const SizedBox(width: _actionGap),
                      Expanded(child: SyncFlowButton(action: ordered[index])),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SyncTaskFrame extends StatelessWidget {
  const SyncTaskFrame({
    super.key,
    required this.title,
    this.kicker,
    this.message,
    this.content = const <Widget>[],
    required this.actions,
    this.closable = true,
  });

  final String title;
  final String? kicker;
  final String? message;
  final List<Widget> content;
  final List<SyncFlowAction> actions;
  final bool closable;

  @override
  Widget build(BuildContext context) {
    if (syncFlowUsesSheet(context)) {
      return SyncFlowPage(
        title: title,
        kicker: kicker,
        message: message,
        content: content,
        actions: actions,
        closable: closable,
      );
    }
    return SyncFlowFrame(
      title: title,
      message: message,
      content: content,
      actions: actions,
    );
  }
}

class _SyncFlowPageClose extends StatelessWidget {
  const _SyncFlowPageClose({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      key: syncFlowPageCloseKey,
      button: true,
      label: syncFlowCloseLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _closeRadius,
          child: SizedBox.square(
            dimension: _closeExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cardLight,
                border: Border.all(
                  color: colors.line,
                  width: _closeBorderWidth,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: IconStickerGlyphIcon(
                  glyph: IconStickerGlyph.close,
                  color: colors.ink,
                  size: _closeGlyph,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
