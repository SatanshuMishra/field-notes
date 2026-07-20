import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'day_detail_heading.dart';

class DayDetailHeader extends StatelessWidget {
  const DayDetailHeader({
    super.key,
    required this.date,
    required this.onClose,
    this.closeLabel = 'Close',
  });

  final String date;
  final VoidCallback onClose;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final DayDetailHeading heading = dayDetailHeadingFor(date);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(heading.title, style: TypographyTokens.titleSerif),
              if (heading.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  heading.subtitle,
                  style: TypographyTokens.captionSans
                      .copyWith(color: Palette.mutedDeep),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        StickerButton(
          label: closeLabel,
          variant: StickerButtonVariant.secondary,
          onPressed: onClose,
        ),
      ],
    );
  }
}
