import 'package:flutter/material.dart';
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

ViewerDockSlot _glassSlot(String label, Key key) {
  return ViewerDockSlot(
    label: label,
    control: ViewerGlassCircle(
      key: key,
      label: label,
      glyph: _glyph(),
      onPressed: () {},
    ),
  );
}

List<ViewerDockSlot?> _slots({required bool earlier}) {
  return <ViewerDockSlot?>[
    _glassSlot('Close', _closeKey),
    earlier ? _glassSlot('Earlier', _earlierKey) : null,
    ViewerDockSlot(
      label: 'Play',
      control: ViewerPrimaryButton(
        key: _playKey,
        playing: false,
        diameter: _primaryDiameter,
        onPressed: () {},
      ),
    ),
    _glassSlot('Later', _laterKey),
    _glassSlot('Delete', _deleteKey),
  ];
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
}
