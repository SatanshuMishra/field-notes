import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:field_notes/features/today/today_layout.dart';

const String _runner = 'windows/runner';

const Map<String, String> _swiftNames = <String, String>{
  'kSidebarWidth': 'sidebarWidth',
  'kTodayRailWidth': 'todayRailWidth',
  'kSeamWidth': 'seamWidth',
  'kTodayPanePadding': 'todayPanePadding',
  'kEntryCardPadding': 'entryCardPadding',
  'kNoteBodyFontSize': 'noteBodyFontSize',
  'kMinimumReadingColumnEm': 'minimumReadingColumnEm',
  'kMinimumContentHeight': 'minimumContentHeight',
  'kOpeningWindowWidth': 'openingWindowWidth',
  'kOpeningWindowHeight': 'openingWindowHeight',
  'kTitleBarHeight': 'titleBarHeight',
};

const List<String> _windowMethods = <String>[
  startDragMethod,
  titlebarDoubleClickMethod,
  setAppearanceMethod,
  minimizeMethod,
  maximizeOrRestoreMethod,
  closeMethod,
  startResizeMethod,
  windowStateMethod,
  stateChangedMethod,
  windowHandleMethod,
];

String _source(String name) {
  final File file = File('$_runner/$name');
  expect(file.existsSync(), isTrue, reason: '$_runner/$name is missing');
  return file.readAsStringSync();
}

String _swift() =>
    File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();

double _swiftConstant(String swift, String name) {
  final RegExpMatch? match = RegExp(
    'private let ${RegExp.escape(name)}: CGFloat = ([0-9.]+)\n',
  ).firstMatch(swift);
  expect(match, isNotNull, reason: '$name must be a literal CGFloat constant');
  return double.parse(match!.group(1)!);
}

double _cppConstant(String header, String name) {
  final RegExpMatch? match = RegExp(
    'constexpr double ${RegExp.escape(name)} = ([0-9.]+);',
  ).firstMatch(header);
  expect(match, isNotNull, reason: '$name must be a literal constexpr double');
  return double.parse(match!.group(1)!);
}

String _swiftExpression(String swift, String name) {
  final RegExpMatch? match = RegExp(
    'private let ${RegExp.escape(name)}: CGFloat =([\\s\\S]*?)\nprivate let',
  ).firstMatch(swift);
  expect(match, isNotNull, reason: '$name must be a Swift expression');
  return match!.group(1)!;
}

String _cppExpression(String header, String name) {
  final RegExpMatch? match = RegExp(
    'constexpr double ${RegExp.escape(name)} =([\\s\\S]*?);',
  ).firstMatch(header);
  expect(match, isNotNull, reason: '$name must be a constexpr expression');
  return match!.group(1)!;
}

String _compact(String expression) => expression.replaceAll(RegExp(r'\s+'), '');

String _inSwiftNames(String cppExpression) => _compact(cppExpression)
    .replaceAllMapped(
      RegExp(r'\bk([A-Z])'),
      (Match match) => match.group(1)!.toLowerCase(),
    );

double _sum(String expression, double Function(String name) value) =>
    _compact(expression)
        .split('+')
        .map(
          (String term) => term
              .split('*')
              .map(value)
              .reduce((double product, double factor) => product * factor),
        )
        .reduce((double total, double term) => total + term);

String _caseBlock(String source, String message) {
  final int start = source.indexOf('case $message:');
  expect(start, isNot(-1), reason: 'the runner must handle $message');
  final int end = source.indexOf('\n    case ', start + 1);
  return source.substring(start, end == -1 ? source.length : end);
}

void main() {
  group('Windows window', () {
    test('the Windows window opens at the macOS opening size and minimum', () {
      final String header = _source('window_geometry.h');
      final String swift = _swift();

      expect(_cppConstant(header, 'kOpeningWindowWidth'), 1200);
      expect(_cppConstant(header, 'kOpeningWindowHeight'), 800);
      for (final MapEntry<String, String> name in _swiftNames.entries) {
        expect(
          _cppConstant(header, name.key),
          _swiftConstant(swift, name.value),
          reason: '${name.key} must equal the Swift ${name.value}',
        );
      }
      expect(_cppConstant(header, 'kTodayRailWidth'), todayRailWidth);
      expect(
        _cppConstant(header, 'kNoteBodyFontSize'),
        TypographyTokens.noteBody.fontSize,
      );
      expect(_cppConstant(header, 'kTitleBarHeight'), shellTitleBarHeight);

      final String minimumWidth = _cppExpression(
        header,
        'kMinimumContentWidth',
      );
      expect(
        minimumWidth,
        contains('kMinimumReadingColumnEm * kNoteBodyFontSize'),
        reason: 'the minimum width must be derived from the reading column',
      );
      expect(
        _inSwiftNames(minimumWidth),
        _compact(_swiftExpression(swift, 'minimumContentWidth')),
      );
      expect(
        _sum(minimumWidth, (String name) => _cppConstant(header, name)),
        closeTo(216 + 2 * 1 + 2 * 24 + 2 * 15 + 19.4 * 16 + 266, 1e-9),
      );

      final String main = _source('main.cpp');
      expect(main, contains('::GetCursorPos(&cursor)'));
      expect(
        main,
        contains('::MonitorFromPoint(cursor, MONITOR_DEFAULTTOPRIMARY)'),
      );
      expect(main, contains('info.rcWork'));
      expect(main, contains('FlutterDesktopGetDpiForMonitor(monitor)'));
      expect(
        main,
        matches(
          RegExp(
            r'WindowSizeForContent\(\s*kOpeningWindowWidth,\s*'
            r'kOpeningWindowHeight,\s*dpi\)',
          ),
        ),
      );
      expect(
        main,
        matches(
          RegExp(
            r'WindowSizeForContent\(\s*kMinimumContentWidth,\s*'
            r'kMinimumContentHeight,\s*dpi\)',
          ),
        ),
      );
      expect(
        main,
        contains('std::max(std::min(opening.cx, work_width), minimum.cx)'),
      );
      expect(
        main,
        contains('std::max(std::min(opening.cy, work_height), minimum.cy)'),
      );
      expect(main, contains('work.left + (work_width - width) / 2'));
      expect(main, contains('work.top + (work_height - height) / 2'));

      expect(
        header,
        matches(
          RegExp(
            r'PhysicalLength\(width, frame_dpi\) \+ frame\.right - '
            r'frame\.left,\s*PhysicalLength\(height, frame_dpi\) \+ '
            r'frame\.bottom\}',
          ),
        ),
        reason: 'the frame adds its sides and bottom, never a caption',
      );

      final String window = _source('win32_window.cpp');
      expect(
        window,
        matches(
          RegExp(
            r'WS_OVERLAPPEDWINDOW,\s*origin\.x, origin\.y, '
            r'size\.width, size\.height,',
          ),
        ),
        reason: 'the physical origin and size are used unscaled',
      );
      expect(window, isNot(contains('Scale(')));
    });

    test('the Windows window answers every window channel method', () {
      final String chrome = File('lib/app/shell/window_chrome.dart')
          .readAsStringSync();
      final Set<String> declared = RegExp(r"const String \w+Method = '(\w+)';")
          .allMatches(chrome)
          .map((RegExpMatch match) => match.group(1)!)
          .toSet();
      expect(declared, _windowMethods.toSet());

      final String channel = _source('window_channel.cpp');
      expect(channel, contains('"$windowChannelName"'));
      for (final String method in declared) {
        expect(
          channel,
          contains('"$method"'),
          reason: 'the runner must name $method',
        );
      }
      expect(channel, contains('flutter::StandardMethodCodec::GetInstance()'));
      expect(channel, contains('result->NotImplemented();'));

      expect(channel, contains('(::GetKeyState(VK_LBUTTON) & 0x8000) != 0'));
      expect(channel, contains('::ReleaseCapture();'));
      expect(
        channel,
        contains('::SendMessage(window, WM_SYSCOMMAND, command, 0);'),
      );
      expect(
        channel,
        contains('RunSystemLoop(window, SC_MOVE | HTCAPTION);'),
        reason: 'a caption drag runs the system move loop, so Aero Snap works',
      );
      expect(channel, contains('RunSystemLoop(window, SC_SIZE | WMSZ_TOP);'));
      expect(channel, contains('kTopEdge[] = "top"'));
      expect(
        channel,
        contains('IsMaximized(window) ? SW_RESTORE : SW_MAXIMIZE'),
      );
      expect(channel, contains('::IsZoomed(window) != FALSE'));
      expect(channel, contains('::ShowWindow(window, SW_MINIMIZE);'));
      expect(channel, contains('::PostMessage(window, WM_CLOSE, 0, 0)'));
      expect(channel, contains('::GetForegroundWindow() == window'));
      expect(channel, contains('flutter::EncodableValue("maximized")'));
      expect(channel, contains('flutter::EncodableValue("active")'));
      expect(
        channel,
        contains('static_cast<int64_t>(reinterpret_cast<intptr_t>(window))'),
        reason: 'the export dialog needs the top-level window as its owner',
      );
      expect(
        channel,
        matches(RegExp(r'InvokeMethod\(\s*kStateChangedMethod,')),
      );

      final String flutterWindow = _source('flutter_window.cpp');
      expect(
        flutterWindow,
        contains('std::make_unique<WindowChannel>(messenger, this)'),
      );
      expect(
        flutterWindow,
        contains('flutter_controller_->engine()->messenger()'),
      );
      expect(_caseBlock(flutterWindow, 'WM_SIZE'), contains('OnSize()'));
      expect(
        _caseBlock(flutterWindow, 'WM_ACTIVATE'),
        contains('OnActivate(LOWORD(wparam) != WA_INACTIVE)'),
      );

      final String cmake = _source('CMakeLists.txt');
      expect(cmake, contains('"window_channel.cpp"'));
      expect(cmake, contains('"system_channels.cpp"'));
    });

    test(
      'the Windows window draws its own title bar and keeps native resizing',
      () {
        final String window = _source('win32_window.cpp');
        expect(window, contains('WS_OVERLAPPEDWINDOW'));

        final String calcSize = _caseBlock(window, 'WM_NCCALCSIZE');
        expect(calcSize, contains('const LONG top = params->rgrc[0].top;'));
        expect(
          calcSize,
          contains('DefWindowProc(hwnd, message, wparam, lparam);'),
        );
        expect(calcSize, contains('params->rgrc[0].top = top;'));
        expect(calcSize, contains('if (IsZoomed(hwnd))'));
        expect(calcSize, contains('MaximizedFrameHeight(hwnd)'));
        expect(calcSize, contains('return 0;'));
        expect(window, contains('GetSystemMetricsForDpi(SM_CYFRAME, dpi)'));
        expect(
          window,
          contains('GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi)'),
        );

        final String minMax = _caseBlock(window, 'WM_GETMINMAXINFO');
        expect(
          minMax,
          matches(
            RegExp(
              r'WindowSizeForContent\(\s*kMinimumContentWidth, '
              r'kMinimumContentHeight, GetDpiForWindow\(hwnd\)\)',
            ),
          ),
        );
        expect(minMax, contains('info->ptMinTrackSize.x = minimum.cx;'));
        expect(minMax, contains('info->ptMinTrackSize.y = minimum.cy;'));
        expect(
          _source('window_geometry.h'),
          contains(
            'AdjustWindowRectExForDpi(&frame, WS_OVERLAPPEDWINDOW, FALSE, 0,',
          ),
        );

        expect(window, contains('const MARGINS shadow{0, 0, 1, 0};'));
        expect(
          window,
          contains('DwmExtendFrameIntoClientArea(window, &shadow)'),
        );
        expect(
          window,
          matches(
            RegExp(
              r'SWP_FRAMECHANGED \| SWP_NOMOVE \| SWP_NOSIZE \|\s*'
              r'SWP_NOZORDER',
            ),
          ),
        );
        expect(window, contains('case WM_DPICHANGED:'));
        expect(window, contains('case WM_SIZE:'));
        expect(window, contains('case WM_ACTIVATE:'));

        expect(window, contains('DWMWA_USE_IMMERSIVE_DARK_MODE'));
        expect(window, contains('L"AppsUseLightTheme"'));
        expect(
          _caseBlock(window, 'WM_DWMCOLORIZATIONCOLORCHANGED'),
          contains('if (appearance_ == Appearance::kSystem)'),
        );
        final String channel = _source('window_channel.cpp');
        expect(channel, contains('kDarkAppearance[] = "dark"'));
        expect(channel, contains('kLightAppearance[] = "light"'));
        expect(
          channel,
          contains('window_->SetAppearance(AppearanceNamed(call.arguments()))'),
        );

        expect(
          _source('main.cpp'),
          matches(RegExp(r'window\.Create\(L"Field Notes", ')),
        );
      },
    );

    test('the Windows build names itself Field Notes', () {
      final String resource = _source('Runner.rc');
      final RegExpMatch? copyright =
          RegExp(r'^PRODUCT_COPYRIGHT = (.+)$', multiLine: true).firstMatch(
            File('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync(),
          );
      expect(copyright, isNotNull);

      expect(resource, startsWith('#pragma code_page(65001)\n'));
      expect(resource, contains('VALUE "ProductName", "Field Notes" "\\0"'));
      expect(
        resource,
        contains('VALUE "FileDescription", "Field Notes" "\\0"'),
      );
      expect(
        resource,
        contains('VALUE "CompanyName", "dev.satanshumishra" "\\0"'),
      );
      expect(resource, contains('VALUE "InternalName", "field_notes" "\\0"'));
      expect(
        resource,
        contains('VALUE "OriginalFilename", "field_notes.exe" "\\0"'),
      );
      expect(
        resource,
        contains('VALUE "LegalCopyright", "${copyright!.group(1)}" "\\0"'),
      );
      expect(resource, contains('#define VERSION_AS_STRING FLUTTER_VERSION'));
      expect(
        resource,
        contains(
          'IDI_APP_ICON            ICON                    '
          '"resources\\\\app_icon.ico"',
        ),
      );
      expect(
        File('windows/CMakeLists.txt').readAsStringSync(),
        contains('set(BINARY_NAME "field_notes")'),
      );

      expect(
        _source('system_channels.h'),
        contains('kAppUserModelId[] = L"$windowsAppUserModelId";'),
      );
      final String main = _source('main.cpp');
      expect(main, contains('#include <shobjidl.h>'));
      expect(main, contains('#include "system_channels.h"'));
      final int identity = main.indexOf(
        '::SetCurrentProcessExplicitAppUserModelID(kAppUserModelId)',
      );
      expect(identity, isNot(-1));
      expect(
        identity,
        lessThan(main.indexOf('window.Create(')),
        reason: 'the identity is set before the window exists',
      );
    });

    test('the audio plugin builds with the current Visual Studio', () {
      final String build = File('windows/CMakeLists.txt').readAsStringSync();
      final int plugins = build.indexOf(
        'include(flutter/generated_plugins.cmake)',
      );
      final int silence = build.indexOf(
        'target_compile_definitions(just_audio_windows_plugin PRIVATE\n'
        '    _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)',
      );
      expect(plugins, isNot(-1));
      expect(silence, greaterThan(plugins));
      expect(build, contains('if(TARGET just_audio_windows_plugin)'));
    });
  });
}
