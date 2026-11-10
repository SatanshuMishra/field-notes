import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

const Key _keepGoingKey = ValueKey<String>('keep-going');
const Key _letGoKey = ValueKey<String>('let-go');
const Key _toggleKey = ValueKey<String>('toggle-panel');

class _PanelHost extends StatefulWidget {
  const _PanelHost({
    required this.compact,
    required this.onKeepGoing,
    required this.onLetGo,
  });

  final bool compact;
  final VoidCallback onKeepGoing;
  final VoidCallback onLetGo;

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextButton(
          key: _toggleKey,
          autofocus: true,
          onPressed: () => setState(() => _open = true),
          child: const Text('Leave'),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.all(16),
            child: LetGoPanel(
              compact: widget.compact,
              keepGoingKey: _keepGoingKey,
              letGoKey: _letGoKey,
              onKeepGoing: widget.onKeepGoing,
              onLetGo: widget.onLetGo,
            ),
          ),
      ],
    );
  }
}

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  required bool compact,
  required VoidCallback onKeepGoing,
  required VoidCallback onLetGo,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = platform == TargetPlatform.android
      ? const Size(360, 740)
      : const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        backgroundColor: recorderStageColor,
        body: _PanelHost(
          compact: compact,
          onKeepGoing: onKeepGoing,
          onLetGo: onLetGo,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(_toggleKey));
  await tester.pump();
  await tester.pump();
}

bool _hasFocusWithin(WidgetTester tester, Key key) {
  final Element target = tester.element(find.byKey(key));
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) {
    return false;
  }
  bool inside = identical(focused, target);
  focused.visitAncestorElements((Element ancestor) {
    if (identical(ancestor, target)) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

void main() {
  testWidgets(
    'the let-go panel shows its copy and calls Keep going and Let it go',
    (WidgetTester tester) async {
      int keepGoing = 0;
      int letGo = 0;
      await _open(
        tester,
        platform: TargetPlatform.macOS,
        compact: false,
        onKeepGoing: () => keepGoing++,
        onLetGo: () => letGo++,
      );

      expect(find.text('Let this one go?'), findsOneWidget);
      expect(
        find.text("Nothing will be saved. That's okay too."),
        findsOneWidget,
      );
      expect(find.text('Keep going'), findsOneWidget);
      expect(find.text('Let it go'), findsOneWidget);
      expect(_hasFocusWithin(tester, _keepGoingKey), isTrue);

      await tester.tap(find.byKey(_keepGoingKey));
      await tester.pump();
      expect(keepGoing, 1);
      expect(letGo, 0);

      await tester.tap(find.byKey(_letGoKey));
      await tester.pump();
      expect(keepGoing, 1);
      expect(letGo, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(keepGoing, 2);
      expect(letGo, 1);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('on the phone the action stacks above the safe button', (
    WidgetTester tester,
  ) async {
    int keepGoing = 0;
    await _open(
      tester,
      platform: TargetPlatform.android,
      compact: true,
      onKeepGoing: () => keepGoing++,
      onLetGo: () {},
    );

    final Rect message = tester.getRect(
      find.text("Nothing will be saved. That's okay too."),
    );
    final Rect keep = tester.getRect(find.byKey(_keepGoingKey));
    final Rect letGo = tester.getRect(find.byKey(_letGoKey));
    expect(letGo.top, greaterThanOrEqualTo(message.bottom));
    expect(keep.top, greaterThanOrEqualTo(letGo.bottom));
    expect(keep.height, greaterThanOrEqualTo(48));
    expect(letGo.height, greaterThanOrEqualTo(48));
    expect(keep.width, closeTo(letGo.width, 1));
    expect(_hasFocusWithin(tester, _keepGoingKey), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(keepGoing, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final bool compact in <bool>[false, true]) {
    testWidgets('desktop button order follows the platform, compact $compact', (
      WidgetTester tester,
    ) async {
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        await _open(
          tester,
          platform: platform,
          compact: compact,
          onKeepGoing: () {},
          onLetGo: () {},
        );

        final double keep = tester.getCenter(find.byKey(_keepGoingKey)).dx;
        final double letGo = tester.getCenter(find.byKey(_letGoKey)).dx;
        expect(
          keep < letGo,
          platform == TargetPlatform.macOS,
          reason: '$platform',
        );
        expect(_hasFocusWithin(tester, _keepGoingKey), isTrue);
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('the panel uses the shared safe and action buttons', (
    WidgetTester tester,
  ) async {
    await _open(
      tester,
      platform: TargetPlatform.macOS,
      compact: false,
      onKeepGoing: () {},
      onLetGo: () {},
    );

    expect(
      tester.widget<StickerButton>(find.byKey(_keepGoingKey)).variant,
      StickerButtonVariant.stageSoft,
    );
    expect(
      tester.widget<StickerButton>(find.byKey(_letGoKey)).variant,
      StickerButtonVariant.danger,
    );
    expect(find.byType(ConfirmChoiceButton), findsNWidgets(2));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('tapping outside keeps going and reaches nothing underneath', (
    WidgetTester tester,
  ) async {
    int keepGoing = 0;
    int letGo = 0;
    int underneath = 0;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          backgroundColor: recorderStageColor,
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton(
                onPressed: () => underneath++,
                child: const Text('Underneath'),
              ),
              LetGoPanel(
                compact: false,
                keepGoingKey: _keepGoingKey,
                letGoKey: _letGoKey,
                onKeepGoing: () => keepGoing++,
                onLetGo: () => letGo++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Underneath'));
    await tester.pump();
    expect(keepGoing, 1);
    expect(underneath, 0);

    await tester.tap(find.byKey(_letGoKey));
    await tester.pump();
    expect(keepGoing, 1);
    expect(letGo, 1);
  });

  testWidgets('the panel is a semantics scope named Let this one go?', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _open(
      tester,
      platform: TargetPlatform.macOS,
      compact: false,
      onKeepGoing: () {},
      onLetGo: () {},
    );

    final SemanticsNode scope = tester.getSemantics(find.byType(LetGoPanel));
    expect(
      scope,
      isSemantics(
        label: 'Let this one go?',
        scopesRoute: true,
        namesRoute: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(_keepGoingKey)),
      isSemantics(label: 'Keep going', isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(_letGoKey)),
      isSemantics(label: 'Let it go', isButton: true),
    );

    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
