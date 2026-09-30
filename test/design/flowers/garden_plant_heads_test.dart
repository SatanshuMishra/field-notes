import 'dart:ui';

import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/garden_plant_geometry.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:flutter_test/flutter_test.dart';

String _number(double value) {
  final double rounded = (value * 1000).round() / 1000;
  return (rounded == 0 ? 0.0 : rounded).toStringAsFixed(3);
}

String _colour(Color? colour) =>
    colour == null ? '-' : colour.toARGB32().toRadixString(16);

String _command(BloomCmd command) => switch (command) {
  BloomMoveTo() => 'M ${_number(command.x)} ${_number(command.y)}',
  BloomLineTo() => 'L ${_number(command.x)} ${_number(command.y)}',
  BloomQuadTo() =>
    'Q ${_number(command.cx)} ${_number(command.cy)} '
        '${_number(command.x)} ${_number(command.y)}',
  BloomCubicTo() =>
    'C ${_number(command.c1x)} ${_number(command.c1y)} '
        '${_number(command.c2x)} ${_number(command.c2y)} '
        '${_number(command.x)} ${_number(command.y)}',
  BloomArcTo() =>
    'A ${_number(command.rx)} ${_number(command.ry)} ${command.largeArc} '
        '${command.clockwise} ${_number(command.x)} ${_number(command.y)}',
};

String _describe(BloomPart part) {
  final double? width = part.strokeWidth;
  final String paint =
      '${_colour(part.fill)} ${_colour(part.strokeColor)} '
      '${width == null ? '-' : _number(width)} '
      '${part.strokeCap.name} ${part.strokeJoin.name}';
  return switch (part) {
    BloomDisc() =>
      'disc ${_number(part.cx)} ${_number(part.cy)} ${_number(part.r)} $paint',
    BloomOval() =>
      'oval ${_number(part.cx)} ${_number(part.cy)} ${_number(part.rx)} '
          '${_number(part.ry)} ${_number(part.rotationDeg)} '
          '${_number(part.pivotX)} ${_number(part.pivotY)} $paint',
    BloomOvalRing() =>
      'ring ${part.count} ${_number(part.cx)} ${_number(part.cy)} '
          '${_number(part.rx)} ${_number(part.ry)} ${_number(part.startDeg)} '
          '${_number(part.stepDeg)} ${_number(part.pivotX)} '
          '${_number(part.pivotY)} $paint',
    BloomShape() =>
      'shape ${part.close} ${part.commands.map(_command).join(' ')} $paint',
  };
}

int _fingerprint(GardenPlantSpec spec) {
  final String text = <String>[
    '${spec.kind.name} ${_number(spec.viewBoxHeight)} '
        '${_colour(spec.strokeColor)} ${_number(spec.strokeWidth)}',
    ...spec.parts.map(_describe),
  ].join('\n');
  int hash = 0x811C9DC5;
  for (final int unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

const Map<FlowerKind, (int, int)> _heads = <FlowerKind, (int, int)>{
  FlowerKind.peony: (7, 0xAAD06BD7),
  FlowerKind.rose: (6, 0xE052291A),
  FlowerKind.sunflower: (13, 0xAF4C384B),
  FlowerKind.chrysanthemum: (5, 0x050B776E),
  FlowerKind.daffodil: (4, 0xF0BC5148),
  FlowerKind.poppy: (16, 0xDD272131),
  FlowerKind.redSpiderLily: (19, 0xB2207BF1),
};

const Map<FlowerKind, int> _otherFingerprints = <FlowerKind, int>{
  FlowerKind.lavender: 0x7CDD4521,
  FlowerKind.aster: 0x959499E3,
  FlowerKind.bleedingHeart: 0xBA9A6665,
};

void main() {
  test("bloom heads are the plant art's own head parts", () {
    for (final MapEntry<FlowerKind, (int, int)> entry in _heads.entries) {
      final FlowerKind kind = entry.key;
      final (int count, int fingerprint) = entry.value;
      final GardenPlantSpec spec = gardenPlantSpecFor(kind);
      final List<BloomPart> heads = gardenBloomHeadParts(kind);
      expect(heads, hasLength(count), reason: kind.name);
      expect(
        spec.parts.sublist(spec.parts.length - count),
        orderedEquals(heads),
        reason: kind.name,
      );
      expect(identical(gardenBloomHeadParts(kind), heads), isTrue);
      expect(_fingerprint(spec), fingerprint, reason: kind.name);
    }
    for (final MapEntry<FlowerKind, int> entry in _otherFingerprints.entries) {
      expect(
        _fingerprint(gardenPlantSpecFor(entry.key)),
        entry.value,
        reason: entry.key.name,
      );
    }
  });
}
