import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart'
    show IconStickerGlyphIcon;
import 'package:field_notes/domain/models/models.dart';
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
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/state/media_provider.dart';

import '../entry_cards/support/fake_video_player.dart';

const Color _white = Color(0xFFFFFFFF);
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

typedef _StoredVideo = ({
  ProviderContainer container,
  MediaResolver resolver,
  String mediaId,
});

Future<_StoredVideo> _storeLandscapeVideo(WidgetTester tester) async {
  final db.AppDatabase database = db.AppDatabase(NativeDatabase.memory());
  final Directory root = Directory.systemTemp.createTempSync('video-shade');
  addTearDown(
    () => tester.runAsync(() async {
      await database.close();
      await root.delete(recursive: true);
    }),
  );
  final FilesystemMediaStore store = FilesystemMediaStore(
    database: database,
    recorder: ChangeRecorder(database),
    root: root,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      mediaStoreProvider.overrideWith((Ref ref) async => store),
    ],
  );
  addTearDown(container.dispose);
  final MediaStoreResolver resolver = MediaStoreResolver(store);
  final MediaBlob? blob = await tester.runAsync(() async {
    final MediaBlob stored = await store.putBytes(
      bytes: List<int>.filled(8, 0),
      mime: 'video/mp4',
      kind: MediaKind.video,
      width: 1920,
      height: 1080,
      durationMs: 65000,
    );
    await resolver.resolve(stored.id);
    container.listen(
      videoAspectProvider(stored.id),
      (AsyncValue<double?>? previous, AsyncValue<double?> next) {},
    );
    await container.read(videoAspectProvider(stored.id).future);
    return stored;
  });
  return (container: container, resolver: resolver, mediaId: blob!.id);
}

LogViewerScene _scene(String mediaId, {bool neighbours = false}) {
  return LogViewerScene(
    entry: Entry(
      id: 'video-entry',
      dayId: 'd1',
      type: EntryType.video,
      title: 'Harbour',
      mediaId: mediaId,
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
  final _StoredVideo video = await _storeLandscapeVideo(tester);
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
  final Widget view = VideoViewerView(
    scene: _scene(video.mediaId, neighbours: neighbours),
    resolver: video.resolver,
    playerFactory: () => player,
    slots: slots,
    focus: PlaybackFocus(),
    embedded: embedded,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: video.container,
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

typedef _Surface = ({
  String name,
  TargetPlatform platform,
  Size window,
  double statusBar,
  double gestureBar,
  bool embedded,
});

const List<_Surface> _surfaces = <_Surface>[
  (
    name: 'Android full view',
    platform: TargetPlatform.android,
    window: Size(412, 915),
    statusBar: 34,
    gestureBar: 24,
    embedded: false,
  ),
  (
    name: 'Windows full view',
    platform: TargetPlatform.windows,
    window: Size(1440, 900),
    statusBar: 0,
    gestureBar: 0,
    embedded: false,
  ),
  (
    name: 'Windows full view on a large display',
    platform: TargetPlatform.windows,
    window: Size(2560, 1440),
    statusBar: 0,
    gestureBar: 0,
    embedded: false,
  ),
  (
    name: 'Windows day pop-up',
    platform: TargetPlatform.windows,
    window: Size(1100, 760),
    statusBar: 0,
    gestureBar: 0,
    embedded: true,
  ),
];

double _greyBehind(WidgetTester tester, Offset point) {
  final Finder top = find.byKey(videoTopShadeKey);
  final double underTop = top.evaluate().isEmpty
      ? 1
      : 1 - _blackAt(tester, top, point);
  return (1 - _blackAt(tester, find.byKey(videoBottomShadeKey), point)) *
      underTop;
}

void main() {
  for (final _Surface surface in _surfaces) {
    testWidgets(
      'every video control in the ${surface.name} is legible over a pure white frame',
      (WidgetTester tester) async {
        _window(
          tester,
          surface.window,
          top: surface.statusBar,
          bottom: surface.gestureBar,
        );
        await _open(
          tester,
          platform: surface.platform,
          embedded: surface.embedded,
        );

        final List<_Control> controls = <_Control>[
          ..._controlsIn(tester, find.byType(Transport)),
          ..._controlsIn(tester, find.byType(ViewerLogBar)),
        ];
        expect(
          controls.map((_Control control) => control.name),
          contains('scrub rail'),
        );
        expect(controls.where((_Control control) => control.text), isNotEmpty);
        final Iterable<_Control> onShade = controls.where(
          (_Control control) => control.colour == _white,
        );
        expect(
          controls
              .where((_Control control) => control.colour != _white)
              .map((_Control control) => control.name),
          everyElement('play glyph'),
        );
        for (final _Control control in onShade) {
          expect(
            _whiteOverGrey(_greyBehind(tester, control.centre)),
            greaterThanOrEqualTo(control.text ? _textContrast : _iconContrast),
            reason: '${control.name} in the ${surface.name}',
          );
        }
      },
    );
  }

  testWidgets('the keyboard skip label is legible over a pure white frame', (
    WidgetTester tester,
  ) async {
    _window(tester, const Size(1440, 900));
    await _open(tester, platform: TargetPlatform.windows);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    final Finder label = find.byKey(videoSkipLabelKey);
    expect(label, findsOneWidget);
    final Finder text = find.descendant(
      of: label,
      matching: find.byType(RichText),
    );
    final Color face =
        (tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: label,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color!;
    final double grey =
        (1 - face.a) * _greyBehind(tester, tester.getCenter(text));
    expect(_whiteOverGrey(grey), greaterThanOrEqualTo(_textContrast));
  });
}
