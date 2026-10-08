import 'dart:async';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/capture/core/capture_test_support.dart'
    show FakeDraftStore;
import '../../features/settings/support/fake_settings_repository.dart';
import '../support/app_shell_harness.dart';

const Size _window = Size(1280, 800);
const Key _fullWindowKey = ValueKey<String>('full-window-route');

const List<Key> _buttons = <Key>[
  windowsMinimizeButtonKey,
  windowsMaximizeButtonKey,
  windowsCloseButtonKey,
];

void _useWindow(WidgetTester tester) {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

List<MethodCall> _mockWindow(
  WidgetTester tester, {
  Map<String, Object?>? windowState,
}) {
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(windowChannel, (MethodCall call) async {
        calls.add(call);
        return call.method == windowStateMethod ? windowState : null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, null),
  );
  return calls;
}

Future<void> _sendState(
  WidgetTester tester, {
  required bool maximized,
  bool active = true,
}) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        windowChannelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(stateChangedMethod, <String, Object?>{
            'maximized': maximized,
            'active': active,
          }),
        ),
        (ByteData? _) {},
      );
  await tester.pump();
}

List<String> _sent(List<MethodCall> calls) => <String>[
  for (final MethodCall call in calls)
    if (call.method != windowStateMethod) call.method,
];

Widget _captionApp(Widget buttons) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: TargetPlatform.windows),
    home: Scaffold(
      body: Align(alignment: Alignment.topRight, child: buttons),
    ),
  );
}

WindowsCaptionGlyph _glyph(WidgetTester tester, Key button) {
  return tester.widget<WindowsCaptionGlyph>(
    find.descendant(
      of: find.byKey(button),
      matching: find.byType(WindowsCaptionGlyph),
    ),
  );
}

Color _fill(WidgetTester tester, Key button) {
  return tester
      .widget<ColoredBox>(
        find.descendant(
          of: find.byKey(button),
          matching: find.byType(ColoredBox),
        ),
      )
      .color;
}

List<Override> _appOverrides() {
  final Set<Object> replaced = <Object>{settingsRepositoryProvider};
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
    draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _appOverrides(),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
}

void main() {
  testWidgets('the caption buttons call the window channel', (
    WidgetTester tester,
  ) async {
    _useWindow(tester);
    final List<MethodCall> calls = _mockWindow(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _captionApp(WindowsCaptionButtons(channel: WindowStateChannel())),
    );
    await tester.pump();

    expect(calls.map((MethodCall call) => call.method), <String>[
      windowStateMethod,
    ]);
    final List<String> labels = <String>[
      windowsMinimizeLabel,
      windowsMaximizeLabel,
      windowsCloseLabel,
    ];
    for (int index = 0; index < _buttons.length; index++) {
      expect(
        tester.getRect(find.byKey(_buttons[index])),
        Rect.fromLTWH(
          _window.width -
              windowsCaptionButtonsWidth +
              index * windowsCaptionButtonWidth,
          0,
          46,
          42,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_buttons[index])),
        isSemantics(label: labels[index], isButton: true, hasTapAction: true),
      );
      final FocusNode focus = Focus.of(
        tester.element(
          find.descendant(
            of: find.byKey(_buttons[index]),
            matching: find.byType(WindowsCaptionGlyph),
          ),
        ),
      );
      expect(focus.canRequestFocus, isFalse);
      expect(focus.descendantsAreFocusable, isFalse);
    }
    expect(find.byType(Tooltip), findsNothing);

    for (final Key button in _buttons) {
      await tester.tap(find.byKey(button));
      await tester.pump();
    }

    expect(_sent(calls), <String>[
      minimizeMethod,
      maximizeOrRestoreMethod,
      closeMethod,
    ]);
    semantics.dispose();
  });

  testWidgets(
    'the maximise button becomes restore while the window is maximised',
    (WidgetTester tester) async {
      _useWindow(tester);
      _mockWindow(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _captionApp(WindowsCaptionButtons(channel: WindowStateChannel())),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.byKey(windowsMaximizeButtonKey)),
        isSemantics(label: windowsMaximizeLabel, isButton: true),
      );
      expect(
        _glyph(tester, windowsMaximizeButtonKey).kind,
        WindowsCaptionGlyphKind.maximize,
      );

      await _sendState(tester, maximized: true);

      expect(
        tester.getSemantics(find.byKey(windowsMaximizeButtonKey)),
        isSemantics(label: 'Restore Down', isButton: true),
      );
      expect(
        _glyph(tester, windowsMaximizeButtonKey).kind,
        WindowsCaptionGlyphKind.restore,
      );

      await _sendState(tester, maximized: false);

      expect(
        tester.getSemantics(find.byKey(windowsMaximizeButtonKey)),
        isSemantics(label: 'Maximize', isButton: true),
      );
      expect(
        _glyph(tester, windowsMaximizeButtonKey).kind,
        WindowsCaptionGlyphKind.maximize,
      );
      semantics.dispose();
    },
  );

  testWidgets('the buttons take the reported state and dim while inactive', (
    WidgetTester tester,
  ) async {
    _useWindow(tester);
    _mockWindow(
      tester,
      windowState: <String, Object?>{'maximized': true, 'active': false},
    );
    await tester.pumpWidget(
      _captionApp(WindowsCaptionButtons(channel: WindowStateChannel())),
    );
    await tester.pump();
    await tester.pump();

    final Color ink = tester
        .element(find.byType(WindowsCaptionButtons))
        .colors
        .ink;
    expect(
      _glyph(tester, windowsMaximizeButtonKey).kind,
      WindowsCaptionGlyphKind.restore,
    );
    for (final Key button in _buttons) {
      expect(
        _glyph(tester, button).color.toARGB32(),
        ink.withValues(alpha: 0.4).toARGB32(),
      );
      expect(_fill(tester, button).toARGB32(), 0x00000000);
    }

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(windowsMinimizeButtonKey)));
    await tester.pump();

    expect(
      _glyph(tester, windowsMinimizeButtonKey).color.toARGB32(),
      ink.toARGB32(),
    );
    expect(
      _fill(tester, windowsMinimizeButtonKey).toARGB32(),
      const Color(0xFF000000).withValues(alpha: 0.0373).toARGB32(),
    );

    await mouse.moveTo(tester.getCenter(find.byKey(windowsCloseButtonKey)));
    await tester.pump();

    expect(_glyph(tester, windowsCloseButtonKey).color.toARGB32(), 0xFFFFFFFF);
    expect(_fill(tester, windowsCloseButtonKey).toARGB32(), 0xFFC42B1C);
    expect(_fill(tester, windowsMinimizeButtonKey).toARGB32(), 0x00000000);

    await _sendState(tester, maximized: true, active: true);

    expect(
      _glyph(tester, windowsMinimizeButtonKey).color.toARGB32(),
      ink.toARGB32(),
    );
  });

  testWidgets(
    'caption buttons sit above a pushed full-window route on Windows only',
    (WidgetTester tester) async {
      _useWindow(tester);
      final List<MethodCall> calls = _mockWindow(tester);

      await _onPlatform(TargetPlatform.windows, () async {
        await _pumpApp(tester);
        final NavigatorState navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        unawaited(
          navigator.push<void>(
            PageRouteBuilder<void>(
              pageBuilder:
                  (
                    BuildContext context,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                  ) => const ColoredBox(
                    key: _fullWindowKey,
                    color: Palette.mediaGround,
                    child: SizedBox.expand(),
                  ),
            ),
          ),
        );
        await _settle(tester);

        expect(
          tester.getRect(find.byKey(_fullWindowKey)),
          Offset.zero & _window,
        );
        Rect? group;
        for (final Key button in _buttons) {
          expect(find.byKey(button).hitTestable(), findsOneWidget);
          final Rect rect = tester.getRect(find.byKey(button));
          group = group?.expandToInclude(rect) ?? rect;
        }
        expect(
          group,
          Rect.fromLTWH(_window.width - windowsCaptionButtonsWidth, 0, 138, 42),
        );

        await tester.tap(find.byKey(windowsMinimizeButtonKey));
        await tester.pump();

        expect(_sent(calls), contains(minimizeMethod));
      });

      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpApp(tester);

        expect(find.byType(WindowsWindowFrame), findsNothing);
        expect(find.byType(WindowsCaptionButtons), findsNothing);
        for (final Key button in _buttons) {
          expect(find.byKey(button), findsNothing);
        }
      });
    },
  );

  testWidgets('dragging the top edge starts a top resize on Windows', (
    WidgetTester tester,
  ) async {
    _useWindow(tester);
    final List<MethodCall> calls = _mockWindow(tester);

    await _onPlatform(TargetPlatform.windows, () async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.windows),
          builder: (BuildContext context, Widget? child) =>
              WindowsWindowFrame(child: child!),
          home: const ColoredBox(
            color: Palette.mediaGround,
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      await tester.dragFrom(const Offset(100, 1), const Offset(0, 40));
      await tester.pump();

      final List<MethodCall> resizes = calls
          .where((MethodCall call) => call.method == startResizeMethod)
          .toList();
      expect(resizes.map((MethodCall call) => call.arguments), <Object?>[
        'top',
      ]);
      expect(_sent(calls), <String>[startResizeMethod]);

      await _sendState(tester, maximized: true);
      await tester.dragFrom(const Offset(100, 1), const Offset(0, 40));
      await tester.pump();

      expect(_sent(calls), <String>[startResizeMethod]);

      await _sendState(tester, maximized: false);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
