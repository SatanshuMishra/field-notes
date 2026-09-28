import 'dart:ui' as ui;

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

PhotoLayoutPlan _plan(
  String title, {
  required double column,
  double? aspect,
  TextScaler textScaler = TextScaler.noScaling,
  bool unavailable = false,
  String caption = '',
  bool boldText = false,
}) => planPhoto(
  placement: MdPhotoPlacement.parse(title),
  columnWidth: column,
  textScaler: textScaler,
  aspect: aspect,
  unavailable: unavailable,
  caption: caption,
  boldText: boldText,
  locale: const ui.Locale('en', 'US'),
);

double _oneCaptionLine() {
  final TextPainter painter = TextPainter(
    text: const TextSpan(text: 'Low tide', style: TypographyTokens.captionSans),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: 344);
  final double height = painter.height;
  painter.dispose();
  return height;
}

void main() {
  test('size fractions apply on a desktop column', () {
    const Map<String, double> widths = <String, double>{
      'centre small': 229.33,
      'centre medium': 344,
      'centre large': 458.67,
      'centre full': 688,
    };
    for (final MapEntry<String, double> entry in widths.entries) {
      final PhotoLayoutPlan plan = _plan(entry.key, column: 688, aspect: 4 / 3);
      expect(plan.width, closeTo(entry.value, 0.01), reason: entry.key);
      expect(plan.photoHeight, closeTo(plan.width * 0.75, 1e-9));
      expect(plan.mode, PhotoMode.centred);
      expect(plan.floats, isFalse);
    }
    final PhotoLayoutPlan medium = _plan(
      'centre medium',
      column: 688,
      aspect: 4 / 3,
    );
    expect(medium.width, 344);
    expect(medium.photoHeight, 258);
    final PhotoLayoutPlan right = _plan(
      'right medium',
      column: 688,
      aspect: 4 / 3,
    );
    expect(right.width, 344);
    expect(right.photoHeight, 258);
    expect(right.mode, PhotoMode.floatRight);
    expect(right.bandWidth, closeTo(328, 1e-9));
    final PhotoLayoutPlan left = _plan(
      'left large',
      column: 688,
      aspect: 3 / 2,
    );
    expect(left.width, closeTo(458.67, 0.01));
    expect(left.photoHeight, closeTo(305.78, 0.01));
    expect(left.mode, PhotoMode.floatLeft);
    expect(left.bandWidth, closeTo(213.33, 0.01));
  });

  test('every photo is full width on a phone column', () {
    const List<String> sides = <String>['left', 'centre', 'right'];
    const List<String> sizes = <String>['small', 'medium', 'large', 'full'];
    final List<String> titles = <String>[
      for (final String side in sides)
        for (final String size in sizes) '$side $size',
      'sideways',
    ];
    for (final String title in titles) {
      final PhotoLayoutPlan plan = _plan(title, column: 350, aspect: 3 / 2);
      expect(plan.width, 350, reason: title);
      expect(plan.mode, PhotoMode.centred, reason: title);
      expect(plan.floats, isFalse, reason: title);
      expect(plan.bandWidth, 0, reason: title);
      expect(plan.photoHeight, closeTo(233.33, 0.01), reason: title);
    }
    for (final String title in <String>['left small', 'right large']) {
      final PhotoLayoutPlan plan = _plan(
        title,
        column: 688,
        aspect: 3 / 2,
        textScaler: const TextScaler.linear(2.0),
      );
      expect(plan.width, 688, reason: title);
      expect(plan.mode, PhotoMode.centred, reason: title);
      expect(plan.floats, isFalse, reason: title);
    }
  });

  test('a left or right photo floats only with a twelve em band', () {
    final PhotoLayoutPlan wideRight = _plan(
      'right large',
      column: 720,
      aspect: 3 / 2,
    );
    expect(wideRight.mode, PhotoMode.floatRight);
    expect(wideRight.width, closeTo(480, 1e-9));
    expect(wideRight.bandWidth, closeTo(224, 1e-9));
    final PhotoLayoutPlan wideLeft = _plan(
      'left large',
      column: 720,
      aspect: 3 / 2,
    );
    expect(wideLeft.mode, PhotoMode.floatLeft);
    expect(wideLeft.width, closeTo(480, 1e-9));
    for (final String title in <String>['right large', 'left large']) {
      final PhotoLayoutPlan plan = _plan(title, column: 560, aspect: 3 / 2);
      expect(plan.mode, PhotoMode.centred, reason: title);
      expect(plan.width, closeTo(373.33, 0.01), reason: title);
      expect(plan.floats, isFalse, reason: title);
      expect(plan.bandWidth, 0, reason: title);
    }
    final PhotoLayoutPlan medium = _plan(
      'left medium',
      column: 560,
      aspect: 3 / 2,
    );
    expect(medium.mode, PhotoMode.floatLeft);
    expect(medium.width, closeTo(280, 1e-9));
    expect(medium.bandWidth, closeTo(264, 1e-9));
  });

  test('an invalid placement is a centred medium block', () {
    for (final String title in <String>['left left', 'left sideways']) {
      expect(MdPhotoPlacement.parse(title).isValid, isFalse, reason: title);
      final PhotoLayoutPlan desktop = _plan(title, column: 688, aspect: 3 / 2);
      expect(desktop.mode, PhotoMode.centred, reason: title);
      expect(desktop.width, 344, reason: title);
      expect(desktop.floats, isFalse, reason: title);
      final PhotoLayoutPlan phone = _plan(title, column: 350, aspect: 3 / 2);
      expect(phone.width, 350, reason: title);
      expect(phone.mode, PhotoMode.centred, reason: title);
    }
  });

  test('constants match the layout rules', () {
    expect(desktopColumnEm, 30);
    expect(floatGutterEm, 1);
    expect(minFloatBandEm, 12);
    expect(photoMaxHeightFactor, 1.6);
    expect(photoPlaceholderAspect, 1.5);
    expect(photoCaptionGap, 8);
    expect(photoUnavailableHeight, 56);
  });

  test('a desktop column starts at thirty em', () {
    expect(isDesktopColumn(columnWidth: 480, em: 16), isTrue);
    expect(isDesktopColumn(columnWidth: 479, em: 16), isFalse);
    expect(isDesktopColumn(columnWidth: 688, em: 32), isFalse);
    expect(photoWidthFor(MdPhotoSize.small, columnWidth: 688, em: 32), 688);
    expect(
      photoWidthFor(MdPhotoSize.small, columnWidth: 688, em: 16),
      closeTo(229.33, 0.01),
    );
  });

  test('a null aspect plans a three by two placeholder', () {
    final PhotoLayoutPlan plan = _plan('right medium', column: 688);
    expect(plan.isPlaceholder, isTrue);
    expect(plan.photoHeight, closeTo(344 / 1.5, 1e-9));
    expect(photoHeightFor(width: 300), 200);
    expect(
      _plan('right medium', column: 688, aspect: 1).isPlaceholder,
      isFalse,
    );
  });

  test('a tall portrait clamps and a panorama keeps one pixel', () {
    expect(photoHeightFor(width: 344, aspect: 0.5), closeTo(550.4, 1e-9));
    expect(photoHeightFor(width: 344, aspect: 10000), 1);
    expect(
      _plan('centre medium', column: 688, aspect: 0.5).photoHeight,
      closeTo(550.4, 1e-9),
    );
  });

  test(
    'stored dimensions give the aspect only when both sides are positive',
    () {
      expect(photoAspectFor(const Size(1600, 1200)), 4 / 3);
      expect(photoAspectFor(null), isNull);
      expect(photoAspectFor(const Size(0, 800)), isNull);
      expect(photoAspectFor(const Size(800, -1)), isNull);
    },
  );

  test('a caption adds the gap and its wrapped lines', () {
    final double line = _oneCaptionLine();
    final PhotoLayoutPlan captioned = _plan(
      'centre medium',
      column: 688,
      aspect: 4 / 3,
      caption: 'Low tide',
    );
    expect(captioned.captionHeight, closeTo(line, 1e-9));
    expect(captioned.figureHeight, closeTo(258 + 8 + line, 1e-9));
    final PhotoLayoutPlan bare = _plan(
      'centre medium',
      column: 688,
      aspect: 4 / 3,
    );
    expect(bare.captionHeight, 0);
    expect(bare.figureHeight, 258);
    final PhotoLayoutPlan long = _plan(
      'centre small',
      column: 688,
      aspect: 4 / 3,
      caption: List<String>.filled(12, 'tide pools at dawn').join(' '),
    );
    expect(long.captionHeight, greaterThan(line * 2.5));
    final PhotoLayoutPlan scaled = _plan(
      'centre medium',
      column: 688,
      aspect: 4 / 3,
      caption: 'Low tide',
      textScaler: const TextScaler.linear(1.15),
    );
    expect(scaled.captionHeight, greaterThan(captioned.captionHeight));
  });

  test('bold text measures the caption in bold', () {
    final double line = _oneCaptionLine();
    const String source =
        'Tide pools at dawn with herons and crabs along the far rocks';
    String fitting = '';
    for (int end = 1; end <= source.length; end++) {
      final String candidate = source.substring(0, end);
      final PhotoLayoutPlan plan = _plan(
        'centre small',
        column: 688,
        aspect: 4 / 3,
        caption: candidate,
      );
      if (plan.captionHeight > line * 1.5) {
        break;
      }
      fitting = candidate;
    }
    expect(fitting.length, lessThan(source.length));
    final PhotoLayoutPlan regular = _plan(
      'centre small',
      column: 688,
      aspect: 4 / 3,
      caption: fitting,
    );
    final PhotoLayoutPlan bold = _plan(
      'centre small',
      column: 688,
      aspect: 4 / 3,
      caption: fitting,
      boldText: true,
    );
    expect(regular.captionHeight, closeTo(line, 1e-9));
    expect(bold.captionHeight, greaterThan(line * 1.5));
  });

  test('an unavailable photo is a fifty six pixel centred block', () {
    final PhotoLayoutPlan desktop = _plan(
      'right medium',
      column: 688,
      unavailable: true,
      caption: 'Low tide',
    );
    expect(desktop.photoHeight, 56);
    expect(desktop.width, 344);
    expect(desktop.mode, PhotoMode.centred);
    expect(desktop.floats, isFalse);
    expect(desktop.bandWidth, 0);
    expect(desktop.isPlaceholder, isFalse);
    expect(desktop.isUnavailable, isTrue);
    expect(desktop.captionHeight, closeTo(_oneCaptionLine(), 1e-9));
    final PhotoLayoutPlan phone = _plan(
      'left small',
      column: 350,
      aspect: 3 / 2,
      unavailable: true,
    );
    expect(phone.width, 350);
    expect(phone.photoHeight, 56);
    expect(phone.isUnavailable, isTrue);
  });

  test('center is read as centre', () {
    expect(
      _plan('center medium', column: 688, aspect: 4 / 3),
      _plan('centre medium', column: 688, aspect: 4 / 3),
    );
  });

  test('a full photo never floats', () {
    for (final String title in <String>['left full', 'right full']) {
      final PhotoLayoutPlan plan = _plan(title, column: 720, aspect: 3 / 2);
      expect(plan.mode, PhotoMode.centred, reason: title);
      expect(plan.width, 720, reason: title);
    }
    expect(
      photoCanFloat(size: MdPhotoSize.full, columnWidth: 2000, em: 16),
      isFalse,
    );
  });

  test('an exact twelve em band still floats', () {
    expect(
      photoCanFloat(size: MdPhotoSize.large, columnWidth: 624, em: 16),
      isTrue,
    );
    expect(
      photoCanFloat(size: MdPhotoSize.large, columnWidth: 623, em: 16),
      isFalse,
    );
    expect(
      photoCanFloat(size: MdPhotoSize.small, columnWidth: 350, em: 16),
      isFalse,
    );
  });

  test('plans compare by value', () {
    final PhotoLayoutPlan a = _plan('left medium', column: 688, aspect: 1.5);
    final PhotoLayoutPlan b = _plan('left medium', column: 688, aspect: 1.5);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(_plan('right medium', column: 688, aspect: 1.5)));
    expect(
      const PhotoLayoutPlan(mode: PhotoMode.centred, width: 10, photoHeight: 5),
      isNot(
        const PhotoLayoutPlan(
          mode: PhotoMode.centred,
          width: 10,
          photoHeight: 5,
          isPlaceholder: true,
        ),
      ),
    );
    expect(a.toString(), contains('floatLeft'));
  });
}
