import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const String draftRestoredLabel = 'Draft restored';
const String draftRestoredDiscardLabel = 'Discard';
const Key draftRestoredDiscardKey = ValueKey<String>('draft-restored-discard');

const double _chipHorizontalPadding = 12;
const double _chipVerticalPadding = 5;
const double _chipGap = 8;

class DraftRestoredChip extends StatelessWidget {
  const DraftRestoredChip({super.key, required this.onDiscard});

  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
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
              Semantics(
                button: true,
                label: draftRestoredDiscardLabel,
                child: GestureDetector(
                  key: draftRestoredDiscardKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onDiscard,
                  child: Text(
                    draftRestoredDiscardLabel,
                    style: TypographyTokens.captureLabelSans.copyWith(
                      color: Palette.coralLink,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
