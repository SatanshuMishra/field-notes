import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, TimeOfDay;

import '../../../design/format/clock_format.dart';
import '../../../domain/models/models.dart';
import '../../../domain/notes/markdown/markdown.dart';
import '../../../domain/notes/note_photos.dart';
import '../../../domain/notes/note_plain_text.dart';
import '../../note_engine/capabilities.dart';
import '../util/duration_format.dart';

const int _maxEpochMs = 8640000000000000;
const int _titleLimit = 72;
const int _snippetLimit = 150;
const int _untitledSnippetLimit = 222;
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

String logStampFor(BuildContext context, int createdAtMs) {
  if (createdAtMs < 0 || createdAtMs > _maxEpochMs) {
    return '';
  }
  final DateTime at = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final String clock = formatClock(context, TimeOfDay.fromDateTime(at));
  return '$clock · ${partOfDayFor(at.hour)}';
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

String? logOwnTitle(Entry entry) {
  final String title = entry.title?.trim() ?? '';
  return title.isEmpty ? null : title;
}

@immutable
final class LogPreview {
  const LogPreview({
    required this.isLong,
    required this.title,
    required this.snippet,
    required this.photoCount,
    required this.firstPhotoReference,
    required this.meta,
    required this.openLabel,
    required this.heading,
  });

  final bool isLong;
  final String title;
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
        title: logOwnTitle(entry) ?? '',
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
        title: logOwnTitle(entry) ?? '',
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
  final String source = entry.textContent ?? '';
  final MdTree tree = parseNoteTree(source, tables: tablesEnabled);
  final List<NotePhoto> photos = notePhotosOf(tree);
  final int photoCount = photos.length;
  final NotePhoto? firstPhoto = photos.isEmpty ? null : photos.first;
  final List<NotePlainSegment> significant = <NotePlainSegment>[
    for (final NotePlainSegment segment in notePlainSegments(tree, source))
      if (segment.kind != NotePlainKind.photo && segment.text.isNotEmpty)
        segment,
  ];
  final String fullText = _collapseWhitespace(
    joinNotePlainSegments(significant),
  );
  final String? ownTitle = logOwnTitle(entry);
  final bool opensWithHeading =
      significant.isNotEmpty && significant.first.kind == NotePlainKind.heading;
  final bool headingIsTitle = ownTitle == null && opensWithHeading;
  final String title =
      ownTitle ??
      (headingIsTitle ? _collapseWhitespace(significant.first.text) : '');
  final String body = headingIsTitle
      ? _collapseWhitespace(joinNotePlainSegments(significant.skip(1)))
      : fullText;
  final String snippet = body.isEmpty && firstPhoto != null
      ? firstPhoto.caption
      : body;
  final bool isLong = fullText.length > 220 || photoCount > 0;
  final List<String> words = fullText.isEmpty
      ? const <String>[]
      : fullText.split(' ');
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
    title: _cutTo(title, _titleLimit),
    snippet: _cutTo(
      snippet,
      title.isEmpty ? _untitledSnippetLimit : _snippetLimit,
    ),
    photoCount: photoCount,
    firstPhotoReference: firstPhoto?.reference,
    meta: metaParts.join(' · '),
    openLabel: 'Read',
    heading: heading,
  );
}

String _collapseWhitespace(String text) =>
    text.replaceAll(_whitespaceRun, ' ').trim();

String _cutTo(String text, int limit) {
  if (text.length <= limit) {
    return text;
  }
  final String head = text.substring(0, limit);
  final int lastWhitespace = head.lastIndexOf(_whitespaceChar);
  final String withoutPartialWord = lastWhitespace == -1
      ? head
      : head.substring(0, lastWhitespace);
  return '${withoutPartialWord.trim()}…';
}
