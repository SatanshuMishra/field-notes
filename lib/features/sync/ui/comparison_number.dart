import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';

String comparisonNumberSemantics(String number) => 'Number $number';

class ComparisonNumber extends StatelessWidget {
  const ComparisonNumber(this.number, {super.key});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: comparisonNumberSemantics(number),
      excludeSemantics: true,
      child: Text(
        number,
        textAlign: TextAlign.center,
        style: context.textStyles.timerSerif.copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
