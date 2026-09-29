import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/flowers/garden_plant_painter.dart';
import 'package:field_notes/design/format/plural.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import '../model/garden_data.dart';

class MoodTallyChips extends StatelessWidget {
  const MoodTallyChips({
    super.key,
    required this.entries,
    this.sproutCount = 0,
  });

  final List<MoodTallyEntry> entries;
  final int sproutCount;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && sproutCount <= 0) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final MoodTallyEntry entry in entries)
          _TallyChip(
            icon: FlowerBloom.forMood(entry.mood, size: 24),
            count: entry.count,
            label: entry.mood.label,
          ),
        if (sproutCount > 0)
          _TallyChip(
            icon: const _SproutIcon(size: 24),
            count: sproutCount,
            label: 'Sprouts',
            mergedText: pluralize(sproutCount, 'Sprout'),
          ),
      ],
    );
  }
}

class _TallyChip extends StatelessWidget {
  const _TallyChip({
    required this.icon,
    required this.count,
    required this.label,
    this.mergedText,
  });

  final Widget icon;
  final int count;
  final String label;
  final String? mergedText;

  @override
  Widget build(BuildContext context) {
    final String? merged = mergedText;
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Semantics(
      container: true,
      label: merged ?? '$count $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBright,
          borderRadius: Shapes.buttonBorderRadius,
          border: Border.fromBorderSide(
            BorderSide(color: colors.line, width: Shapes.outlineWidth),
          ),
          boxShadow: context.shadows.button,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                icon,
                const SizedBox(width: 6),
                if (merged != null)
                  Text(merged, style: textStyles.labelSans)
                else ...<Widget>[
                  Text('$count', style: textStyles.labelSans),
                  const SizedBox(width: 4),
                  Text(label, style: textStyles.captionSans),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SproutIcon extends StatelessWidget {
  const _SproutIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _SproutIconPainter(),
    );
  }
}

class _SproutIconPainter extends CustomPainter {
  const _SproutIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.height / sproutRatio;
    canvas.save();
    canvas.translate((size.width - width) / 2, 0);
    const GardenSproutPainter().paint(canvas, Size(width, size.height));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SproutIconPainter oldDelegate) => false;
}
