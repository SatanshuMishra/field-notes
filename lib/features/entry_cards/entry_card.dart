import 'package:flutter/widgets.dart';

import '../../design/tokens/tokens.dart';
import '../../design/widgets/icon_sticker_button.dart';
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

const String entryEditLabel = 'Edit';
const String entryDeleteLabel = 'Delete';

const double _headerGap = 4;
const double _actionGap = 8;
const int _maxEpochMs = 8640000000000000;

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
          const SizedBox(height: _headerGap),
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
    final VoidCallback? edit = onEdit;
    final VoidCallback? delete = onDelete;
    return Row(
      children: <Widget>[
        Text(_stamp(entry.createdAt), style: TypographyTokens.stampAccent),
        const Spacer(),
        if (edit != null) ...<Widget>[
          IconStickerButton(
            glyph: IconStickerGlyph.edit,
            glyphColor: Palette.ink,
            background: Palette.cardLight,
            semanticLabel: entryEditLabel,
            onPressed: edit,
          ),
          const SizedBox(width: _actionGap),
        ],
        if (delete != null) ...<Widget>[
          IconStickerButton(
            glyph: IconStickerGlyph.trash,
            glyphColor: Palette.danger,
            background: Palette.cardLight,
            semanticLabel: entryDeleteLabel,
            onPressed: delete,
          ),
          const SizedBox(width: _actionGap),
        ],
        _typeChip(entry.type),
      ],
    );
  }

  Widget _typeChip(EntryType type) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.coral12,
        borderRadius: BorderRadius.all(
          Radius.circular(Shapes.radiusIconButton),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
        child: Text(
          _typeLabel(type).toUpperCase(),
          style: TypographyTokens.chipMicroSans,
        ),
      ),
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

  String _typeLabel(EntryType type) {
    switch (type) {
      case EntryType.text:
        return 'note';
      case EntryType.voice:
        return 'voice';
      case EntryType.video:
        return 'video';
    }
  }

  String _stamp(int createdAt) {
    if (createdAt < 0 || createdAt > _maxEpochMs) {
      return '';
    }
    final DateTime at = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final String hour = at.hour.toString().padLeft(2, '0');
    final String minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute · ${_partOfDay(at.hour)}';
  }

  String _partOfDay(int hour) {
    if (hour < 12) {
      return 'morning';
    }
    if (hour < 17) {
      return 'afternoon';
    }
    if (hour < 21) {
      return 'evening';
    }
    return 'night';
  }
}
