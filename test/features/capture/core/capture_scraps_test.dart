import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/chooser/capture_routes_provider.dart';
import 'package:field_notes/features/capture/chooser/capture_scraps.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _desktop = Size(1280, 900);
const Size _phone = Size(360, 780);
const Set<EntryType> _everyType = <EntryType>{
  EntryType.text,
  EntryType.voice,
  EntryType.video,
};
const Map<EntryType, double> _restingTilts = <EntryType, double>{
  EntryType.text: -3.2,
  EntryType.voice: 2.6,
  EntryType.video: -1.5,
};
const double _angleTolerance = 0.001;

class _Pose {
  const _Pose(this.degrees, this.rise);

  final double degrees;
  final double rise;
}

_Pose _poseOf(WidgetTester tester, EntryType type) {
  final RenderBox slot = tester.renderObject<RenderBox>(
    find.byKey(captureScrapKey(type)),
  );
  final RenderBox paper = tester.renderObject<RenderBox>(
    find.byKey(captureScrapPaperKey(type)),
  );
  final Matrix4 transform = paper.getTransformTo(slot);
  final Offset paperCentre = MatrixUtils.transformPoint(
    transform,
    paper.size.center(Offset.zero),
  );
  return _Pose(
    math.atan2(transform.entry(1, 0), transform.entry(0, 0)) * 180 / math.pi,
    slot.size.center(Offset.zero).dy - paperCentre.dy,
  );
}

Future<void> _settleDeal(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump();
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  Set<EntryType> available = _everyType,
  ValueChanged<EntryType>? onSelected,
  ShellLayout layout = ShellLayout.sidebar,
  TargetPlatform platform = TargetPlatform.macOS,
  Brightness brightness = Brightness.light,
  Size size = _desktop,
  double textScale = 1,
  bool disableAnimations = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform, brightness: brightness),
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Align(
              alignment: layout == ShellLayout.bottomBar
                  ? Alignment.bottomCenter
                  : Alignment.center,
              child: CaptureChooserSheet(
                availableTypes: available,
                onOptionSelected: onSelected ?? (EntryType _) {},
                layout: layout,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await _settleDeal(tester);
  }
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Future<void> _hover(
  WidgetTester tester,
  TestGesture mouse,
  EntryType type,
) async {
  await mouse.moveTo(tester.getCenter(find.byKey(captureScrapKey(type))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

BoxDecoration _paperOf(WidgetTester tester, EntryType type) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byKey(captureScrapPaperKey(type)),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

Color? _borderOf(BoxDecoration decoration) =>
    (decoration.border as Border?)?.top.color;

Color? _colourOfText(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

class _OpenCapture extends ConsumerWidget {
  const _OpenCapture({required this.onResult});

  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        onResult(await openCapture(context, ref, date: '2026-11-09'));
      },
      child: const Text('open'),
    );
  }
}

CaptureRouteRegistry _routesRecording(List<EntryType> opened) =>
    EntryType.values.fold(
      CaptureRouteRegistry.empty,
      (CaptureRouteRegistry registry, EntryType type) => registry.withRoute(
        CaptureRoute(
          type: type,
          open: (BuildContext context, String date) async {
            opened.add(type);
            return 'entry-${type.id}';
          },
        ),
      ),
    );

Widget _openerApp(
  CaptureRouteRegistry routes,
  ValueChanged<String?> onResult,
  TargetPlatform platform,
) {
  return ProviderScope(
    overrides: <Override>[captureRoutesProvider.overrideWithValue(routes)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: Center(child: _OpenCapture(onResult: onResult)),
      ),
    ),
  );
}

void main() {
  for (final CaptureOption option in captureOptions) {
    testWidgets('tapping the ${option.label} scrap opens its route', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _desktop;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final List<EntryType> opened = <EntryType>[];
      String? result;
      await tester.pumpWidget(
        _openerApp(
          _routesRecording(opened),
          (String? id) => result = id,
          TargetPlatform.macOS,
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(captureScrapKey(option.type)));
      await tester.pumpAndSettle();

      expect(opened, <EntryType>[option.type]);
      expect(result, 'entry-${option.type.id}');
    });
  }

  testWidgets('every scrap keeps the copy of its capture option', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('Capture a moment'), findsOneWidget);
    expect(find.text(captureChooserSubtitle), findsOneWidget);
    for (final CaptureOption option in captureOptions) {
      expect(find.text(option.label), findsOneWidget);
      expect(find.text(option.description), findsOneWidget);
    }
  });

  testWidgets('each scrap reads as one button naming its copy', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpSheet(tester);

    for (final CaptureOption option in captureOptions) {
      expect(
        tester.getSemantics(find.byKey(captureScrapKey(option.type))),
        isSemantics(
          label: '${option.label}\n${option.description}',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('at rest each scrap sits at its own slight tilt on a taped '
      'page', (WidgetTester tester) async {
    await _pumpSheet(tester);

    for (final MapEntry<EntryType, double> rest in _restingTilts.entries) {
      final _Pose pose = _poseOf(tester, rest.key);
      expect(pose.degrees, closeTo(rest.value, _angleTolerance));
      expect(pose.rise, closeTo(0, _angleTolerance));
    }
    expect(find.byKey(captureChooserTapeKey), findsOneWidget);
    expect(
      tester.widget<StickerCard>(find.byType(StickerCard)).rotationDegrees,
      -0.6,
    );
  });

  testWidgets('hovering a scrap straightens and lifts it and brings it on '
      'top', (WidgetTester tester) async {
    await _pumpSheet(tester);
    final TestGesture mouse = await _mouse(tester);

    await _hover(tester, mouse, EntryType.voice);

    final _Pose hovered = _poseOf(tester, EntryType.voice);
    expect(hovered.degrees, closeTo(0, _angleTolerance));
    expect(hovered.rise, closeTo(captureScrapLift, _angleTolerance));
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    expect(
      tester.widget<Stack>(find.byKey(captureScrapPileKey)).children.last.key,
      const ValueKey<EntryType>(EntryType.voice),
    );
    expect(
      _poseOf(tester, EntryType.text).degrees,
      closeTo(_restingTilts[EntryType.text]!, _angleTolerance),
    );

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final _Pose released = _poseOf(tester, EntryType.voice);
    expect(
      released.degrees,
      closeTo(_restingTilts[EntryType.voice]!, _angleTolerance),
    );
    expect(released.rise, closeTo(0, _angleTolerance));
    expect(
      tester.widget<Stack>(find.byKey(captureScrapPileKey)).children.last.key,
      const ValueKey<EntryType>(EntryType.video),
    );
  });

  testWidgets('keyboard focus straightens and lifts a scrap and shows the '
      'one ring', (WidgetTester tester) async {
    await _pumpSheet(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final _Pose focused = _poseOf(tester, EntryType.text);
    expect(focused.degrees, closeTo(0, _angleTolerance));
    expect(focused.rise, closeTo(captureScrapLift, _angleTolerance));
    expect(
      find.descendant(
        of: find.byKey(captureScrapKey(EntryType.text)),
        matching: find.byKey(focusRingKey),
      ),
      findsOneWidget,
    );
    expect(
      _poseOf(tester, EntryType.voice).degrees,
      closeTo(_restingTilts[EntryType.voice]!, _angleTolerance),
    );
  });

  testWidgets('Tab walks the scraps left to right and Enter selects one', (
    WidgetTester tester,
  ) async {
    final List<EntryType> selected = <EntryType>[];
    await _pumpSheet(tester, onSelected: selected.add);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, <EntryType>[EntryType.voice]);
  });

  testWidgets('on Android the chooser opens as a bottom sheet with no tape', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _openerApp(
        _routesRecording(<EntryType>[]),
        (String? _) {},
        TargetPlatform.android,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(CaptureChooserSheet),
        matching: find.byType(PhoneSheet),
      ),
      findsOneWidget,
    );
    expect(find.byType(StickerCard), findsNothing);
    expect(find.byKey(captureChooserTapeKey), findsNothing);
    expect(tester.getBottomLeft(find.byType(PhoneSheet)).dy, _phone.height);
    for (final CaptureOption option in captureOptions) {
      final Rect slot = tester.getRect(
        find.byKey(captureScrapKey(option.type)),
      );
      expect(slot.left, greaterThanOrEqualTo(0));
      expect(slot.right, lessThanOrEqualTo(_phone.width));
      expect(slot.shortestSide, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('a narrow phone still fits the three scraps', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(
      tester,
      layout: ShellLayout.bottomBar,
      platform: TargetPlatform.android,
      size: const Size(320, 700),
    );

    expect(tester.takeException(), isNull);
    final Rect pile = tester.getRect(find.byKey(captureScrapPileKey));
    expect(pile.left, greaterThanOrEqualTo(0));
    expect(pile.right, lessThanOrEqualTo(320));
  });

  group('an unavailable scrap', () {
    Future<void> pumpTextOnly(
      WidgetTester tester, {
      List<EntryType>? selected,
    }) => _pumpSheet(
      tester,
      available: const <EntryType>{EntryType.text},
      onSelected: selected?.add,
    );

    testWidgets('says it is coming soon and cannot be chosen', (
      WidgetTester tester,
    ) async {
      final List<EntryType> selected = <EntryType>[];
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpTextOnly(tester, selected: selected);

      expect(find.text('Coming soon'), findsNWidgets(2));
      expect(find.text('speak it, hands-free'), findsNothing);
      await tester.tap(find.byKey(captureScrapKey(EntryType.voice)));
      await tester.pump();
      expect(selected, isEmpty);
      expect(
        tester.getSemantics(find.byKey(captureScrapKey(EntryType.video))),
        isSemantics(
          label: 'Record video\nComing soon',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('does not lift, straighten or show the click cursor', (
      WidgetTester tester,
    ) async {
      await pumpTextOnly(tester);
      final TestGesture mouse = await _mouse(tester);

      await _hover(tester, mouse, EntryType.voice);

      final _Pose pose = _poseOf(tester, EntryType.voice);
      expect(
        pose.degrees,
        closeTo(_restingTilts[EntryType.voice]!, _angleTolerance),
      );
      expect(pose.rise, closeTo(0, _angleTolerance));
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        isNot(SystemMouseCursors.click),
      );
    });

    testWidgets('is drawn flat with a faint outline', (
      WidgetTester tester,
    ) async {
      await pumpTextOnly(tester);
      final FieldNotesColors colors = FieldNotesColors.light;

      final BoxDecoration unavailable = _paperOf(tester, EntryType.video);
      final BoxDecoration available = _paperOf(tester, EntryType.text);
      expect(unavailable.boxShadow, isNull);
      expect(_borderOf(unavailable), colors.dashMuted);
      expect(available.boxShadow, isNotEmpty);
      expect(_borderOf(available), colors.line);
    });
  });

  for (final (Brightness brightness, FieldNotesColors colors)
      in <(Brightness, FieldNotesColors)>[
        (Brightness.light, FieldNotesColors.light),
        (Brightness.dark, FieldNotesColors.dark),
      ]) {
    testWidgets('the page and scraps draw in the ${brightness.name} theme', (
      WidgetTester tester,
    ) async {
      await _pumpSheet(tester, brightness: brightness);

      final StickerCard page = tester.widget<StickerCard>(
        find.byType(StickerCard),
      );
      expect(page.surface, colors.cardBright);
      expect(_paperOf(tester, EntryType.text).color, colors.cardLight);
      expect(_paperOf(tester, EntryType.voice).color, colors.cardWarm);
      expect(_paperOf(tester, EntryType.video).color, colors.cardBright);
      for (final EntryType type in EntryType.values) {
        expect(_borderOf(_paperOf(tester, type)), colors.line);
      }
      expect(_colourOfText(tester, 'Capture a moment'), colors.ink);
      expect(_colourOfText(tester, captureChooserSubtitle), colors.accentInk);
      expect(_colourOfText(tester, 'Write a note'), colors.ink);
      expect(_colourOfText(tester, 'put the day into words'), colors.muted);
    });
  }

  group('with enlarged text', () {
    testWidgets('nothing tilts, on the desktop page', (
      WidgetTester tester,
    ) async {
      await _pumpSheet(tester, textScale: 1.3);

      for (final EntryType type in EntryType.values) {
        expect(_poseOf(tester, type).degrees, closeTo(0, _angleTolerance));
      }
      expect(
        tester.widget<StickerCard>(find.byType(StickerCard)).rotationDegrees,
        0,
      );
      expect(
        tester.widget<Transform>(find.byKey(captureChooserTapeKey)).transform,
        Matrix4.identity(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a scrap still lifts on hover but stays straight', (
      WidgetTester tester,
    ) async {
      await _pumpSheet(tester, textScale: 1.3);
      final TestGesture mouse = await _mouse(tester);

      await _hover(tester, mouse, EntryType.text);

      final _Pose pose = _poseOf(tester, EntryType.text);
      expect(pose.degrees, closeTo(0, _angleTolerance));
      expect(pose.rise, closeTo(captureScrapLift, _angleTolerance));
    });

    for (final (ShellLayout layout, TargetPlatform platform, Size size)
        in <(ShellLayout, TargetPlatform, Size)>[
          (ShellLayout.sidebar, TargetPlatform.macOS, _desktop),
          (ShellLayout.bottomBar, TargetPlatform.android, _phone),
        ]) {
      testWidgets('at double size the ${layout.name} scraps part and nothing '
          'overflows', (WidgetTester tester) async {
        await _pumpSheet(
          tester,
          layout: layout,
          platform: platform,
          size: size,
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(captureScrapPileKey), findsNothing);
        final List<Rect> slots = <Rect>[
          for (final EntryType type in EntryType.values)
            tester.getRect(find.byKey(captureScrapKey(type))),
        ];
        for (final (int index, Rect slot) in slots.indexed) {
          for (final Rect other in slots.skip(index + 1)) {
            expect(slot.overlaps(other), isFalse);
          }
        }
      });
    }
  });

  testWidgets('with reduced motion the scraps are dealt and turn at once', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(tester, disableAnimations: true, settle: false);

    final Iterable<FadeTransition> deals = tester.widgetList<FadeTransition>(
      find.descendant(
        of: find.byKey(captureScrapPileKey),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(deals, hasLength(3));
    expect(
      deals.every((FadeTransition deal) => deal.opacity.value == 1),
      isTrue,
    );

    final TestGesture mouse = await _mouse(tester);
    await mouse.moveTo(
      tester.getCenter(find.byKey(captureScrapKey(EntryType.video))),
    );
    await tester.pump();
    await tester.pump();

    expect(
      _poseOf(tester, EntryType.video).degrees,
      closeTo(0, _angleTolerance),
    );
  });
}
