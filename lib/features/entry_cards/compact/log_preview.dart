import 'package:flutter/foundation.dart';

import '../../../domain/models/models.dart';
import '../../../domain/notes/notes.dart';
import '../util/duration_format.dart';

const int _maxEpochMs = 8640000000000000;
const int _leadLimit = 72;
const int _snippetLimit = 150;
const int _minWordsForReadTime = 60;
const int _wordsPerMinute = 200;

final RegExp _whitespaceRun = RegExp(r'\s+');
final RegExp _whitespaceChar = RegExp(r'\s');

String partOfDayFor(int hour) {
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

String logStampFor(int createdAtMs) {
  if (createdAtMs < 0 || createdAtMs > _maxEpochMs) {
    return '';
  }
  final DateTime at = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final String hour = at.hour.toString().padLeft(2, '0');
  final String minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute · ${partOfDayFor(at.hour)}';
}

String logTypeLabelFor(EntryType type) {
  switch (type) {
    case EntryType.text:
      return 'note';
    case EntryType.voice:
      return 'voice';
    case EntryType.video:
      return 'video';
  }
}

@immutable
final class LogPreview {
  const LogPreview({
    required this.isLong,
    required this.lead,
    required this.snippet,
    required this.photoCount,
    required this.firstPhotoReference,
    required this.meta,
    required this.openLabel,
    required this.heading,
  });

  final bool isLong;
  final String lead;
  final String snippet;
  final int photoCount;
  final String? firstPhotoReference;
  final String meta;
  final String openLabel;
  final String heading;
}

LogPreview logPreviewOf(Entry entry) {
  final String heading = _headingFor(entry);
  switch (entry.type) {
    case EntryType.text:
      return _textPreview(entry, heading);
    case EntryType.voice:
      return LogPreview(
        isLong: false,
        lead: '',
        snippet: '',
        photoCount: 0,
        firstPhotoReference: null,
        meta: '',
        openLabel: '',
        heading: heading,
      );
    case EntryType.video:
      return LogPreview(
        isLong: false,
        lead: '',
        snippet: '',
        photoCount: 0,
        firstPhotoReference: null,
        meta: entry.durationMs != null
            ? formatMediaDuration(entry.durationMs)
            : '',
        openLabel: 'Watch',
        heading: heading,
      );
  }
}

String _headingFor(Entry entry) {
  final DateTime at = DateTime.fromMillisecondsSinceEpoch(entry.createdAt);
  final String part = partOfDayFor(at.hour);
  final String capitalisedPart = part[0].toUpperCase() + part.substring(1);
  final String kind = switch (entry.type) {
    EntryType.text => 'note',
    EntryType.voice => 'voice log',
    EntryType.video => 'video',
  };
  return '$capitalisedPart $kind';
}

LogPreview _textPreview(Entry entry, String heading) {
  final List<NoteBlock> blocks = parseNote(entry.textContent ?? '');
  int photoCount = 0;
  PhotoBlock? firstPhoto;
  for (final NoteBlock block in blocks) {
    if (block is PhotoBlock) {
      photoCount++;
      firstPhoto ??= block;
    }
  }
  final List<NoteBlock> significant = _significantBlocks(blocks);
  final String fullText = _collapseWhitespace(_joinPlainText(significant));
  String lead;
  String snippet;
  if (significant.isNotEmpty && significant.first is HeadingBlock) {
    final HeadingBlock headingBlock = significant.first as HeadingBlock;
    lead = _collapseWhitespace(headingBlock.plainText);
    snippet =
        _collapseWhitespace(_joinPlainText(significant.skip(1).toList()));
  } else {
    final int? sentenceEnd = _firstSentenceEnd(fullText);
    if (sentenceEnd == null) {
      lead = fullText;
      snippet = '';
    } else {
      lead = fullText.substring(0, sentenceEnd);
      snippet = fullText.substring(sentenceEnd).trim();
    }
  }
  if (lead.isEmpty && firstPhoto != null) {
    lead = firstPhoto.alt;
  }
  final bool isLong = fullText.length > 220 || photoCount > 0;
  final List<String> words =
      fullText.isEmpty ? const <String>[] : fullText.split(' ');
  final List<String> metaParts = <String>[];
  if (words.length > _minWordsForReadTime) {
    final int minutes = (words.length / _wordsPerMinute).round();
    metaParts.add('${minutes < 1 ? 1 : minutes} min read');
  }
  if (photoCount > 0) {
    metaParts.add(photoCount == 1 ? '1 photo' : '$photoCount photos');
  }
  return LogPreview(
    isLong: isLong,
    lead: _cutTo(lead, _leadLimit),
    snippet: _cutTo(snippet, _snippetLimit),
    photoCount: photoCount,
    firstPhotoReference: firstPhoto?.reference,
    meta: metaParts.join(' · '),
    openLabel: 'Read',
    heading: heading,
  );
}

List<NoteBlock> _significantBlocks(List<NoteBlock> blocks) {
  final List<NoteBlock> result = <NoteBlock>[];
  for (final NoteBlock block in blocks) {
    if (block is PhotoBlock || block.plainText.isEmpty) {
      continue;
    }
    result.add(block);
  }
  return result;
}

String _joinPlainText(List<NoteBlock> blocks) {
  final StringBuffer buffer = StringBuffer();
  NoteBlock? previous;
  for (final NoteBlock block in blocks) {
    if (previous != null) {
      buffer.write(plainBreakBetween(previous, block));
    }
    buffer.write(block.plainText);
    previous = block;
  }
  return buffer.toString();
}

String _collapseWhitespace(String text) =>
    text.replaceAll(_whitespaceRun, ' ').trim();

int? _firstSentenceEnd(String text) {
  for (int i = 0; i < text.length; i++) {
    final String char = text[i];
    if (char == '.' || char == '!' || char == '?') {
      final bool endsHere =
          i + 1 >= text.length || _whitespaceChar.hasMatch(text[i + 1]);
      if (endsHere) {
        return i + 1;
      }
    }
  }
  return null;
}

String _cutTo(String text, int limit) {
  if (text.length <= limit) {
    return text;
  }
  final String head = text.substring(0, limit);
  final int lastWhitespace = head.lastIndexOf(_whitespaceChar);
  final String withoutPartialWord =
      lastWhitespace == -1 ? head : head.substring(0, lastWhitespace);
  return '${withoutPartialWord.trim()}…';
}
