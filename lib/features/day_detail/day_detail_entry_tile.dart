import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/state/state.dart';

bool isEditableEntry(Entry entry) => entry.type == EntryType.text;

class DayDetailEntryTile extends ConsumerWidget {
  const DayDetailEntryTile({
    super.key,
    required this.entry,
    required this.resolver,
    this.onEdit,
    this.onDelete,
  });

  final Entry entry;
  final MediaResolver resolver;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<EntryPhoto> photos =
        ref.watch(photosForEntryProvider(entry.id)).value ??
            const <EntryPhoto>[];
    return EntryCard(
      entry: entry,
      resolver: resolver,
      photos: photos,
      audioPlayerFactory: createJustAudioPlayer,
      videoPlayerFactory: createVideoPlayerEntryPlayer,
      onEdit: isEditableEntry(entry) ? onEdit : null,
      onDelete: onDelete,
    );
  }
}
