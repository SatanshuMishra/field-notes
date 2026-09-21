import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/notes/notes.dart';

const double _aspect = 3 / 2;
const double _nudge = 0.01;

final class _CurvedScaler extends TextScaler {
  const _CurvedScaler();

  @override
  double scale(double fontSize) => fontSize + 4;

  @override
  double get textScaleFactor => 1.25;
}

final class _Width {
  const _Width(this.label, this.em, {this.nudge = 0});

  final String label;
  final double em;
  final double nudge;

  double maxWidthAt(double em) => this.em * em + nudge;
}

final class _Row {
  const _Row(this.width, this.small, this.medium, this.large);

  final _Width width;
  final double? small;
  final double? medium;
  final double? large;

  double? floatEm(PhotoSize size) => switch (size) {
        PhotoSize.small => small,
        PhotoSize.medium => medium,
        PhotoSize.large => large,
        PhotoSize.full => null,
      };
}

const List<_Row> _table = <_Row>[
  _Row(_Width('390pt phone, 20 em', 20), null, null, null),
  _Row(_Width('430pt phone, 22.5 em', 22.5), null, null, null),
  _Row(_Width('a hair under the gate', 28.9, nudge: -_nudge), null, null, null),
  _Row(_Width('a hair over the gate', 28.9, nudge: _nudge), 8.5, 8.5, 8.5),
  _Row(_Width('shrinking, 30 em', 30), 8.5, 9.6, 9.6),
  _Row(_Width('Medium stops shrinking, 32.4 em', 32.4), 8.5, 12, 12),
  _Row(_Width('Large stops shrinking, 34.9 em', 34.9), 8.5, 12, 14.5),
  _Row(_Width('the full measure, 35 em', 35), 8.5, 12, 14.5),
  _Row(_Width('1280 window, pinned to 35 em', 80), 8.5, 12, 14.5),
];

const Map<String, TextScaler> _scales = <String, TextScaler>{
  '0.9x': TextScaler.linear(0.9),
  '1x': TextScaler.noScaling,
  '1.15x': TextScaler.linear(1.15),
  '1.5x': TextScaler.linear(1.5),
  'non-linear': _CurvedScaler(),
};

double _emOf(TextScaler scaler) =>
    scaler.scale(TypographyTokens.noteBody.fontSize!);

void main() {
  group('planFloat decision table', () {
    int row = 0;
    for (final _Row entry in _table) {
      for (final MapEntry<String, TextScaler> scale in _scales.entries) {
        for (final PhotoSize size in PhotoSize.values) {
          for (final bool beforeParagraph in <bool>[true, false]) {
            final PhotoSide side =
                row.isEven ? PhotoSide.right : PhotoSide.left;
            final double em = _emOf(scale.value);
            final double measure = noteMeasureFor(
              maxWidth: entry.width.maxWidthAt(em),
              em: em,
            );
            final double? floatEm =
                beforeParagraph ? entry.floatEm(size) : null;
            final String name = '#$row ${entry.width.label} @ ${scale.key}, '
                '${size.name} ${side.name}, '
                '${beforeParagraph ? 'before a paragraph' : 'before a heading'}'
                ' -> ${floatEm == null ? 'stacks' : 'floats at $floatEm em'}';
            row++;

            test(name, () {
              final PhotoPlan plan = planFloat(
                measure: measure,
                em: em,
                side: side,
                size: size,
                aspect: _aspect,
                nextIsParagraph: beforeParagraph,
              );

              expect(plan.measure, measure);
              expect(plan.side, side);
              expect(plan.size, size);
              expect(plan.gutter, closeTo(photoGutterEm * em, 1e-9));
              if (floatEm == null) {
                expect(plan.isStacked, isTrue);
                expect(
                    plan.width, closeTo(size.measureFraction * measure, 1e-9));
                expect(plan.band, measure);
              } else {
                expect(plan.isStacked, isFalse);
                expect(plan.width, closeTo(floatEm * em, 2 * _nudge));
                expect(
                  plan.band,
                  closeTo(measure - (photoGutterEm + floatEm) * em, 2 * _nudge),
                );
                expect(
                  plan.band,
                  greaterThanOrEqualTo(photoBandResidualEm * em - 1e-9),
                );
                expect(
                  plan.width,
                  greaterThanOrEqualTo(photoMinFloatEm * em - 1e-9),
                );
              }
              expect(
                plan.height,
                closeTo(plan.width / _aspect, 1e-9),
              );
            });
          }
        }
      }
    }

    test('covers every width, scale, size and next block once', () {
      expect(row, _table.length * _scales.length * 4 * 2);
      expect(row, 360);
    });
  });

  group('what the table implies', () {
    test('em is scale(fontSize), never scale(1) * fontSize', () {
      const TextScaler curved = _CurvedScaler();
      expect(_emOf(curved), 20);
      expect(curved.scale(1) * 16, isNot(20));
    });

    test('every size demotes at the same width: 28.9 em', () {
      for (final TextScaler scaler in _scales.values) {
        final double em = _emOf(scaler);
        for (final PhotoSize size in <PhotoSize>[
          PhotoSize.small,
          PhotoSize.medium,
          PhotoSize.large,
        ]) {
          PhotoPlan at(double measure) => planFloat(
                measure: measure,
                em: em,
                side: PhotoSide.right,
                size: size,
                aspect: _aspect,
                nextIsParagraph: true,
              );
          expect(at(28.9 * em + _nudge).isStacked, isFalse);
          expect(at(28.9 * em - _nudge).isStacked, isTrue);
          expect(
            at(28.9 * em + _nudge).isStacked,
            !canFloatAt(measure: 28.9 * em + _nudge, em: em),
          );
        }
      }
    });

    test('the photo shrinks continuously before it demotes', () {
      const double em = 16;
      double? previous;
      for (double measure = 560; measure >= 462.5; measure -= 0.5) {
        final PhotoPlan plan = planFloat(
          measure: measure,
          em: em,
          side: PhotoSide.right,
          size: PhotoSize.medium,
          aspect: _aspect,
          nextIsParagraph: true,
        );
        expect(plan.isStacked, isFalse, reason: '$measure');
        if (previous != null) {
          expect(previous - plan.width, lessThanOrEqualTo(0.5 + 1e-9));
        }
        previous = plan.width;
      }
      expect(previous, closeTo(136, 0.5));
    });

    test('demotion is a step, not a continuation: stated here plainly', () {
      const double em = 16;
      const double gate = 28.9 * em;
      for (final PhotoSize size in <PhotoSize>[
        PhotoSize.small,
        PhotoSize.medium,
        PhotoSize.large,
      ]) {
        final PhotoPlan floated = planFloat(
          measure: gate + _nudge,
          em: em,
          side: PhotoSide.right,
          size: size,
          aspect: _aspect,
          nextIsParagraph: true,
        );
        final PhotoPlan stacked = planFloat(
          measure: gate - _nudge,
          em: em,
          side: PhotoSide.right,
          size: size,
          aspect: _aspect,
          nextIsParagraph: true,
        );
        expect(floated.width, closeTo(136, 2 * _nudge));
        expect(
          stacked.width,
          closeTo(size.measureFraction * (gate - _nudge), 1e-9),
        );
        expect(stacked.width / floated.width, greaterThan(1.8));
      }
      final PhotoPlan medium = planFloat(
        measure: gate - _nudge,
        em: em,
        side: PhotoSide.right,
        size: PhotoSize.medium,
        aspect: _aspect,
        nextIsParagraph: true,
      );
      expect(medium.width, closeTo(346.8, 0.01));
    });

    test('the side never changes the geometry', () {
      for (final _Row entry in _table) {
        for (final PhotoSize size in PhotoSize.values) {
          PhotoPlan on(PhotoSide side) => planFloat(
                measure: noteMeasureFor(
                    maxWidth: entry.width.maxWidthAt(16), em: 16),
                em: 16,
                side: side,
                size: size,
                aspect: _aspect,
                nextIsParagraph: true,
              );
          final PhotoPlan left = on(PhotoSide.left);
          final PhotoPlan right = on(PhotoSide.right);
          expect(
            <Object>[left.width, left.height, left.band, left.isStacked],
            <Object>[right.width, right.height, right.band, right.isStacked],
          );
        }
      }
    });
  });
}
