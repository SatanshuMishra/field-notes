import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/window_chrome.dart' show WindowDragBand;
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_media_pane.dart';
import 'package:field_notes/features/day_detail/day_note_pane.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart'
    show
        TransportGlyph,
        TransportGlyphIcon,
        transportDockBackKey,
        transportDockMoreKey;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackKey;
import 'package:field_notes/features/log_viewer/video_viewer_view.dart'
    show videoAspectProvider;
import 'package:field_notes/features/log_viewer/viewer_chrome.dart'
    show ViewerEdgeArrows, ViewerLogBar, ViewerStage;
import 'package:field_notes/features/today/today_providers.dart';

import '../entry_cards/support/fake_audio_player.dart';
import '../entry_cards/support/fake_video_player.dart';
import '../notes/support/notes_harness.dart' show FakeNoteMediaResolver;
import 'support/day_detail_harness.dart' show blobOf;

const Size _window = Size(1100, 760);
const Size _pane = Size(760, 620);
const String _voiceMedia = 'blob-voice';
const String _videoMedia = 'blob-video';

Entry _entry(String id, EntryType type, {String? mediaId, String? text}) =>
    Entry(
      id: id,
      dayId: 'day-1',
      type: type,
      mediaId: mediaId,
      textContent: text,
      durationMs: type == EntryType.text ? null : 65000,
      peaks: type == EntryType.voice
          ? const <double>[0.2, 0.6, 0.9, 0.4, 0.7, 0.3]
          : null,
      createdAt: DateTime(2026, 7, 19, 9, 12).millisecondsSinceEpoch,
      updatedAt: 0,
    );

final Entry _voice = _entry('voice-1', EntryType.voice, mediaId: _voiceMedia);
final Entry _video = _entry('video-1', EntryType.video, mediaId: _videoMedia);
final Entry _note = _entry('note-1', EntryType.text, text: 'Fed the robins.');

FakeNoteMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('day-pop-up');
  addTearDown(() => folder.deleteSync(recursive: true));
  final File voice = File('${folder.path}/voice.m4a')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  final File video = File('${folder.path}/video.mp4')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  return FakeNoteMediaResolver(<String, ResolvedMedia>{
    _voiceMedia: ResolvedMedia.available(
      blob: blobOf(
        id: _voiceMedia,
        relPath: 'voice.m4a',
        kind: MediaKind.audio,
      ),
      file: voice,
    ),
    _videoMedia: ResolvedMedia.available(
      blob: blobOf(
        id: _videoMedia,
        relPath: 'video.mp4',
        kind: MediaKind.video,
      ),
      file: video,
    ),
  })..memoizeAll();
}

Future<void> _pumpPane(
  WidgetTester tester, {
  required Entry entry,
  required Brightness brightness,
}) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final FakeNoteMediaResolver resolver = _resolver();
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final FieldNotesColors colors = brightness == Brightness.dark
      ? FieldNotesColors.dark
      : FieldNotesColors.light;
  final List<Entry> entries = <Entry>[entry];
  final Widget pane = entry.type == EntryType.text
      ? DayNotePane(
          entries: entries,
          selected: entry,
          mood: null,
          dayTitle: 'Sunday',
          resolver: resolver,
          onEdit: (Entry entry) {},
          onDelete: (Entry entry) {},
          onOpenFull: (Entry entry) {},
        )
      : DayMediaPane(
          entries: entries,
          selected: entry,
          date: '2026-07-19',
          dayTitle: 'Sunday',
          mood: null,
          resolver: resolver,
          onDelete: (Entry entry) {},
          onStep: (Entry entry) {},
          onClose: () {},
        );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        todayAudioPlayerFactoryProvider.overrideWithValue(
          FakeEntryAudioPlayer.new,
        ),
        todayVideoPlayerFactoryProvider.overrideWithValue(
          FakeEntryVideoPlayer.new,
        ),
        videoSlotsProvider.overrideWithValue(slots),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: TargetPlatform.macOS,
          brightness: brightness,
        ),
        home: Scaffold(
          body: Center(
            child: ColoredBox(
              color: colors.cardLight,
              child: SizedBox.fromSize(size: _pane, child: pane),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder _under(Key key, Finder matching) =>
    find.descendant(of: find.byKey(key), matching: matching);

Color? _ownFill(Widget widget) => switch (widget) {
  ColoredBox(:final Color color) => color,
  DecoratedBox(decoration: BoxDecoration(:final Color? color)) => color,
  Container(:final Color? color) when color != null => color,
  Container(decoration: BoxDecoration(:final Color? color)) => color,
  _ => null,
};

List<Color> _fillsAround(Finder inner, Key outer) {
  final Finder ancestors = find.ancestor(
    of: inner,
    matching: find.byWidgetPredicate((Widget widget) => true),
  );
  final Set<Element> inside = find
      .descendant(
        of: find.byKey(outer),
        matching: find.byWidgetPredicate((Widget widget) => true),
      )
      .evaluate()
      .toSet();
  return <Color>[
    for (final Element element in ancestors.evaluate())
      if (inside.contains(element))
        if (_ownFill(element.widget) case final Color color)
          if (color.a > 0) color,
  ];
}

void main() {
  testWidgets(
    'the day pop-up plays a voice log with the full view voice player in light and dark',
    (WidgetTester tester) async {
      for (final Brightness brightness in Brightness.values) {
        await _pumpPane(tester, entry: _voice, brightness: brightness);
        final String theme = brightness.name;

        final Finder transport = _under(
          dayMediaPaneKey,
          find.byType(Transport),
        );
        expect(transport, findsOneWidget, reason: theme);
        final Transport player = tester.widget<Transport>(transport);
        expect(player.kind, TransportKind.voice, reason: theme);
        expect(player.mode, TransportMode.viewer, reason: theme);
        expect(player.onBack, isNull, reason: theme);
        expect(player.onMore, isNull, reason: theme);
        for (final Key key in <Key>[
          transportDockBackKey,
          transportDockMoreKey,
          logViewerBackKey,
        ]) {
          expect(_under(dayMediaPaneKey, find.byKey(key)), findsNothing);
        }
        for (final Type chrome in <Type>[
          ViewerStage,
          ViewerLogBar,
          ViewerEdgeArrows,
          WindowDragBand,
        ]) {
          expect(
            _under(dayMediaPaneKey, find.byType(chrome)),
            findsNothing,
            reason: '$chrome in $theme',
          );
        }
        expect(
          _fillsAround(transport, dayMediaPaneKey),
          isEmpty,
          reason: 'a box behind the transport paints its own colour in $theme',
        );
        expect(
          _under(dayMediaPaneKey, find.byType(VoiceWaveform)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the day pop-up header buttons are plain icons in the window ink for every log kind',
    (WidgetTester tester) async {
      for (final Entry entry in <Entry>[_voice, _video, _note]) {
        for (final Brightness brightness in Brightness.values) {
          await _pumpPane(tester, entry: entry, brightness: brightness);
          final String context = '${entry.type.name} in ${brightness.name}';
          final FieldNotesColors colors = brightness == Brightness.dark
              ? FieldNotesColors.dark
              : FieldNotesColors.light;

          expect(find.byKey(dayPaneOpenFullKey), findsOneWidget);
          expect(find.byType(LogActionsPill), findsOneWidget);
          for (final Finder button in <Finder>[
            find.byKey(dayPaneOpenFullKey),
            find.byType(LogActionsPill),
          ]) {
            final List<Color> fills = <Color>[
              for (final Element element
                  in find
                      .descendant(
                        of: button,
                        matching: find.byWidgetPredicate(
                          (Widget widget) => true,
                        ),
                      )
                      .evaluate())
                if (_ownFill(element.widget) case final Color color) color,
            ];
            expect(fills, isNot(contains(Palette.toolbarInk)), reason: context);
          }
          final TransportGlyphIcon glyph = tester.widget<TransportGlyphIcon>(
            _under(dayPaneOpenFullKey, find.byType(TransportGlyphIcon)),
          );
          expect(glyph.glyph, TransportGlyph.fullScreen, reason: context);
          expect(glyph.color, colors.ink, reason: context);
          expect(tester.takeException(), isNull, reason: context);
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
