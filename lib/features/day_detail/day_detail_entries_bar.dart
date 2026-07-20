import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

String dayDetailEntryCountLabel(int count) {
  if (count <= 0) {
    return 'No entries yet';
  }
  if (count == 1) {
    return '1 entry';
  }
  return '$count entries';
}

class DayDetailEntriesBar extends StatelessWidget {
  const DayDetailEntriesBar({
    super.key,
    required this.entryCount,
    required this.onAddNote,
    this.addNoteLabel = 'Add a note',
  });

  final int? entryCount;
  final VoidCallback? onAddNote;
  final String addNoteLabel;

  @override
  Widget build(BuildContext context) {
    final int? count = entryCount;
    return Row(
      children: <Widget>[
        if (count != null)
          Text(
            dayDetailEntryCountLabel(count),
            style:
                TypographyTokens.labelSans.copyWith(color: Palette.mutedDeep),
          ),
        const Spacer(),
        StickerButton(label: addNoteLabel, onPressed: onAddNote),
      ],
    );
  }
}
