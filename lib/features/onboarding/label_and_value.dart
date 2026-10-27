import 'package:flutter/widgets.dart';

class LabelAndValue extends StatelessWidget {
  const LabelAndValue({
    super.key,
    required this.label,
    required this.labelStyle,
    required this.value,
    required this.valueStyle,
    this.gap = 0,
  });

  final String label;
  final TextStyle labelStyle;
  final String value;
  final TextStyle valueStyle;
  final double gap;

  double _widthOf(BuildContext context, String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints area) {
        final double room =
            area.maxWidth - gap - _widthOf(context, value, valueStyle);
        if (_widthOf(context, label, labelStyle) <= room) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(child: Text(label, style: labelStyle)),
              SizedBox(width: gap),
              Text(value, style: valueStyle),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(label, style: labelStyle),
            Text(value, textAlign: TextAlign.end, style: valueStyle),
          ],
        );
      },
    );
  }
}
