import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _message = 'Saved to Today';
const Color _cream = Color.fromRGBO(251, 243, 228, 1);

Future<void> _show(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size surface,
  double statusBar = 0,
  double gestureBar = 0,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: statusBar, bottom: gestureBar);
  tester.view.viewPadding = FakeViewPadding(top: statusBar, bottom: gestureBar);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              onTap: () => showTransientToast(context, _message),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a phone toast rises above the floating tab bar', (
    WidgetTester tester,
  ) async {
    const Size surface = Size(384, 832);
    const double gestureBar = 24;
    await _show(
      tester,
      platform: TargetPlatform.android,
      surface: surface,
      statusBar: 34,
      gestureBar: gestureBar,
    );

    final Rect toast = tester.getRect(find.byType(Toast));
    expect(toast.bottom, surface.height - gestureBar - 84);
    const double barTop = 832 - gestureBar - 8 - 64;
    expect(toast.bottom, lessThan(barTop));
    expect(toast.center.dx, surface.width / 2);

    await tester.pump(kToastLifetime);
    await tester.pump();
    expect(find.text(_message), findsNothing);
  });

  testWidgets('toasts draw on dark glass', (WidgetTester tester) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      final String reason = platform.name;
      await _show(
        tester,
        platform: platform,
        surface: platform == TargetPlatform.macOS
            ? const Size(1280, 800)
            : const Size(384, 832),
      );

      final Finder glass = find.descendant(
        of: find.byType(Toast),
        matching: find.byType(GlassSurface),
      );
      expect(glass, findsOneWidget, reason: reason);
      final GlassSurface surface = tester.widget<GlassSurface>(glass);
      expect(surface.tone, GlassTone.toast, reason: reason);
      expect(
        surface.borderRadius,
        BorderRadius.all(
          Radius.circular(platform == TargetPlatform.macOS ? 22 : 20),
        ),
        reason: reason,
      );
      expect(
        find.descendant(
          of: find.byType(Toast),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
        reason: reason,
      );
      expect(
        tester.widget<Text>(find.text(_message)).style!.color!.toARGB32(),
        _cream.toARGB32(),
        reason: reason,
      );
      expect(
        tester
            .widget<IconStickerGlyphIcon>(
              find.descendant(
                of: find.byType(Toast),
                matching: find.byType(IconStickerGlyphIcon),
              ),
            )
            .color
            .toARGB32(),
        _cream.toARGB32(),
        reason: reason,
      );
      expect(
        find.descendant(
          of: find.byType(Toast),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color?.toARGB32() ==
                    GlassColors.toast.tint.toARGB32(),
          ),
        ),
        findsOneWidget,
        reason: reason,
      );

      await tester.pump(kToastLifetime);
      await tester.pump();
      expect(find.text(_message), findsNothing, reason: reason);
    }
  });
}
