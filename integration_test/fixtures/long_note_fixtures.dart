import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:flutter/material.dart';

const int benchPhotoWidth = 2048;
const int benchPhotoHeight = 1536;
const int benchPhotoCount = 8;
const int benchFeedEntryCount = 40;
const int benchPhotoReferenceLength = 12;

const int _noteSeed = 20260920;
const int _photoSeed = 5150;
const int _feedSeed = 77001;
const int _tailBudget = 700;
const int _photoEveryBlocks = 6;

const List<String> _words = <String>[
  'morning', 'harbour', 'lantern', 'gravel', 'thistle', 'rain', 'slate',
  'kettle', 'orchard', 'ferry', 'chalk', 'meadow', 'window', 'crossing',
  'signal', 'linen', 'harvest', 'cedar', 'quarry', 'shutter', 'compass',
  'marsh', 'pebble', 'drift', 'ember', 'hedge', 'lichen', 'tideline',
  'paddock', 'copper', 'wicker', 'bramble', 'heron', 'sawdust', 'yarrow',
  'furrow', 'brook', 'aspen', 'stipple', 'rowan', 'clover', 'gorse',
  'plover', 'sedge', 'basalt', 'cairn', 'trellis', 'kelp', 'wren',
  'foxglove', 'sandbar', 'juniper', 'bellows', 'thatch', 'pollen', 'muslin',
];

const List<String> _photoAttributes = <String>[
  'right medium',
  'left small',
  'center large',
  'full',
];

class _Stream {
  _Stream(this._seed);

  int _seed;

  int next(int bound) {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed % bound;
  }

  int between(int low, int high) => low + next(high - low + 1);
}

String _word(_Stream rng) => _words[rng.next(_words.length)];

String _plainWords(_Stream rng, int count) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i++) {
    if (i > 0) {
      buffer.write(' ');
    }
    buffer.write(_word(rng));
  }
  return buffer.toString();
}

String _capitalise(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

String _sentence(_Stream rng, int wordCount) =>
    '${_capitalise(_plainWords(rng, wordCount))}.';

String _paragraph(_Stream rng) {
  final int sentences = rng.between(2, 3);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < sentences; i++) {
    if (i > 0) {
      buffer.write(' ');
    }
    buffer.write(_sentence(rng, rng.between(9, 16)));
  }
  return buffer.toString();
}

String _richParagraph(_Stream rng) {
  return '${_capitalise(_plainWords(rng, rng.between(5, 8)))} '
      '**${_plainWords(rng, 2)}** '
      '${_plainWords(rng, rng.between(4, 7))} '
      '_${_plainWords(rng, 2)}_ '
      '${_plainWords(rng, rng.between(3, 6))} '
      '`${_word(rng)}` '
      '${_plainWords(rng, rng.between(5, 9))}.';
}

String _bullets(_Stream rng) {
  return <String>[
    for (int i = 0; i < 3; i++) '- ${_sentence(rng, rng.between(6, 12))}',
  ].join('\n');
}

String _numbers(_Stream rng) {
  return <String>[
    for (int i = 0; i < 3; i++)
      '${i + 1}. ${_sentence(rng, rng.between(6, 12))}',
  ].join('\n');
}

String _block(_Stream rng, int index) {
  switch (index % 8) {
    case 0:
      return '## ${_capitalise(_plainWords(rng, rng.between(2, 4)))}';
    case 2:
      return _richParagraph(rng);
    case 3:
      return _bullets(rng);
    case 5:
      return '> ${_sentence(rng, rng.between(12, 20))}';
    case 7:
      return _numbers(rng);
    default:
      return _paragraph(rng);
  }
}

String benchPhotoLine(String reference, int index) {
  final String attributes = _photoAttributes[index % _photoAttributes.length];
  return '![Field photo ${index + 1}](photo/$reference "$attributes")';
}

final RegExp _wordish = RegExp(r'[A-Za-z]');

int _countWords(String block) {
  int total = 0;
  for (final String token in block.split(RegExp(r'\s+'))) {
    if (token.isNotEmpty && _wordish.hasMatch(token)) {
      total++;
    }
  }
  return total;
}

String _composeBlocks({
  required bool Function(int chars, int words) enough,
  required List<String> photoReferences,
  required int seed,
}) {
  final _Stream rng = _Stream(seed);
  final List<String> blocks = <String>[];
  int chars = 0;
  int words = 0;
  int index = 0;
  int placed = 0;
  while (!enough(chars, words)) {
    final String block = _block(rng, index);
    blocks.add(block);
    chars += block.length + 2;
    words += _countWords(block);
    index++;
    if (placed < photoReferences.length && index % _photoEveryBlocks == 0) {
      final String line = benchPhotoLine(photoReferences[placed], placed);
      blocks.add(line);
      chars += line.length + 2;
      placed++;
    }
  }
  while (placed < photoReferences.length) {
    final String line = benchPhotoLine(photoReferences[placed], placed);
    blocks.add(line);
    placed++;
  }
  return blocks.join('\n\n');
}

String _plainRunOfLength(_Stream rng, int length) {
  if (length <= 0) {
    return '';
  }
  final StringBuffer buffer = StringBuffer();
  while (buffer.length < length) {
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(_word(rng));
  }
  return buffer.toString().substring(0, length);
}

String benchNoteOfChars(
  int chars, {
  List<String> photoReferences = const <String>[],
  int seed = _noteSeed,
}) {
  final String body = _composeBlocks(
    enough: (int written, int _) => written >= chars - _tailBudget,
    photoReferences: photoReferences,
    seed: seed,
  );
  final int remaining = chars - body.length - 2;
  if (remaining <= 0) {
    return body;
  }
  return '$body\n\n${_plainRunOfLength(_Stream(seed + 1), remaining)}';
}

String benchNoteOfWords(
  int words, {
  List<String> photoReferences = const <String>[],
  int seed = _noteSeed,
}) {
  final String body = _composeBlocks(
    enough: (int _, int written) => written >= words,
    photoReferences: photoReferences,
    seed: seed,
  );
  return '$body\n\n${_paragraph(_Stream(seed + 1))}';
}

String benchWrappedParagraphSource({int seed = _noteSeed}) {
  final _Stream rng = _Stream(seed);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < 5; i++) {
    if (i > 0) {
      buffer.write(' ');
    }
    buffer.write(_sentence(rng, rng.between(12, 16)));
  }
  return buffer.toString();
}

String benchFeedNoteSource(int index) => benchNoteOfWords(
      240,
      seed: _feedSeed + index,
    );

String benchVariant(String base, int index) =>
    '$base v${index.toString().padLeft(4, '0')}';

Future<Uint8List> benchPhotoBytes({
  required int seed,
  int width = benchPhotoWidth,
  int height = benchPhotoHeight,
}) async {
  final Rect bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder, bounds);
  final _Stream rng = _Stream(seed);
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF000000 | rng.next(0xFFFFFF)),
          Color(0xFF000000 | rng.next(0xFFFFFF)),
        ],
      ).createShader(bounds),
  );
  for (int i = 0; i < 18; i++) {
    final Paint paint = Paint()
      ..color = Color(0x88000000 | rng.next(0xFFFFFF));
    final double x = rng.next(width).toDouble();
    final double y = rng.next(height).toDouble();
    final double size = rng.between(80, 420).toDouble();
    if (i.isEven) {
      canvas.drawCircle(Offset(x, y), size / 2, paint);
    } else {
      canvas.drawRect(Rect.fromLTWH(x, y, size, size * 0.6), paint);
    }
  }
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  picture.dispose();
  final ByteData? encoded =
      await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (encoded == null) {
    throw StateError('bench photo $seed produced no encoded bytes');
  }
  return encoded.buffer.asUint8List();
}

Future<List<MediaBlob>> seedBenchPhotos({
  required MediaStore store,
  int count = benchPhotoCount,
}) async {
  final List<MediaBlob> blobs = <MediaBlob>[];
  for (int i = 0; i < count; i++) {
    final Uint8List bytes = await benchPhotoBytes(seed: _photoSeed + i);
    blobs.add(
      await store.putBytes(
        bytes: bytes,
        mime: 'image/png',
        kind: MediaKind.photo,
        width: benchPhotoWidth,
        height: benchPhotoHeight,
      ),
    );
  }
  return List<MediaBlob>.unmodifiable(blobs);
}

List<String> benchPhotoReferences(List<MediaBlob> blobs) => <String>[
      for (final MediaBlob blob in blobs)
        blob.id.substring(0, benchPhotoReferenceLength),
    ];

Future<List<Entry>> seedBenchFeed({
  required JournalRepository repository,
  required String date,
  int count = benchFeedEntryCount,
}) async {
  final List<Entry> entries = <Entry>[];
  for (int i = 0; i < count; i++) {
    entries.add(
      await repository.saveNote(
        date: date,
        source: benchFeedNoteSource(i),
        photoMediaIds: const <String>[],
      ),
    );
  }
  return List<Entry>.unmodifiable(entries);
}
