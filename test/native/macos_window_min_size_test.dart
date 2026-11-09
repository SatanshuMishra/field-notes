import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/sidebar_shell.dart';
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
    final String swift = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();

    test('contentMinSize is set from the named minimum content constants', () {
      final RegExp assignment = RegExp(
        r'self\.contentMinSize\s*=\s*NSSize\(\s*width:\s*minimumContentWidth,'
        r'\s*height:\s*minimumContentHeight\s*\)',
        multiLine: true,
      );
      expect(swift, matches(assignment));
    });

    test('the minimum width lets both narrow layouts appear', () {
      final double minimumWidth = _constant(swift, 'minimumContentWidth');

      expect(minimumWidth, 720);
      expect(minimumWidth, lessThan(shellSidebarOpenMinWindowWidth));
      expect(minimumWidth, lessThan(todayRailMinWindowWidth));
    });

    test('the minimum height stays at 600', () {
      expect(_constant(swift, 'minimumContentHeight'), 600);
    });
  });

  group('macOS window opening size', () {
    final String swift = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();

    test('the window opens at 1200 by 800 points', () {
      expect(_constant(swift, 'openingWindowWidth'), 1200);
      expect(_constant(swift, 'openingWindowHeight'), 800);
      expect(
        swift,
        contains('self.setFrame(self.openingFrame(), display: true)'),
      );
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
