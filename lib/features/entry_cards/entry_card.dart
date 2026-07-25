import 'package:flutter/widgets.dart';

import '../../design/tokens/tokens.dart';
import '../../design/widgets/widgets.dart';
import '../../domain/models/models.dart';
import 'cards/note_body.dart';
import 'cards/photo_strip.dart';
import 'cards/video_body.dart';
import 'cards/voice_body.dart';
import 'media/media_placeholders.dart';
import 'media/media_resolver.dart';
import 'playback/audio_playback.dart';
import 'playback/video_playback.dart';
import 'playback/video_slots.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.resolver,
    required this.videoSlots,
    this.photos = const <EntryPhoto>[],
    this.audioPlayerFactory,
    this.videoPlayerFactory,
    this.onEdit,
    this.onDelete,
    this.surface = Palette.cardWarm,
  });

  final Entry entry;
  final MediaResolver resolver;
  final List<EntryPhoto> photos;
  final EntryAudioPlayerFactory? audioPlayerFactory;
  final EntryVideoPlayerFactory? videoPlayerFactory;
  final VideoSlots videoSlots;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      surface: surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _header(),
          const SizedBox(height: 8),
          _body(),
          if (photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            InlinePhotoStrip(photos: photos, resolver: resolver),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: <Widget>[
        Text(_eyebrow(entry.type), style: TypographyTokens.eyebrowAccent),
        const Spacer(),
        if (onEdit != null)
          StickerButton(
            label: 'Edit',
            variant: StickerButtonVariant.secondary,
            onPressed: onEdit,
          ),
        if (onEdit != null && onDelete != null) const SizedBox(width: 8),
        if (onDelete != null)
          StickerButton(
            label: 'Delete',
            variant: StickerButtonVariant.danger,
            onPressed: onDelete,
          ),
      ],
    );
  }

  Widget _body() {
    switch (entry.type) {
      case EntryType.text:
        return NoteBody(text: entry.textContent ?? '');
      case EntryType.voice:
        final EntryAudioPlayerFactory? factory = audioPlayerFactory;
        if (factory == null) {
          return const CorruptMediaPlaceholder(
            label: 'Playback unavailable',
            height: 64,
          );
        }
        return VoiceBody(
          entry: entry,
          resolver: resolver,
          playerFactory: factory,
        );
      case EntryType.video:
        final EntryVideoPlayerFactory? factory = videoPlayerFactory;
        if (factory == null) {
          return const CorruptMediaPlaceholder(
            label: 'Playback unavailable',
            height: 200,
          );
        }
        return VideoBody(
          entry: entry,
          resolver: resolver,
          playerFactory: factory,
          slots: videoSlots,
        );
    }
  }

  String _eyebrow(EntryType type) {
    switch (type) {
      case EntryType.text:
        return 'Note';
      case EntryType.voice:
        return 'Voice note';
      case EntryType.video:
        return 'Video';
    }
  }
}
