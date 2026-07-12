import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/motion/motion.dart';

void main() {
  group('Motion tokens', () {
    test('every motion duration is strictly positive', () {
      for (final Duration d in Motion.all) {
        expect(
          d,
          greaterThan(Duration.zero),
          reason: 'a zero-length animation would never play',
        );
      }
    });

    test('exposes the seven locked durations', () {
      expect(Motion.all, hasLength(7));
      expect(
        Motion.all,
        containsAll(<Duration>[
          Motion.blink,
          Motion.pulse,
          Motion.bob,
          Motion.fade,
          Motion.toastRise,
          Motion.modalPop,
          Motion.sheetSlide,
        ]),
      );
    });
  });
}
