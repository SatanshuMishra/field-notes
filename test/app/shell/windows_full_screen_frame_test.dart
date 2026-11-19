import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _page = 'A plain page';

void _answerWindowState(WidgetTester tester) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(windowChannel, (MethodCall call) async {
        return call.method == windowStateMethod
            ? <String, Object?>{
                'maximized': false,
                'active': true,
                'fullScreen': false,
              }
            : null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, null),
  );
}

Future<void> _windowReports(
  WidgetTester tester, {
  required bool fullScreen,
}) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        windowChannelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(stateChangedMethod, <String, Object?>{
            'maximized': false,
            'active': true,
            'fullScreen': fullScreen,
          }),
        ),
        (ByteData? _) {},
      );
  await tester.pump();
}

Finder get _topResizeBand => find.byWidgetPredicate(
  (Widget widget) =>
      widget is MouseRegion && widget.cursor == SystemMouseCursors.resizeUpDown,
);

void main() {
  testWidgets(
    'Windows hides its caption buttons and resize band while the window is '
    'full screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _answerWindowState(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: fieldNotesTheme(platform: TargetPlatform.windows),
            builder: (BuildContext context, Widget? child) =>
                WindowsWindowFrame(child: child!),
            home: const Scaffold(body: Center(child: Text(_page))),
          ),
        );
        await tester.pump();
        expect(find.byType(WindowsCaptionButtons), findsOneWidget);
        expect(_topResizeBand, findsOneWidget);

        await _windowReports(tester, fullScreen: true);
        expect(find.text(_page), findsOneWidget);
        expect(find.byType(WindowsCaptionButtons), findsNothing);
        expect(find.byKey(windowsCloseButtonKey), findsNothing);
        expect(_topResizeBand, findsNothing);

        await _windowReports(tester, fullScreen: false);
        expect(find.byType(WindowsCaptionButtons), findsOneWidget);
        expect(find.byKey(windowsCloseButtonKey), findsOneWidget);
        expect(_topResizeBand, findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
