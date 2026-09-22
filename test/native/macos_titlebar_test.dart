import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/window_chrome.dart';

double _constant(String source, String name) {
  final RegExp pattern = RegExp(
    'private let ${RegExp.escape(name)}: CGFloat = ([0-9.]+)',
  );
  final RegExpMatch? match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: '$name must be a literal CGFloat constant');
  return double.parse(match!.group(1)!);
}

void main() {
  group('macOS titlebar', () {
    final String swift = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();

    test('the system titlebar is transparent, untitled and under the content',
        () {
      expect(swift, contains('self.titleVisibility = .hidden'));
      expect(swift, contains('self.titlebarAppearsTransparent = true'));
      expect(swift, contains('self.styleMask.insert(.fullSizeContentView)'));
    });

    test('the window buttons are laid out inside the shell titlebar', () {
      expect(_constant(swift, 'titleBarHeight'), shellTitleBarHeight);
      expect(_constant(swift, 'windowButtonsLeading'), shellTitleBarPadding);
    });

    test('the window answers the titlebar calls the shell makes', () {
      expect(swift, contains('"$windowChannelName"'));
      expect(swift, contains('case "$startDragMethod":'));
      expect(swift, contains('case "$titlebarDoubleClickMethod":'));
    });

    test('a titlebar double-click follows the system setting', () {
      expect(swift, contains('"AppleActionOnDoubleClick"'));
      expect(swift, contains('case "Minimize":'));
      expect(swift, contains('case "None":'));
    });
  });
}
