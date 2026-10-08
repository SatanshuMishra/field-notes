import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/features/capture/immersive/recorder_glass_button.dart';

const Key _buttonKey = ValueKey<String>('glass-circle');
const String _label = 'Close';

void _phoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  addTearDown(tester.view.reset);
}

Widget _host(Widget button) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(
      platform: TargetPlatform.android,
      brightness: Brightness.dark,
    ),
    home: Scaffold(body: Center(child: button)),
  );
}

Finder _within(Type type) =>
    find.descendant(of: find.byKey(_buttonKey), matching: find.byType(type));

void main() {
  testWidgets('a media glass circle is a labelled 48-point button', (
    WidgetTester tester,
  ) async {
    _phoneSurface(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    int presses = 0;

    await tester.pumpWidget(
      _host(
        GlassCircleButton(
          key: _buttonKey,
          tone: GlassTone.media,
          face: 48,
          label: _label,
          glyph: const SizedBox.square(dimension: 14),
          onPressed: () => presses += 1,
        ),
      ),
    );

    expect(tester.getSize(find.byKey(_buttonKey)), const Size.square(48));
    expect(
      tester.widget<GlassSurface>(_within(GlassSurface)).tone,
      GlassTone.media,
    );
    expect(tester.getSize(_within(GlassSurface)), const Size.square(48));
    expect(tester.widget<Opacity>(_within(Opacity).first).opacity, 1);
    expect(_within(FocusRing), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(_buttonKey)),
      isSemantics(
        label: _label,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byKey(_buttonKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(presses, 1);

    await tester.pumpWidget(
      _host(
        const GlassCircleButton(
          key: _buttonKey,
          tone: GlassTone.media,
          face: 48,
          label: _label,
          glyph: SizedBox.square(dimension: 14),
          onPressed: null,
        ),
      ),
    );

    expect(tester.widget<Opacity>(_within(Opacity).first).opacity, 0.5);
    expect(
      tester.getSemantics(find.byKey(_buttonKey)),
      isSemantics(
        label: _label,
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    int leaves = 0;
    await tester.pumpWidget(
      _host(
        RecorderGlassButton(
          key: _buttonKey,
          label: 'Leave',
          glyph: const SizedBox.square(dimension: 15),
          onPressed: () => leaves += 1,
        ),
      ),
    );

    final Rect target = tester.getRect(find.byKey(_buttonKey));
    expect(target.size, const Size.square(48));
    expect(
      tester.widget<GlassSurface>(_within(GlassSurface)).tone,
      GlassTone.media,
    );
    expect(
      tester.getSize(_within(GlassSurface)),
      const Size.square(recorderGlassButtonFace),
    );
    expect(recorderGlassButtonFace, 40);
    expect(
      tester.getSemantics(find.byKey(_buttonKey)),
      isSemantics(label: 'Leave', isButton: true, isEnabled: true),
    );

    await tester.tapAt(target.topLeft + const Offset(2, 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(leaves, 1);

    semantics.dispose();
  });

  testWidgets('a glass circle takes keyboard focus and presses on Enter', (
    WidgetTester tester,
  ) async {
    _phoneSurface(tester);
    int presses = 0;

    await tester.pumpWidget(
      _host(
        GlassCircleButton(
          key: _buttonKey,
          tone: GlassTone.media,
          face: 48,
          label: _label,
          glyph: const SizedBox.square(dimension: 14),
          onPressed: () => presses += 1,
        ),
      ),
    );
    expect(_within(GlassSurface), findsOneWidget);
    expect(find.byKey(focusRingKey), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(_buttonKey),
        matching: find.byKey(focusRingKey),
      ),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 1);
  });
}
