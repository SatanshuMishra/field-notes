import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const String draftRestoredLabel = 'Draft restored';
const String draftRestoredDiscardLabel = 'Discard';
const Key draftRestoredDiscardKey = ValueKey<String>('draft-restored-discard');

const double _chipHorizontalPadding = 12;
const double _chipVerticalPadding = 5;
const double _chipGap = 8;
const double _discardTarget = 48;

final TextStyle _discardStyle = TypographyTokens.captureLabelSans.copyWith(
  color: Palette.coralLink,
  decoration: TextDecoration.underline,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _discardTarget),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: verticalMargin),
              child: _chip(),
            ),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              child: _discardButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.cardBright,
        border: Shapes.outline,
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
              style: TypographyTokens.captionSans.copyWith(color: Palette.ink),
            ),
            const SizedBox(width: _chipGap),
            Text('·', style: TypographyTokens.captionSans),
            const SizedBox(width: _chipGap),
            ExcludeSemantics(
              child: Text(draftRestoredDiscardLabel, style: _discardStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discardButton() {
    return Semantics(
      container: true,
      button: true,
      enabled: onDiscard != null,
      label: draftRestoredDiscardLabel,
      child: GestureDetector(
        key: draftRestoredDiscardKey,
        behavior: HitTestBehavior.opaque,
        onTap: onDiscard,
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
                child: Text(draftRestoredDiscardLabel, style: _discardStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
