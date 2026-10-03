import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/today/today_layout.dart';

double _constant(String source, String name) {
  final RegExp pattern = RegExp(
    'private let ${RegExp.escape(name)}: CGFloat = ([0-9.]+)',
  );
  final RegExpMatch? match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: '$name must be a literal CGFloat constant');
  return double.parse(match!.group(1)!);
}

void main() {
  group('macOS window minimum size', () {
    final String swift = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();

    test('contentMinSize is set from the named minimum content constants', () {
      final RegExp assignment = RegExp(
        r'self\.contentMinSize\s*=\s*NSSize\(\s*width:\s*minimumContentWidth,'
        r'\s*height:\s*minimumContentHeight\s*\)',
        multiLine: true,
      );
      expect(swift, matches(assignment));
    });

    test(
      'the minimum width leaves a readable column beside the shell chrome',
      () {
        final double sidebar = _constant(swift, 'sidebarWidth');
        final double rail = _constant(swift, 'todayRailWidth');
        final double seam = _constant(swift, 'seamWidth');
        final double panePadding = _constant(swift, 'todayPanePadding');
        final double cardPadding = _constant(swift, 'entryCardPadding');
        final double fontSize = _constant(swift, 'noteBodyFontSize');
        final double columnEm = _constant(swift, 'minimumReadingColumnEm');

        expect(sidebar, greaterThan(0));
        expect(rail, todayRailWidth);
        expect(fontSize, TypographyTokens.noteBody.fontSize);
        expect(columnEm, 19.4);

        final double chrome =
            sidebar + rail + 2 * seam + 2 * panePadding + 2 * cardPadding;
        final double column = columnEm * fontSize;
        expect(column, greaterThan(0));
        expect(chrome + column, greaterThan(chrome));
        expect(
          swift,
          contains('minimumReadingColumnEm * noteBodyFontSize'),
          reason: 'the minimum width must be derived from the reading column',
        );
      },
    );

    test('the minimum height is a positive literal', () {
      expect(_constant(swift, 'minimumContentHeight'), greaterThan(0));
    });

  });

  group('macOS window opening size', () {
    final String swift = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();

    test('the window opens at 1200 by 800 points', () {
      expect(_constant(swift, 'openingWindowWidth'), 1200);
      expect(_constant(swift, 'openingWindowHeight'), 800);
      expect(swift, contains('self.setFrame(self.openingFrame(), display: true)'));
    });

    test('the opening frame fits the visible screen and never drops below '
        'the minimum', () {
      expect(swift, contains('min(openingWindowWidth, visible.width)'));
      expect(swift, contains('min(openingWindowHeight, visible.height)'));
      expect(swift, contains('minimumFrame.width'));
      expect(swift, contains('minimumFrame.height'));
    });

    test('the opening frame is centred on the visible screen', () {
      expect(swift, contains('visible.midX - width / 2'));
      expect(swift, contains('visible.midY - height / 2'));
    });
  });
}
