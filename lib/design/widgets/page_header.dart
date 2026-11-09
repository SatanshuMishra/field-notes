import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

const double _eyebrowGap = 1;
const double _actionsLeadingGap = Spacing.space16;
const double _actionGap = Spacing.space8;

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    final String? eyebrow = this.eyebrow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (eyebrow != null) ...<Widget>[
                Text(eyebrow, style: textStyles.pageEyebrowAccent),
                const SizedBox(height: _eyebrowGap),
              ],
              Semantics(
                header: true,
                child: Text(title, style: textStyles.displaySerifToday),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...<Widget>[
          const SizedBox(width: _actionsLeadingGap),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: _actionGap,
            children: actions,
          ),
        ],
      ],
    );
  }
}
