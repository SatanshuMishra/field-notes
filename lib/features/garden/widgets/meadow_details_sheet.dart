import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';

const Duration meadowDetailsSheetSlide = Duration(milliseconds: 240);
const double meadowDetailsSheetShare = 0.58;
const ValueKey<String> meadowDetailsSheetKey = ValueKey<String>(
  'meadow-details-sheet',
);

const BorderRadius _sheetRadius = BorderRadius.vertical(
  top: Radius.circular(22),
);
const double _sheetEdge = 2;
const List<BoxShadow> _sheetShadows = <BoxShadow>[
  BoxShadow(
    color: Color.fromRGBO(50, 35, 20, 0.55),
    offset: Offset(0, -14),
    blurRadius: 34,
    spreadRadius: -14,
  ),
];

class MeadowDetailsSheet extends StatelessWidget {
  const MeadowDetailsSheet({
    super.key,
    required this.maxHeight,
    required this.bottomPadding,
    required this.child,
  });

  final double maxHeight;
  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Widget sheet = MeadowChromeBlock(
      child: ConstrainedBox(
        key: meadowDetailsSheetKey,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardWarm,
            border: Border(
              top: BorderSide(color: colors.line, width: _sheetEdge),
            ),
            borderRadius: _sheetRadius,
            boxShadow: _sheetShadows,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: _sheetEdge, bottom: bottomPadding),
            child: child,
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return sheet;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: meadowDetailsSheetSlide,
      curve: meadowEase,
      builder: (BuildContext context, double progress, Widget? child) =>
          FractionalTranslation(
            translation: Offset(0, 1 - progress),
            child: child,
          ),
      child: sheet,
    );
  }
}
