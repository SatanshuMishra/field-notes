import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';

const String draftRestoredLabel = 'Draft restored';
const String draftRestoredDiscardLabel = 'Discard';
const Key draftRestoredDiscardKey = ValueKey<String>('draft-restored-discard');

const double _chipHorizontalPadding = 12;
const double _chipVerticalPadding = 5;
const double _chipGap = 8;
const double _discardTarget = 48;
const BorderRadius _discardFocusRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusPill),
);

class DraftRestoredChip extends StatelessWidget {
  const DraftRestoredChip({
    super.key,
    required this.onDiscard,
    this.verticalMargin = 0,
  });

  final VoidCallback? onDiscard;
  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    final TextStyle discardStyle = context.textStyles.captureLabelSans.copyWith(
      color: context.colors.coralLink,
      decoration: TextDecoration.underline,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _discardTarget),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: verticalMargin),
              child: _chip(context, discardStyle),
            ),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              child: _discardButton(discardStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, TextStyle discardStyle) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBright,
        border: context.shadows.outline,
        borderRadius: BorderRadius.circular(Shapes.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _chipHorizontalPadding,
          vertical: _chipVerticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              draftRestoredLabel,
              style: textStyles.captionSans.copyWith(color: colors.ink),
            ),
            const SizedBox(width: _chipGap),
            Text('·', style: textStyles.captionSans),
            const SizedBox(width: _chipGap),
            ExcludeSemantics(
              child: Text(draftRestoredDiscardLabel, style: discardStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discardButton(TextStyle discardStyle) {
    return TextFieldTapRegion(
      child: Semantics(
        container: true,
        button: true,
        enabled: onDiscard != null,
        label: draftRestoredDiscardLabel,
        child: GestureDetector(
          key: draftRestoredDiscardKey,
          behavior: HitTestBehavior.opaque,
          onTap: onDiscard,
          child: FocusRing(
            enabled: onDiscard != null,
            onPressed: onDiscard,
            borderRadius: _discardFocusRadius,
            placement: FocusRingPlacement.edge,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _discardTarget),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: _chipGap,
                  end: _chipHorizontalPadding,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Opacity(
                    opacity: 0,
                    child: Text(draftRestoredDiscardLabel, style: discardStyle),
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
