import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart'
    show IconStickerGlyphIcon;
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart'
    show PlayPauseGlyph, TransportGlyphIcon;
import 'package:field_notes/features/entry_cards/transport/transport_timeline.dart'
    show TransportTimeline;
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerEarlierKey, logViewerLaterKey;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

import '../entry_cards/support/entry_cards_harness.dart';
import '../entry_cards/support/fake_video_player.dart';

const String _videoId = 'video-media';
const Color _white = Color(0xFFFFFFFF);
const double _shadeTolerance = 0.02;
const double _textContrast = 4.5;
const double _iconContrast = 3;

void _window(
  WidgetTester tester,
  Size size, {
  double top = 0,
  double bottom = 0,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.reset);
}

FakeMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('video-shade');
  addTearDown(() => folder.deleteSync(recursive: true));
  final File clip = File('${folder.path}/clip.mp4')
    ..writeAsBytesSync(List<int>.filled(8, 0));
  return FakeMediaResolver()..set(
    _videoId,
    ResolvedMedia.available(
      blob: blobOf(id: _videoId, relPath: 'clip.mp4', kind: MediaKind.video),
      file: clip,
    ),
  );
}

LogViewerScene _scene({bool neighbours = false}) {
  return LogViewerScene(
    entry: const Entry(
      id: 'video-entry',
      dayId: 'd1',
      type: EntryType.video,
      title: 'Harbour',
      mediaId: _videoId,
      durationMs: 65000,
      createdAt: 0,
      updatedAt: 0,
    ),
    date: '2025-10-02',
    dayTitle: 'Thursday 2 October',
    mood: Mood.calm,
    index: 1,
    count: 3,
    earlier: null,
    later: null,
    exit: LogViewerExit.close,
    onBack: () {},
    onEarlier: neighbours ? () {} : null,
    onLater: neighbours ? () {} : null,
    onDelete: () {},
    onEdit: null,
  );
}

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  Brightness brightness = Brightness.light,
  bool embedded = false,
  bool neighbours = false,
}) async {
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
  final Widget view = VideoViewerView(
    scene: _scene(neighbours: neighbours),
    resolver: _resolver(),
    playerFactory: () => player,
    slots: slots,
    focus: PlaybackFocus(),
    embedded: embedded,
  );
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey<String>('$platform-$brightness-$embedded'),
      overrides: <Override>[
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform, brightness: brightness),
        home: DialogHost(
          child: embedded
              ? Center(child: SizedBox(width: 704, height: 396, child: view))
              : view,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  player.emitState(VideoPlaybackState.paused);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Rect _box(WidgetTester tester) => tester.getRect(find.byType(VideoBody));

LinearGradient _gradientOf(WidgetTester tester, Finder shade) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: shade, matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

Color _gradientAt(LinearGradient gradient, Rect rect, Offset point) {
  final Offset begin = gradient.begin
      .resolve(TextDirection.ltr)
      .withinRect(rect);
  final Offset end = gradient.end.resolve(TextDirection.ltr).withinRect(rect);
  final Offset axis = end - begin;
  final Offset along = point - begin;
  final double t =
      ((along.dx * axis.dx + along.dy * axis.dy) / axis.distanceSquared).clamp(
        0.0,
        1.0,
      );
  final List<double> stops =
      gradient.stops ??
      <double>[
        for (int index = 0; index < gradient.colors.length; index += 1)
          index / (gradient.colors.length - 1),
      ];
  for (int index = 1; index < stops.length; index += 1) {
    if (t <= stops[index]) {
      final double span = stops[index] - stops[index - 1];
      final double local = span == 0 ? 1 : (t - stops[index - 1]) / span;
      return Color.lerp(
        gradient.colors[index - 1],
        gradient.colors[index],
        local,
      )!;
    }
  }
  return gradient.colors.last;
}

double _blackAt(WidgetTester tester, Finder shade, Offset point) {
  final Rect rect = tester.getRect(shade);
  if (point.dy < rect.top - 0.01 || point.dy > rect.bottom + 0.01) {
    return 0;
  }
  final Color colour = _gradientAt(_gradientOf(tester, shade), rect, point);
  expect(colour.r, 0);
  expect(colour.g, 0);
  expect(colour.b, 0);
  return colour.a;
}

double _channel(double value) => value <= 0.04045
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

double _whiteOverGrey(double grey) => 1.05 / (_channel(grey) + 0.05);

void _expectCurve(
  WidgetTester tester,
  Finder shade, {
  required bool fromTop,
  required double height,
  required List<double> expected,
  required String reason,
}) {
  final Rect rect = tester.getRect(shade);
  for (int index = 0; index < expected.length; index += 1) {
    final double distance = height * index / (expected.length - 1);
    final Offset point = Offset(
      rect.center.dx,
      fromTop ? rect.top + distance : rect.bottom - distance,
    );
    expect(
      _blackAt(tester, shade, point),
      closeTo(expected[index], _shadeTolerance),
      reason: '$reason at $distance px',
    );
  }
}

typedef _Shade = ({Rect rect, List<Color> colours, List<double>? stops});

_Shade _shadeOf(WidgetTester tester, Key key) {
  final Finder shade = find.byKey(key);
  final LinearGradient gradient = _gradientOf(tester, shade);
  return (
    rect: tester.getRect(shade),
    colours: gradient.colors,
    stops: gradient.stops,
  );
}

void _expectSameShade(_Shade light, _Shade dark) {
  expect(dark.rect, light.rect);
  expect(dark.colours, light.colours);
  expect(dark.stops, light.stops);
}

typedef _Control = ({String name, Color colour, Offset centre, bool text});

List<_Control> _controlsIn(WidgetTester tester, Finder area) {
  Iterable<Element> under(Type type) =>
      find.descendant(of: area, matching: find.byType(type)).evaluate();
  Offset centre(Element element) =>
      (element.renderObject! as RenderBox).localToGlobal(Offset.zero) +
      (element.renderObject! as RenderBox).size.center(Offset.zero);
  return <_Control>[
    for (final Element element in under(RichText))
      (
        name: (element.widget as RichText).text.toPlainText(),
        colour: (element.widget as RichText).text.style!.color!,
        centre: centre(element),
        text: true,
      ),
    for (final Element element in under(EditableText))
      (
        name: 'title field',
        colour: (element.widget as EditableText).style.color!,
        centre: centre(element),
        text: true,
      ),
    for (final Element element in under(PlayPauseGlyph))
      (
        name: 'play glyph',
        colour: (element.widget as PlayPauseGlyph).color,
        centre: centre(element),
        text: false,
      ),
    for (final Element element in under(TransportGlyphIcon))
      (
        name: '${(element.widget as TransportGlyphIcon).glyph}',
        colour: (element.widget as TransportGlyphIcon).color,
        centre: centre(element),
        text: false,
      ),
    for (final Element element in under(ChevronGlyph))
      (
        name: 'chevron',
        colour: (element.widget as ChevronGlyph).color,
        centre: centre(element),
        text: false,
      ),
    for (final Element element in under(IconStickerGlyphIcon))
      (
        name: '${(element.widget as IconStickerGlyphIcon).glyph}',
        colour: (element.widget as IconStickerGlyphIcon).color,
        centre: centre(element),
        text: false,
      ),
    for (final Element element in under(TransportTimeline))
      (
        name: 'scrub rail',
        colour: (element.widget as TransportTimeline).palette.played,
        centre: centre(element),
        text: false,
      ),
  ];
}

void main() {
  testWidgets(
    'the full view bottom shade eases from 72 percent black to nothing 168 px up',
    (WidgetTester tester) async {
      _window(tester, const Size(1440, 900));
      final List<_Shade> shades = <_Shade>[];
      for (final Brightness brightness in Brightness.values) {
        await _open(
          tester,
          platform: TargetPlatform.macOS,
          brightness: brightness,
        );
        final Finder shade = find.byKey(videoBottomShadeKey);
        expect(shade, findsOneWidget);
        final Rect rect = tester.getRect(shade);
        final Rect box = _box(tester);
        expect(rect.height, closeTo(168, 0.5), reason: brightness.name);
        expect(rect.bottom, closeTo(box.bottom, 0.5), reason: brightness.name);
        expect(rect.left, closeTo(box.left, 0.5), reason: brightness.name);
        expect(rect.width, closeTo(box.width, 0.5), reason: brightness.name);
        _expectCurve(
          tester,
          shade,
          fromTop: false,
          height: 168,
          expected: const <double>[0.72, 0.61, 0.36, 0.11, 0],
          reason: brightness.name,
        );
        shades.add(_shadeOf(tester, videoBottomShadeKey));
      }
      _expectSameShade(shades.first, shades.last);
    },
  );

  testWidgets(
    'the title shade eases from 66 percent black to nothing 128 px down',
    (WidgetTester tester) async {
      _window(tester, const Size(1440, 900));
      final List<_Shade> shades = <_Shade>[];
      for (final Brightness brightness in Brightness.values) {
        await _open(
          tester,
          platform: TargetPlatform.macOS,
          brightness: brightness,
        );
        final Finder shade = find.descendant(
          of: find.byType(ViewerLogBar),
          matching: find.byKey(videoTopShadeKey),
        );
        expect(shade, findsOneWidget);
        final Rect rect = tester.getRect(shade);
        final Rect box = _box(tester);
        expect(rect.height, closeTo(128, 0.5), reason: brightness.name);
        expect(rect.top, closeTo(box.top, 0.5), reason: brightness.name);
        expect(rect.left, closeTo(box.left, 0.5), reason: brightness.name);
        expect(rect.width, closeTo(box.width, 0.5), reason: brightness.name);
        _expectCurve(
          tester,
          shade,
          fromTop: true,
          height: 128,
          expected: const <double>[0.66, 0.56, 0.33, 0.10, 0],
          reason: brightness.name,
        );
        shades.add(_shadeOf(tester, videoTopShadeKey));
      }
      _expectSameShade(shades.first, shades.last);
    },
  );

  testWidgets('the day pop-up bottom shade is gone 132 px up', (
    WidgetTester tester,
  ) async {
    _window(tester, const Size(1100, 760));
    await _open(tester, platform: TargetPlatform.macOS, embedded: true);

    final Finder shade = find.byKey(videoBottomShadeKey);
    expect(shade, findsOneWidget);
    final Rect rect = tester.getRect(shade);
    final Rect box = _box(tester);
    expect(rect.height, closeTo(132, 0.5));
    expect(rect.bottom, closeTo(box.bottom, 0.5));
    expect(rect.width, closeTo(box.width, 0.5));
    _expectCurve(
      tester,
      shade,
      fromTop: false,
      height: 132,
      expected: const <double>[0.72, 0.61, 0.36, 0.11, 0],
      reason: 'day pop-up',
    );
  });

  testWidgets(
    'every video control is white and legible over a pure white frame',
    (WidgetTester tester) async {
      _window(tester, const Size(1440, 900));
      final List<List<(String, Color)>> themes = <List<(String, Color)>>[];
      for (final Brightness brightness in Brightness.values) {
        await _open(
          tester,
          platform: TargetPlatform.macOS,
          brightness: brightness,
        );
        final Finder bottom = find.byKey(videoBottomShadeKey);
        final Finder top = find.byKey(videoTopShadeKey);
        final List<_Control> controls = <_Control>[
          ..._controlsIn(tester, find.byType(Transport)),
          ..._controlsIn(tester, find.byType(ViewerLogBar)),
        ];
        expect(controls.where((_Control control) => control.text), isNotEmpty);
        expect(controls.where((_Control control) => !control.text), isNotEmpty);
        expect(
          controls.map((_Control control) => control.name),
          contains('scrub rail'),
        );
        for (final _Control control in controls) {
          final String reason = '${control.name} in ${brightness.name}';
          expect(control.colour, _white, reason: reason);
          final double grey =
              (1 - _blackAt(tester, bottom, control.centre)) *
              (1 - _blackAt(tester, top, control.centre));
          expect(
            _whiteOverGrey(grey),
            greaterThanOrEqualTo(control.text ? _textContrast : _iconContrast),
            reason: reason,
          );
        }
        for (final Type filter in <Type>[BackdropFilter, ImageFiltered]) {
          for (final Type area in <Type>[Transport, ViewerLogBar]) {
            expect(
              find.descendant(
                of: find.byType(area),
                matching: find.byType(filter),
              ),
              findsNothing,
              reason: '$filter in $area, ${brightness.name}',
            );
          }
        }
        themes.add(<(String, Color)>[
          for (final _Control control in controls)
            (control.name, control.colour),
        ]);
      }
      expect(themes.first, themes.last);
    },
  );

  testWidgets(
    'the previous and next arrows are 48 px circles of 48 percent black with a white chevron',
    (WidgetTester tester) async {
      _window(tester, const Size(1440, 900));
      await _open(tester, platform: TargetPlatform.macOS, neighbours: true);

      for (final Key key in <Key>[logViewerEarlierKey, logViewerLaterKey]) {
        final Finder arrow = find.byKey(key);
        expect(arrow, findsOneWidget);
        expect(tester.getSize(arrow), const Size(48, 48), reason: '$key');
        final Container face = tester.widget<Container>(
          find.descendant(of: arrow, matching: find.byType(Container)),
        );
        final BoxDecoration decoration = face.decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle, reason: '$key');
        expect(decoration.border, isNull, reason: '$key');
        final Color fill = decoration.color!;
        expect(fill.r, 0, reason: '$key');
        expect(fill.g, 0, reason: '$key');
        expect(fill.b, 0, reason: '$key');
        expect(fill.a * 255, closeTo(122, 1), reason: '$key');
        final ChevronGlyph chevron = tester.widget<ChevronGlyph>(
          find.descendant(of: arrow, matching: find.byType(ChevronGlyph)),
        );
        expect(chevron.color, _white, reason: '$key');
      }
    },
  );

  testWidgets('on Android one shade replaces the dock band and its fade', (
    WidgetTester tester,
  ) async {
    _window(tester, const Size(412, 915), top: 34, bottom: 24);
    await _open(tester, platform: TargetPlatform.android);

    final Finder shade = find.byKey(videoBottomShadeKey);
    expect(shade, findsOneWidget);
    final Rect box = _box(tester);
    final Rect picture = tester.getRect(find.byKey(videoFrameKey));
    final Rect rect = tester.getRect(shade);
    expect(picture.height, lessThan(box.height - 1));
    expect(rect.bottom, closeTo(box.bottom, 0.5));
    expect(rect.bottom, isNot(closeTo(picture.bottom, 1)));
    expect(rect.height, closeTo(168, 0.5));

    final FieldNotesColors colors = FieldNotesColors.light;
    final List<LinearGradient> gradients = <LinearGradient>[
      for (final Element element
          in find
              .descendant(
                of: find.byType(VideoViewerView),
                matching: find.byType(DecoratedBox),
              )
              .evaluate())
        if ((element.widget as DecoratedBox).decoration case BoxDecoration(
          gradient: final LinearGradient gradient,
        ))
          gradient,
    ];
    for (final LinearGradient gradient in gradients) {
      expect(gradient.colors, isNot(contains(colors.viewerFadeStart)));
      expect(gradient.colors, isNot(contains(colors.viewerFadeEnd)));
    }
    final Iterable<Element> bottomBands = find
        .descendant(
          of: find.byType(VideoViewerView),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).gradient != null,
          ),
        )
        .evaluate()
        .where((Element element) {
          final RenderBox render = element.renderObject! as RenderBox;
          final Rect band = render.localToGlobal(Offset.zero) & render.size;
          return (band.bottom - box.bottom).abs() < 0.5;
        });
    expect(bottomBands, hasLength(1));
  });
}
