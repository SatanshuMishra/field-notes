import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/mood/mood.dart';

import 'flower_painter.dart';
import 'flower_spec.dart';

class FlowerBloom extends StatelessWidget {
  const FlowerBloom({
    super.key,
    required this.kind,
    this.size = 48,
    this.semanticLabel,
  });

  factory FlowerBloom.forMood(
    Mood mood, {
    Key? key,
    double size = 48,
    String? semanticLabel,
  }) =>
      FlowerBloom(
        key: key,
        kind: mood.flower,
        size: size,
        semanticLabel: semanticLabel ?? mood.label,
      );

  final FlowerKind kind;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? kind.label,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: FlowerPainter(flowerSpecFor(kind), headless: true),
          size: Size.square(size),
        ),
      ),
    );
  }
}
