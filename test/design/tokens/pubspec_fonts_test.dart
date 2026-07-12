import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pubspec font registration', () {
    late String pubspec;

    setUpAll(() {
      pubspec = File('pubspec.yaml').readAsStringSync();
    });

    test('registers the three vendored font families by exact name', () {
      expect(pubspec, contains('family: Newsreader'));
      expect(pubspec, contains('family: Instrument Sans'));
      expect(pubspec, contains('family: Caveat'));
    });

    test('points each family at its vendored variable font asset', () {
      expect(pubspec, contains('assets/fonts/Newsreader-Variable.ttf'));
      expect(pubspec, contains('assets/fonts/Newsreader-Italic-Variable.ttf'));
      expect(pubspec, contains('assets/fonts/InstrumentSans-Variable.ttf'));
      expect(pubspec, contains('assets/fonts/Caveat-Variable.ttf'));
    });

    test('does not pull in the google_fonts package', () {
      expect(pubspec.contains('google_fonts'), isFalse);
    });
  });
}
