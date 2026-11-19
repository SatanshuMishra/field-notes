import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/design/tokens/field_notes_colors.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/opening/opening_cover.dart';
import 'package:field_notes/features/opening/opening_frame.dart';
import 'package:field_notes/state/settings_providers.dart';

import 'support/app_shell_harness.dart';

const MethodChannel _uploads = MethodChannel('field_notes/background_uploads');
const Size _view = Size(440, 900);

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

class _HiddenGate extends OnboardingGate {
  @override
  Future<OnboardingVisibility> build() async => OnboardingVisibility.hidden;
}

Future<void> _pumpApp(WidgetTester tester, FieldNotesApp app) async {
  tester.view.physicalSize = _view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...shellOverrides(),
        onboardingGateProvider.overrideWith(_HiddenGate.new),
      ],
      child: app,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<Color> _firstFrameBeforeSettings(
  WidgetTester tester,
  Brightness system,
) async {
  tester.platformDispatcher.platformBrightnessTestValue = system;
  final StreamController<AppSettings> settings =
      StreamController<AppSettings>();
  addTearDown(settings.close);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        ...shellOverrides(),
        appSettingsProvider.overrideWith((Ref ref) => settings.stream),
      ],
      child: const FieldNotesApp(),
    ),
  );
  final Finder fullPaper = find.byWidgetPredicate(
    (Widget widget) => widget is ColoredBox,
  );
  final Iterable<ColoredBox> boxes = tester
      .widgetList<ColoredBox>(fullPaper)
      .where((ColoredBox box) => tester.getSize(find.byWidget(box)) == _view);
  expect(boxes, hasLength(1));
  expect(find.byType(MaterialApp), findsNothing);
  final Color paper = boxes.single.color;
  await tester.pumpWidget(const SizedBox.shrink());
  return paper;
}

void main() {
  testWidgets('the app plays the opening over the shell when asked', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, const FieldNotesApp(playsOpening: true));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OpeningFrame), findsOneWidget);
    final Stack layers = tester.widget<Stack>(
      find
          .descendant(
            of: find.byType(OpeningCover),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(layers.children, hasLength(2));
    expect(
      find.descendant(
        of: find.byWidget(layers.children.first),
        matching: find.byType(AppShell),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byWidget(layers.children.last),
        matching: find.byType(OpeningFrame),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the app plays no opening unless asked', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, const FieldNotesApp());

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OpeningFrame), findsNothing);
    expect(find.byKey(openingPaperKey), findsNothing);
  });

  test('the device entry point asks for the opening', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      _messenger.setMockMethodCallHandler(_uploads, null);
    });
    _messenger.setMockMethodCallHandler(
      _uploads,
      (MethodCall call) async => true,
    );

    expect((await fieldNotesAppForThisDevice()).playsOpening, isTrue);
  });

  testWidgets('before settings load the first frame is the paper of the '
      'system brightness', (WidgetTester tester) async {
    tester.view.physicalSize = _view;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    expect(
      await _firstFrameBeforeSettings(tester, Brightness.light),
      FieldNotesColors.light.panelTop,
    );
    expect(
      await _firstFrameBeforeSettings(tester, Brightness.dark),
      FieldNotesColors.dark.panelTop,
    );
  });
}
