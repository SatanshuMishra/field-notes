import 'package:flutter/foundation.dart';

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/domain/notes/notes.dart';

enum PhotoSide {
  left('Left'),
  right('Right');

  const PhotoSide(this.label);

  final String label;
}

enum PhotoSize {
  small('Small', 'S', 0.55),
  medium('Medium', 'M', 0.75),
  large('Large', 'L', 0.92),
  full('Full', 'Full', 1.0);

  const PhotoSize(this.label, this.shortLabel, this.measureFraction);

  final String label;
  final String shortLabel;
  final double measureFraction;
}

const PhotoSide defaultPhotoSide = PhotoSide.right;
const PhotoSize defaultPhotoSize = PhotoSize.medium;

final RegExp _attributeSeparator = RegExp(r'[ \t]+');
final RegExp _captionLineBreak = RegExp(r'[\r\n]');

@immutable
final class PhotoPlacement {
  const PhotoPlacement({
    this.side = defaultPhotoSide,
    this.size = defaultPhotoSize,
    this.extras = const <String>[],
  });

  factory PhotoPlacement.parse(String attributes) {
    PhotoSide? side;
    PhotoSize? size;
    final List<String> extras = <String>[];
    for (final String token in attributes.split(_attributeSeparator)) {
      if (token.isEmpty) {
        continue;
      }
      final String name = token.toLowerCase();
      final PhotoSide? asSide = _named(PhotoSide.values, name);
      final PhotoSize? asSize = _named(PhotoSize.values, name);
      if (asSide != null) {
        side ??= asSide;
      } else if (asSize != null) {
        size ??= asSize;
      } else {
        extras.add(token);
      }
    }
    return PhotoPlacement(
      side: side ?? defaultPhotoSide,
      size: size ?? defaultPhotoSize,
      extras: List<String>.unmodifiable(extras),
    );
  }

  final PhotoSide side;
  final PhotoSize size;
  final List<String> extras;

  PhotoPlacement copyWith({PhotoSide? side, PhotoSize? size}) {
    return PhotoPlacement(
      side: side ?? this.side,
      size: size ?? this.size,
      extras: extras,
    );
  }

  String format() =>
      <String>[side.name, size.name, ...extras].join(' ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoPlacement &&
          side == other.side &&
          size == other.size &&
          listEquals(extras, other.extras);

  @override
  int get hashCode => Object.hash(side, size, Object.hashAll(extras));

  @override
  String toString() => 'PhotoPlacement(${format()})';
}

T? _named<T extends Enum>(List<T> values, String name) {
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

extension PhotoBlockPlacement on PhotoBlock {
  PhotoPlacement get placement => PhotoPlacement.parse(attributes);

  String get caption => alt;
}

String sanitizePhotoCaption(String caption) =>
    caption.replaceAll(']', '').replaceAll(_captionLineBreak, ' ');

String photoLineFor({
  required String reference,
  String caption = '',
  PhotoPlacement placement = const PhotoPlacement(),
}) {
  return '![${sanitizePhotoCaption(caption)}]'
      '($photoReferenceScheme$reference "${placement.format()}")';
}
