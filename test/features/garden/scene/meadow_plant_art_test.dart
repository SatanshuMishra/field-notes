import 'dart:ui';

import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/flower_palette.dart';
import 'package:field_notes/design/flowers/garden_plant_geometry.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_plant_art.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Mood> _fixedHeads = <Mood>[
  Mood.happy,
  Mood.love,
  Mood.warm,
  Mood.grateful,
  Mood.hopeful,
  Mood.tired,
  Mood.angry,
];

MeadowPlantArt _art(Mood? mood, {int entries = 1, int seed = 1}) =>
    buildMeadowPlantArt(
      mood: mood,
      entries: entries,
      valence: mood == null ? 0 : meadowValence(mood),
      random: MeadowRandom(seed),
      driftHue: 2,
      driftLightness: 0.01,
    );

String _number(double value) {
  final double rounded = (value * 1000).round() / 1000;
  return (rounded == 0 ? 0.0 : rounded).toStringAsFixed(3);
}

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
  final String paint =
      '${part.fill} ${part.strokeColor} ${part.strokeWidth} '
      '${part.strokeCap} ${part.strokeJoin}';
  return switch (part) {
    BloomDisc() =>
      'disc ${_number(part.cx)} ${_number(part.cy)} ${_number(part.r)} $paint',
    BloomOval() =>
      'oval ${_number(part.cx)} ${_number(part.cy)} ${_number(part.rx)} '
          '${_number(part.ry)} ${_number(part.rotationDeg)} $paint',
    BloomOvalRing() =>
      'ring ${part.count} ${_number(part.cx)} ${_number(part.cy)} '
          '${_number(part.rx)} ${_number(part.ry)} ${_number(part.startDeg)} '
          '${_number(part.stepDeg)} ${_number(part.pivotX)} '
          '${_number(part.pivotY)} $paint',
    BloomShape() =>
      'shape ${part.close} ${part.commands.map(_command).join(' ')} $paint',
  };
}

List<String> _described(List<BloomPart> parts) => parts.map(_describe).toList();

class _PaintLog implements Canvas {
  final List<int> colours = <int>[];
  int draws = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final String name = invocation.memberName.toString();
    if (name.contains('draw')) {
      draws++;
      for (final Object? argument in invocation.positionalArguments) {
        if (argument is Paint) {
          colours.add(argument.color.toARGB32());
        }
      }
    }
    return null;
  }
}

void _expectPaintable(MeadowPlantArt art, String reason) {
  expect(art.bounds.isEmpty, isFalse, reason: reason);
  expect(
    art.bounds.left >= meadowPlantBox.left &&
        art.bounds.top >= meadowPlantBox.top &&
        art.bounds.right <= meadowPlantBox.right &&
        art.bounds.bottom <= meadowPlantBox.bottom,
    isTrue,
    reason: reason,
  );
  for (final Offset head in art.heads) {
    expect(art.bounds.inflate(1e-6).contains(head), isTrue, reason: reason);
  }
  final PictureRecorder recorder = PictureRecorder();
  paintMeadowPlantArt(Canvas(recorder), art);
  recorder.endRecording().dispose();
}

void main() {
  test('each mood grows its own bloom head', () {
    for (int seed = 1; seed <= 12; seed++) {
      final int entries = 1 + seed % 4;
      for (final Mood mood in _fixedHeads) {
        final String reason = '${mood.name} seed $seed';
        final MeadowPlantArt art = _art(mood, entries: entries, seed: seed);
        expect(art.placements, isNotEmpty, reason: reason);
        expect(art.heads, hasLength(art.placements.length), reason: reason);
        for (final MeadowHeadPlacement placement in art.placements) {
          expect(placement.kind, mood.flower, reason: reason);
          expect(
            identical(placement.parts, gardenBloomHeadParts(mood.flower)),
            isTrue,
            reason: reason,
          );
          expect(placement.scale, inInclusiveRange(0.5, 1), reason: reason);
        }
        _expectPaintable(art, reason);
      }

      final MeadowPlantArt anxious = _art(
        Mood.anxious,
        entries: entries,
        seed: seed,
      );
      expect(anxious.placements.length, greaterThanOrEqualTo(2));
      expect(anxious.heads, hasLength(anxious.placements.length));
      for (final MeadowHeadPlacement placement in anxious.placements) {
        expect(placement.kind, FlowerKind.aster);
        final BloomOvalRing petals = placement.parts.first as BloomOvalRing;
        final BloomDisc disc = placement.parts.last as BloomDisc;
        expect(
          _described(placement.parts),
          _described(asterDaisy(0, 0, petals.ry, disc.r)),
        );
        expect(anxious.heads, contains(placement.transform.translation));
      }
      _expectPaintable(anxious, 'anxious seed $seed');

      final MeadowPlantArt sad = _art(Mood.sad, entries: entries, seed: seed);
      expect(sad.placements.length, inInclusiveRange(4, 7));
      expect(sad.heads, hasLength(sad.placements.length));
      for (final MeadowHeadPlacement placement in sad.placements) {
        expect(placement.kind, FlowerKind.bleedingHeart);
        final BloomShape lobe = placement.parts.first as BloomShape;
        final double size = (lobe.commands.first as BloomMoveTo).y / 0.3;
        expect(size, inInclusiveRange(4, 8.41));
        expect(
          _described(placement.parts),
          _described(pendantHeart(0, 0, size)),
        );
      }
      _expectPaintable(sad, 'sad seed $seed');

      final MeadowPlantArt calm = _art(Mood.calm, entries: entries, seed: seed);
      expect(calm.placements.length, inInclusiveRange(3, 6));
      expect(calm.heads, hasLength(calm.placements.length));
      for (final MeadowHeadPlacement placement in calm.placements) {
        expect(placement.kind, FlowerKind.lavender);
        expect(placement.parts.length, inInclusiveRange(5, 7));
        final List<BloomOval> florets = placement.parts
            .cast<BloomOval>()
            .toList();
        for (int k = 0; k < florets.length; k++) {
          expect(
            florets[k].fill,
            k.isOdd
                ? FlowerColors.lavenderFloret
                : FlowerColors.lavenderFloretDeep,
          );
          expect(florets[k].strokeColor, FlowerColors.lavenderStroke);
          if (k > 0) {
            expect(florets[k].rx, lessThan(florets[k - 1].rx));
            expect(florets[k].ry, lessThan(florets[k - 1].ry));
          }
        }
      }
      _expectPaintable(calm, 'calm seed $seed');

      final MeadowPlantArt sprout = _art(null, entries: 2, seed: seed);
      expect(sprout.placements, isEmpty);
      expect(sprout.shapes, isNotEmpty);
      expect(sprout.heads, <Offset>[const Offset(0, -18)]);
      _expectPaintable(sprout, 'sprout seed $seed');
    }
  });

  test('three or more entries add a second bloom and heavy days nod', () {
    for (int seed = 1; seed <= 20; seed++) {
      expect(_art(Mood.happy, entries: 3, seed: seed).placements, hasLength(2));
      expect(_art(Mood.happy, entries: 2, seed: seed).placements, hasLength(1));
      for (final Mood mood in <Mood>[
        Mood.love,
        Mood.warm,
        Mood.grateful,
        Mood.hopeful,
        Mood.angry,
      ]) {
        expect(
          _art(mood, entries: 4, seed: seed).placements,
          hasLength(2),
          reason: '${mood.name} seed $seed',
        );
        expect(
          _art(mood, entries: 1, seed: seed).placements,
          hasLength(1),
          reason: '${mood.name} seed $seed',
        );
      }
      for (final Mood mood in Mood.values) {
        final double nod = _art(mood, seed: seed).nodDegrees;
        if (meadowValence(mood) < 0) {
          expect(nod.abs(), inInclusiveRange(5, 13), reason: mood.name);
        } else {
          expect(nod, 0, reason: mood.name);
        }
      }
      expect(_art(null, entries: 1, seed: seed).nodDegrees, 0);
    }
  });

  test(
    'bloom heads take the drift colour shift and stems keep their greens',
    () {
      const MeadowColourShift shift = MeadowColourShift(
        hue: 5,
        saturation: 0.03,
        lightness: -0.02,
      );
      expect(shift.apply(const Color(0xFFF2A9B2)), const Color(0xFFF29FA2));
      expect(
        const MeadowColourShift(
          hue: -4,
          saturation: -0.05,
          lightness: 0.02,
        ).apply(const Color(0xFF7A4A24)),
        const Color(0xFF7E4A2B),
      );
      expect(
        const MeadowColourShift(
          hue: 4,
          saturation: 0.02,
        ).apply(const Color(0xFF808080)),
        const Color(0xFF837E7D),
      );
      expect(
        MeadowColourShift.none.apply(FlowerColors.peonyCore),
        FlowerColors.peonyCore,
      );

      final MeadowPlantArt art = _art(Mood.happy, seed: 7);
      expect(art.shift.isNone, isFalse);
      final _PaintLog log = _PaintLog();
      paintMeadowPlantArt(log, art);
      expect(log.draws, greaterThan(10));
      expect(
        log.colours,
        contains(art.shift.apply(FlowerColors.peonyCore).toARGB32()),
      );
      expect(log.colours, isNot(contains(FlowerColors.peonyCore.toARGB32())));
      expect(log.colours, contains(FlowerColors.gardenLeafStroke.toARGB32()));
    },
  );
}
