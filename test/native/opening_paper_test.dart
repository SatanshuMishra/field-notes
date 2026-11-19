import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/field_notes_colors.dart';

const String _res = 'android/app/src/main/res';
const String _macWindow = 'macos/Runner/MainFlutterWindow.swift';
const String _winRunner = 'windows/runner';

String _read(String path) => File(path).readAsStringSync();

String _channelHex(double channel) =>
    (channel * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();

List<String> _rgbHex(Color color) => <String>[
  _channelHex(color.r),
  _channelHex(color.g),
  _channelHex(color.b),
];

String _androidHex(Color color) => '#${_rgbHex(color).join()}';

String _openingPaperColour(String colorsXml) {
  final RegExpMatch? match = RegExp(
    r'<color\s+name="opening_paper"\s*>\s*([^<\s]+)\s*</color>',
  ).firstMatch(colorsXml);
  expect(match, isNotNull, reason: 'opening_paper is not defined');
  return match!.group(1)!.toUpperCase();
}

String _firstLayerDrawable(String launchBackground) {
  final RegExpMatch? match = RegExp(r'<item\s+android:drawable="([^"]+)"')
      .firstMatch(launchBackground);
  expect(match, isNotNull, reason: 'the launch background draws no layer');
  return match!.group(1)!;
}

String _styleItem(String stylesXml, String styleName, String itemName) {
  final RegExpMatch? style = RegExp(
    '<style\\s+name="${RegExp.escape(styleName)}"[^>]*>(.*?)</style>',
    dotAll: true,
  ).firstMatch(stylesXml);
  expect(style, isNotNull, reason: '$styleName is not defined');
  final RegExpMatch? item = RegExp(
    '<item\\s+name="${RegExp.escape(itemName)}"\\s*>\\s*([^<\\s]+)\\s*</item>',
  ).firstMatch(style!.group(1)!);
  expect(item, isNotNull, reason: '$styleName sets no $itemName');
  return item!.group(1)!;
}

String _swiftColour(Color color) {
  final List<String> rgb = _rgbHex(color);
  return 'NSColor(srgbRed: 0x${rgb[0]} / 255.0, green: 0x${rgb[1]} / 255.0, '
      'blue: 0x${rgb[2]} / 255.0, alpha: 1)';
}

String _cppColour(Color color) {
  final List<String> rgb = _rgbHex(color);
  return 'RGB(0x${rgb[0]}, 0x${rgb[1]}, 0x${rgb[2]})';
}

String _cppBlock(String source, String opening) {
  final int start = source.indexOf(opening);
  expect(start, isNot(-1), reason: 'the Windows runner has no $opening');
  final int end = source.indexOf(RegExp(r'\n    case |\n}\n'), start + 1);
  return source.substring(start, end == -1 ? source.length : end);
}

String _awakeFromNibBody(String swift) {
  final int start = swift.indexOf('override func awakeFromNib()');
  expect(start, isNot(-1), reason: 'the window overrides no awakeFromNib');
  final int end = swift.indexOf('super.awakeFromNib()', start);
  expect(end, isNot(-1), reason: 'awakeFromNib never calls super');
  return swift.substring(start, end);
}

void main() {
  test(
    'Android draws the shell paper before and behind Flutter in light and dark',
    () {
      expect(
        _openingPaperColour(_read('$_res/values/colors.xml')),
        _androidHex(FieldNotesColors.light.panelTop),
      );
      expect(
        _openingPaperColour(_read('$_res/values-night/colors.xml')),
        _androidHex(FieldNotesColors.dark.panelTop),
      );

      for (final String drawable in <String>['drawable', 'drawable-v21']) {
        expect(
          _firstLayerDrawable(_read('$_res/$drawable/launch_background.xml')),
          '@color/opening_paper',
          reason: '$drawable/launch_background.xml',
        );
      }

      for (final String values in <String>['values', 'values-night']) {
        expect(
          _styleItem(
            _read('$_res/$values/styles.xml'),
            'NormalTheme',
            'android:windowBackground',
          ),
          '@color/opening_paper',
          reason: '$values NormalTheme',
        );
      }

      for (final String values in <String>['values-v31', 'values-night-v31']) {
        expect(
          _styleItem(
            _read('$_res/$values/styles.xml'),
            'LaunchTheme',
            'android:windowSplashScreenBackground',
          ),
          '@color/opening_paper',
          reason: '$values LaunchTheme',
        );
      }
    },
  );

  test('the Mac window opens on the shell paper', () {
    final String swift = _read(_macWindow);
    final RegExpMatch? dynamicColour = RegExp(
      r'let\s+(\w+)\s*=\s*NSColor\(\s*name:[^,]*,\s*dynamicProvider:\s*\{\s*'
      r'appearance\s+in\s*'
      r'appearance\.bestMatch\(from:\s*\[\s*\.aqua,\s*\.darkAqua\s*\]\)\s*'
      r'==\s*\.darkAqua\s*\?\s*(NSColor\([^)]*\))\s*:\s*(NSColor\([^)]*\))\s*\}',
    ).firstMatch(swift);
    expect(
      dynamicColour,
      isNotNull,
      reason: 'no NSColor picks its value by the .aqua or .darkAqua match',
    );
    final String name = dynamicColour!.group(1)!;
    expect(
      dynamicColour.group(2),
      _swiftColour(FieldNotesColors.dark.panelTop),
    );
    expect(
      dynamicColour.group(3),
      _swiftColour(FieldNotesColors.light.panelTop),
    );

    final String awake = _awakeFromNibBody(swift);
    final int controller = awake.indexOf(
      'let flutterViewController = FlutterViewController()',
    );
    final int viewBackground = awake.indexOf(
      'flutterViewController.backgroundColor = $name',
    );
    expect(controller, isNot(-1));
    expect(
      viewBackground,
      greaterThan(controller),
      reason: 'the Flutter view does not open on $name',
    );
    expect(
      awake,
      contains('self.backgroundColor = $name'),
      reason: 'the window does not open on $name',
    );
  });

  test('the Windows window paints the shell paper until its first paint', () {
    final String window = _read('$_winRunner/win32_window.cpp');
    expect(
      window,
      contains(
        'constexpr COLORREF kLightOpeningPaper = '
        '${_cppColour(FieldNotesColors.light.panelTop)};',
      ),
    );
    expect(
      window,
      contains(
        'constexpr COLORREF kDarkOpeningPaper = '
        '${_cppColour(FieldNotesColors.dark.panelTop)};',
      ),
    );
    expect(
      _read('$_winRunner/win32_window.h'),
      contains('bool paints_opening_paper_ = true;'),
    );

    final String erase = _cppBlock(window, 'case WM_ERASEBKGND:');
    expect(erase, contains('if (paints_opening_paper_) {'));
    expect(
      erase,
      contains('UsesDarkAppearance() ? kDarkOpeningPaper : kLightOpeningPaper'),
    );
    expect(erase, contains('FillRect(reinterpret_cast<HDC>(wparam), &area'));

    final String paint = _cppBlock(window, 'case WM_PAINT:');
    final int painted = paint.indexOf('DefWindowProc(hwnd, message');
    expect(painted, isNot(-1));
    expect(
      paint.indexOf('paints_opening_paper_ = false;'),
      greaterThan(painted),
      reason: 'the first paint erases to paper before the paper stops',
    );

    final String show = _cppBlock(window, 'bool Win32Window::Show() {');
    final int shown = show.indexOf('ShowWindow(window_handle_, SW_SHOWNORMAL)');
    expect(shown, isNot(-1));
    expect(
      show.indexOf('UpdateWindow(window_handle_);'),
      greaterThan(shown),
      reason: 'the window paints its paper as soon as it is shown',
    );
  });
}
