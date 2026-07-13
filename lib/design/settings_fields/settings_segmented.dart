import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class SettingsSegment<T> {
  const SettingsSegment({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<SettingsSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.panelTop,
          border: Shapes.outline,
          borderRadius: Shapes.buttonBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final SettingsSegment<T> segment in segments)
                _segmentTile(segment),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmentTile(SettingsSegment<T> segment) {
    final bool selected = segment.value == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled && !selected ? () => onChanged?.call(segment.value) : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? Palette.cardBright : const Color(0x00000000),
          border: selected ? Shapes.outline : null,
          borderRadius: Shapes.buttonBorderRadius,
          boxShadow: selected ? Shadows.button : const <BoxShadow>[],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(segment.label, style: TypographyTokens.labelSans),
        ),
      ),
    );
  }
}
