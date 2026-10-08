import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/system_bars.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

const Key _contentKey = ValueKey<String>('viewer-content');
const Key _regionKey = ValueKey<String>('no-swipe-region');
const Key _closeKey = ValueKey<String>('dock-close');
const Key _earlierKey = ValueKey<String>('dock-earlier');
const Key _playKey = ValueKey<String>('dock-play');
const Key _laterKey = ValueKey<String>('dock-later');
const Key _deleteKey = ValueKey<String>('dock-delete');

const double _statusBar = 34;
const double _gestureBar = 24;
const double _primaryDiameter = 68;

const List<Size> _phones = <Size>[Size(384, 832), Size(412, 869)];
const List<Key> _glassKeys = <Key>[
  _closeKey,
  _earlierKey,
  _laterKey,
  _deleteKey,
];
const List<String> _labels = <String>[
  'Close',
  'Earlier',
  'Play',
  'Later',
  'Delete',
];

void _phone(WidgetTester tester, {Size size = const Size(384, 832)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
}

void _mac(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget stage, {
  required TargetPlatform platform,
  Brightness brightness = Brightness.dark,
}) {
  return MaterialApp(
    key: ValueKey<String>('$platform-$brightness'),
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: platform, brightness: brightness),
    home: DialogHost(child: stage),
  );
}

Finder _inStage(Finder matching) =>
    find.descendant(of: find.byType(ViewerStage), matching: matching);

Widget _glyph() => const SizedBox.square(dimension: 15);

ViewerDockSlot _glassSlot(String label, Key key, {bool grouped = false}) {
  return ViewerDockSlot(
    label: label,
    control: ViewerGlassCircle(
      key: key,
      label: label,
      glyph: _glyph(),
      onPressed: () {},
      grouped: grouped,
    ),
  );
}

List<ViewerDockSlot?> _slots({required bool earlier, bool grouped = false}) {
  return <ViewerDockSlot?>[
    _glassSlot('Close', _closeKey, grouped: grouped),
    earlier ? _glassSlot('Earlier', _earlierKey, grouped: grouped) : null,
    ViewerDockSlot(
      label: 'Play',
      control: ViewerPrimaryButton(
        key: _playKey,
        playing: false,
        diameter: _primaryDiameter,
        onPressed: () {},
      ),
    ),
    _glassSlot('Later', _laterKey, grouped: grouped),
    _glassSlot('Delete', _deleteKey, grouped: grouped),
  ];
}

const Key _boundaryKey = ValueKey<String>('viewer-glass-boundary');
const int _maxGroupedDelta = 8;
const double _stripe = 7;
const List<Color> _stripeColours = <Color>[
  Color(0xFFE4572E),
  Color(0xFF17BEBB),
  Color(0xFFFFC914),
  Color(0xFF2E282A),
  Color(0xFF76B041),
];

class _StripesPainter extends CustomPainter {
  const _StripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (int index = 0; index * _stripe < size.width; index++) {
      canvas.drawRect(
        Rect.fromLTWH(index * _stripe, 0, _stripe, size.height),
        Paint()..color = _stripeColours[index % _stripeColours.length],
      );
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => false;
}

Widget _overPicture(Widget chrome, {required TargetPlatform platform}) {
  return _host(
    RepaintBoundary(
      key: _boundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CustomPaint(painter: _StripesPainter()),
          chrome,
        ],
      ),
    ),
    platform: platform,
  );
}

Future<Uint8List> _capture(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final Uint8List? pixels = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return pixels!;
}

List<BackdropKey?> _backdropKeys(WidgetTester tester, Finder within) => tester
    .renderObjectList<RenderBackdropFilter>(
      find.descendant(of: within, matching: find.byType(BackdropFilter)),
    )
    .map((RenderBackdropFilter filter) => filter.backdropKey)
    .toList();

int _worstChannelDelta(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  int worst = 0;
  for (int index = 0; index < a.length; index++) {
    final int delta = (a[index] - b[index]).abs();
    if (delta > worst) {
      worst = delta;
    }
  }
  return worst;
}

Widget _dockStage(List<ViewerDockSlot?> slots) {
  return ViewerStage(
    ground: ViewerGround.voice,
    child: ViewerDock(slots: slots),
  );
}

void main() {
  testWidgets('a dark viewer asks for light status bar icons', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    for (final Brightness brightness in Brightness.values) {
      SystemChrome.setSystemUIOverlayStyle(lightBackdropSystemBars);
      await tester.pumpWidget(const SizedBox());
      expect(SystemChrome.latestStyle, lightBackdropSystemBars);

      await tester.pumpWidget(
        _host(
          const ViewerStage(
            ground: ViewerGround.voice,
            child: SizedBox.expand(key: _contentKey),
          ),
          platform: TargetPlatform.android,
          brightness: brightness,
        ),
      );
      await tester.pump();

      final Finder region = _inStage(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region, findsOneWidget);
      expect(
        tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(region).value,
        darkBackdropSystemBars,
      );
      expect(
        find.descendant(of: region, matching: find.byKey(_contentKey)),
        findsOneWidget,
      );
      expect(SystemChrome.latestStyle, darkBackdropSystemBars);
      expect(_inStage(find.byType(WindowDragBand)), findsNothing);
      expect(
        tester.getRect(find.byKey(_contentKey)),
        const Rect.fromLTWH(0, 0, 384, 832),
      );
    }

    _mac(tester);
    for (final Brightness brightness in Brightness.values) {
      await tester.pumpWidget(
        _host(
          const ViewerStage(
            ground: ViewerGround.media,
            child: SizedBox.expand(key: _contentKey),
          ),
          platform: TargetPlatform.macOS,
          brightness: brightness,
        ),
      );

      expect(
        _inStage(find.byType(AnnotatedRegion<SystemUiOverlayStyle>)),
        findsNothing,
      );
      final Finder band = _inStage(find.byType(WindowDragBand));
      expect(band, findsOneWidget);
      expect(
        tester.getRect(band),
        const Rect.fromLTWH(0, 0, 1280, shellTitleBarHeight),
      );
      expect(shellTitleBarHeight, 42);
      expect(
        tester.getRect(find.byKey(_contentKey)),
        const Rect.fromLTWH(0, 42, 1280, 758),
      );
    }
  });

  testWidgets('a swipe steps but a drag on a no-swipe region does not', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    int next = 0;
    int previous = 0;
    int taps = 0;
    double scrubbed = 0;

    Widget stage(TargetPlatform platform) {
      return _host(
        ViewerStage(
          ground: ViewerGround.voice,
          onSwipeNext: () => next += 1,
          onSwipePrevious: () => previous += 1,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 22,
                right: 22,
                top: 328,
                height: 176,
                child: NoSwipe(
                  child: GestureDetector(
                    key: _regionKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps += 1,
                    onHorizontalDragUpdate: (DragUpdateDetails details) =>
                        scrubbed += details.delta.dx,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
        platform: platform,
      );
    }

    await tester.pumpWidget(stage(TargetPlatform.android));

    await tester.dragFrom(const Offset(300, 640), const Offset(-120, 0));
    await tester.pump();
    expect(next, 1);
    expect(previous, 0);

    await tester.dragFrom(const Offset(80, 640), const Offset(120, 0));
    await tester.pump();
    expect(next, 1);
    expect(previous, 1);

    await tester.flingFrom(const Offset(300, 700), const Offset(-120, 0), 1200);
    await tester.pumpAndSettle();
    expect(next, 2);
    expect(previous, 1);

    await tester.dragFrom(const Offset(200, 640), const Offset(-30, 0));
    await tester.pump();
    await tester.dragFrom(const Offset(200, 640), const Offset(30, 0));
    await tester.pump();
    expect(next, 2);
    expect(previous, 1);

    await tester.dragFrom(const Offset(250, 760), const Offset(-70, -160));
    await tester.pump();
    await tester.dragFrom(const Offset(100, 200), const Offset(70, 160));
    await tester.pump();
    expect(next, 2);
    expect(previous, 1);

    final Offset region = tester.getCenter(find.byKey(_regionKey));
    await tester.dragFrom(region + const Offset(60, 0), const Offset(-120, 0));
    await tester.pump();
    final double leftward = scrubbed;
    expect(leftward, lessThan(0));
    await tester.dragFrom(region - const Offset(60, 0), const Offset(120, 0));
    await tester.pump();
    expect(scrubbed, greaterThan(leftward));
    expect(next, 2);
    expect(previous, 1);

    await tester.tap(find.byKey(_regionKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, 1);
    expect(next, 2);
    expect(previous, 1);

    _mac(tester);
    await tester.pumpWidget(stage(TargetPlatform.macOS));
    await tester.dragFrom(const Offset(900, 600), const Offset(-120, 0));
    await tester.pump();
    await tester.dragFrom(const Offset(300, 600), const Offset(120, 0));
    await tester.pump();
    expect(next, 2);
    expect(previous, 1);
  });

  testWidgets(
    'the phone dock sits in the bottom third with 48-point controls and kept slots',
    (WidgetTester tester) async {
      expect(viewerDockLift, 18);
      expect(Palette.coral.toARGB32(), 0xFFB8566A);
      expect(Palette.mediaInk.toARGB32(), 0xFFF3E6D1);

      for (final Size size in _phones) {
        _phone(tester, size: size);
        for (final Brightness brightness in Brightness.values) {
          await tester.pumpWidget(
            _host(
              _dockStage(_slots(earlier: true)),
              platform: TargetPlatform.android,
              brightness: brightness,
            ),
          );

          final double dockBottom = size.height - _gestureBar - viewerDockLift;
          for (final String label in _labels) {
            final Finder text = find.text(label);
            expect(text, findsOneWidget);
            expect(tester.getRect(text).bottom, moreOrLessEquals(dockBottom));
            expect(
              tester.widget<Text>(text).style?.color?.toARGB32(),
              Palette.mediaInk.toARGB32(),
            );
          }

          final Map<Key, double> centres = <Key, double>{};
          for (final Key key in <Key>[..._glassKeys, _playKey]) {
            final Rect rect = tester.getRect(find.byKey(key));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.center.dy, greaterThan(size.height * 2 / 3));
            expect(rect.left, greaterThanOrEqualTo(24));
            expect(rect.right, lessThanOrEqualTo(size.width - 24));
            centres[key] = rect.center.dx;
          }

          for (final Key key in _glassKeys) {
            final Finder glass = find.descendant(
              of: find.byKey(key),
              matching: find.byType(GlassSurface),
            );
            expect(tester.widget<GlassSurface>(glass).tone, GlassTone.media);
            expect(tester.getSize(glass), const Size.square(48));
          }

          expect(
            tester.getSize(find.byKey(_playKey)),
            const Size.square(_primaryDiameter),
          );
          final Finder disc = find.descendant(
            of: find.byKey(_playKey),
            matching: find.byWidgetPredicate(
              (Widget widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).shape == BoxShape.circle,
            ),
          );
          expect(disc, findsOneWidget);
          expect(tester.getSize(disc), const Size.square(_primaryDiameter));
          final BoxDecoration face =
              tester.widget<DecoratedBox>(disc).decoration as BoxDecoration;
          expect(face.color?.toARGB32(), Palette.coral.toARGB32());
          expect(face.gradient, isNull);
          final FieldNotesColors colors = brightness == Brightness.light
              ? FieldNotesColors.light
              : FieldNotesColors.dark;
          final Border edge = face.border! as Border;
          expect(edge.top.width, 1.5);
          expect(edge.top.color.toARGB32(), colors.line.toARGB32());

          await tester.pumpWidget(
            _host(
              _dockStage(_slots(earlier: false)),
              platform: TargetPlatform.android,
              brightness: brightness,
            ),
          );

          expect(find.byKey(_earlierKey), findsNothing);
          expect(find.text('Earlier'), findsNothing);
          for (final Key key in <Key>[
            _closeKey,
            _playKey,
            _laterKey,
            _deleteKey,
          ]) {
            expect(
              tester.getCenter(find.byKey(key)).dx,
              moreOrLessEquals(centres[key]!),
            );
          }
        }
      }
    },
  );

  testWidgets('the dock glass circles share one backdrop read', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _overPicture(
        ViewerDock(slots: _slots(earlier: true, grouped: true)),
        platform: TargetPlatform.android,
      ),
    );
    final List<BackdropKey?> keys = _backdropKeys(
      tester,
      find.byType(ViewerDock),
    );
    expect(keys, hasLength(_glassKeys.length));
    expect(keys.first, isNotNull);
    expect(keys.toSet(), hasLength(1));
    final Uint8List shared = await _capture(tester);

    await tester.pumpWidget(
      _overPicture(
        ViewerDock(slots: _slots(earlier: true)),
        platform: TargetPlatform.android,
      ),
    );
    expect(
      _backdropKeys(tester, find.byType(ViewerDock)).toSet(),
      <BackdropKey?>{null},
    );
    final Uint8List separate = await _capture(tester);

    expect(
      _worstChannelDelta(shared, separate),
      lessThanOrEqualTo(_maxGroupedDelta),
    );
  });
}
