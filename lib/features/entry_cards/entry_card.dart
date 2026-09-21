import 'package:flutter/widgets.dart';

import '../../design/tokens/tokens.dart';
import '../../design/widgets/icon_sticker_button.dart';
import '../../design/widgets/widgets.dart';
import '../../domain/models/models.dart';
import '../notes/render/note_photo_block.dart';
import 'cards/note_body.dart';
import 'cards/note_preview.dart';
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

const double _tiltOddDegrees = -0.5;
const double _tiltEvenDegrees = 0.4;
const EdgeInsets _cardPadding =
    EdgeInsets.symmetric(vertical: 13, horizontal: 15);
const BorderRadius _cardBorderRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusMd));

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.entry,
    required this.resolver,
    required this.videoSlots,
    this.audioPlayerFactory,
    this.videoPlayerFactory,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.preview = false,
    this.surface = Palette.cardWarm,
  });

  final Entry entry;
  final MediaResolver resolver;
  final EntryAudioPlayerFactory? audioPlayerFactory;
  final EntryVideoPlayerFactory? videoPlayerFactory;
  final VideoSlots videoSlots;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool preview;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final Widget card = StickerCard(
      surface: surface,
      borderRadius: _cardBorderRadius,
      shadow: Shadows.cardDefault,
      padding: _cardPadding,
      rotationDegrees: _tiltDegrees(entry.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _header(),
          const SizedBox(height: _headerGap),
          _body(),
        ],
      ),
    );
    final VoidCallback? tap = onTap;
    if (tap == null) {
      return card;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: card,
    );
  }

  double _tiltDegrees(String id) {
    final int codeUnitSum =
        id.codeUnits.fold<int>(0, (int total, int unit) => total + unit);
    return codeUnitSum.isOdd ? _tiltOddDegrees : _tiltEvenDegrees;
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
        final String text = entry.textContent ?? '';
        return NoteMediaScope(
          resolver: resolver,
          child: preview
              ? NotePreview(text: text, onReadMore: onTap)
              : NoteBody(text: text),
        );
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
