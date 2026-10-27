import 'dart:io';

import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/note_photos.dart';
import 'package:field_notes/features/entry_cards/cards/video_scrubber.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/media/live_media.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/photo_viewer.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../features/entry_cards/support/fake_video_player.dart';
import '../../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver;
import '../support/a11y_state.dart';
import 'viewer_states.dart' show openA11yViewer;

final DateTime _now = DateTime(2026, 9, 18, 9, 30);
const String _videoId = 'video-1';
const String _posterId = 'poster-1';
const String _photoId = 'a1b2c3d4e5f6';
const String _launchLabel = 'open';
const String _dayTitle = 'Friday, September 18';
const String _videoUnavailable = "Can't play this video";
const String _voiceUnavailable = "Can't play this recording";
const int _megabyte = 1024 * 1024;
const int _videoDurationMs = 64000;
const Duration _decodeStep = Duration(milliseconds: 40);
const int _decodeRounds = 8;

const MediaDownloadProgress _threeOfTwelve = MediaDownloadProgress(
  blobId: _videoId,
  received: 3 * _megabyte,
  total: 12 * _megabyte,
);

final img.Color _pureBlack = img.ColorRgb8(0, 0, 0);
final img.Color _pureWhite = img.ColorRgb8(255, 255, 255);
final img.Color _harbourGrey = img.ColorRgb8(120, 128, 136);

Entry _video({String? thumbnailMediaId}) => Entry(
  id: 'entry-1',
  dayId: 'day-1',
  type: EntryType.video,
  mediaId: _videoId,
  thumbnailMediaId: thumbnailMediaId,
  durationMs: _videoDurationMs,
  createdAt: _now.millisecondsSinceEpoch,
  updatedAt: 0,
);

MediaBlob _blob(String id, MediaKind kind, String mime) => MediaBlob(
  id: id,
  relPath: '$id.bin',
  mime: mime,
  kind: kind,
  bytes: 4,
  createdAt: 0,
);

Directory _scratch() {
  final Directory dir = Directory.systemTemp.createTempSync('media_sweep');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}

File _png(img.Color fill, {int width = 8, int height = 6}) {
  final File file = File('${_scratch().path}/still.png');
  file.writeAsBytesSync(
    img.encodePng(
      img.fill(
        img.Image(width: width, height: height),
        color: fill,
      ),
    ),
  );
  return file;
}

File _clip() {
  final File file = File('${_scratch().path}/clip.mp4');
  file.writeAsBytesSync(List<int>.filled(8, 0));
  return file;
}

ResolvedMedia _available(String id, MediaKind kind, String mime, File file) =>
    ResolvedMedia.available(blob: _blob(id, kind, mime), file: file);

final class _DownloadingResolver implements MediaResolver, LiveMedia {
  _DownloadingResolver(this._poster);

  final ResolvedMedia _poster;

  @override
  ResolvedMedia? resolved(String? mediaId) =>
      mediaId == _posterId ? _poster : null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async =>
      mediaId == _posterId ? _poster : const ResolvedMedia.missing();

  @override
  Stream<String> get arrivals => const Stream<String>.empty();

  @override
  Stream<MediaDownloadProgress>? downloadProgress(String mediaId) =>
      mediaId == _videoId
      ? Stream<MediaDownloadProgress>.value(_threeOfTwelve)
      : null;
}

final class _FailingResolver implements MediaResolver {
  const _FailingResolver();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) =>
      Future<ResolvedMedia>.error(FileSystemException('unreadable', mediaId));
}

Future<void> _decode(WidgetTester tester) async {
  for (int round = 0; round < _decodeRounds; round++) {
    await tester.runAsync(() => Future<void>.delayed(_decodeStep));
    await tester.pump();
  }
}

Future<void> _pumpDownload(
  WidgetTester tester,
  A11yVariant variant,
  img.Color poster,
) async {
  await openA11yViewer(
    tester,
    variant,
    entry: _video(thumbnailMediaId: _posterId),
    resolver: _DownloadingResolver(
      _available(_posterId, MediaKind.photo, 'image/png', _png(poster)),
    ),
  );
  await _decode(tester);
}

Future<void> _pumpVideoControls(
  WidgetTester tester,
  A11yVariant variant,
) async {
  final FakeEntryVideoPlayer player = FakeEntryVideoPlayer()
    ..duration = const Duration(milliseconds: _videoDurationMs);
  await openA11yViewer(
    tester,
    variant,
    entry: _video(),
    resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
      _videoId: _available(_videoId, MediaKind.video, 'video/mp4', _clip()),
    }),
    videoPlayer: () => player,
  );
  player
    ..emitState(VideoPlaybackState.ready)
    ..emitState(VideoPlaybackState.paused)
    ..emitPosition(const Duration(seconds: 21));
  await tester.pump();
}

Future<void> _pumpVoiceUnavailable(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await openA11yViewer(
    tester,
    variant,
    entry: Entry(
      id: 'entry-1',
      dayId: 'day-1',
      type: EntryType.voice,
      mediaId: 'voice-1',
      durationMs: 65000,
      createdAt: _now.millisecondsSinceEpoch,
      updatedAt: 0,
    ),
    resolver: FakeNoteMediaResolver(),
  );
  await tester.pump();
}

Future<void> _pumpVideoError(WidgetTester tester, A11yVariant variant) async {
  await openA11yViewer(
    tester,
    variant,
    entry: _video(),
    resolver: FakeNoteMediaResolver(),
  );
  await tester.pump();
}

class _PhotoLauncher extends StatelessWidget {
  const _PhotoLauncher({required this.resolver});

  final MediaResolver resolver;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showPhotoViewer(
          context,
          photos: const <NotePhoto>[
            NotePhoto(reference: _photoId, caption: 'The harbour wall'),
            NotePhoto(reference: 'b2c3d4e5f6a1', caption: ''),
          ],
          initialIndex: 0,
          dayTitle: _dayTitle,
          resolver: resolver,
        ),
        child: const Text(_launchLabel),
      ),
    );
  }
}

Future<void> _pumpPhotoViewer(
  WidgetTester tester,
  A11yVariant variant,
  MediaResolver Function() resolver,
) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: variant.theme,
      builder: variant.scaleText,
      home: _PhotoLauncher(resolver: resolver()),
    ),
  );
  await tester.tap(find.text(_launchLabel));
  await tester.pumpAndSettle();
  await _decode(tester);
}

MediaResolver _photoResolver() => FakeNoteMediaResolver(<String, ResolvedMedia>{
  _photoId: _available(
    _photoId,
    MediaKind.photo,
    'image/png',
    _png(_harbourGrey, width: 12, height: 8),
  ),
})..memoizeAll();

Finder _inViewer(Finder matching) =>
    find.descendant(of: find.byType(LogViewerPanel), matching: matching);

final Finder _downloadCaption = _inViewer(find.textContaining('downloading'));

final List<A11yState> mediaStates = <A11yState>[
  A11yState(
    id: 'm1-video-download-black-poster',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpDownload(tester, variant, _pureBlack),
    proof: <A11yProof>[
      A11yProof(_inViewer(find.byType(VideoViewerView))),
      A11yProof(_downloadCaption),
    ],
  ),
  A11yState(
    id: 'm2-video-download-white-poster',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpDownload(tester, variant, _pureWhite),
    proof: <A11yProof>[
      A11yProof(_inViewer(find.byType(VideoViewerView))),
      A11yProof(_downloadCaption),
    ],
  ),
  A11yState(
    id: 'm3-video-controls',
    pump: _pumpVideoControls,
    proof: <A11yProof>[
      A11yProof(_inViewer(find.byType(ViewerPrimaryButton))),
      A11yProof(_inViewer(find.byType(VideoScrubber))),
      A11yProof(_inViewer(find.text('0:21'))),
    ],
  ),
  A11yState(
    id: 'm4-photo-viewer',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpPhotoViewer(tester, variant, _photoResolver),
    proof: <A11yProof>[
      A11yProof(find.byType(PhotoViewer)),
      A11yProof(
        find.descendant(
          of: find.byType(PhotoViewer),
          matching: find.byType(RawImage),
        ),
      ),
    ],
  ),
  A11yState(
    id: 'm5-photo-error',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpPhotoViewer(tester, variant, () => const _FailingResolver()),
    proof: <A11yProof>[
      A11yProof(find.byType(PhotoViewer)),
      A11yProof(
        find.descendant(
          of: find.byType(PhotoViewer),
          matching: find.byType(CorruptMediaPlaceholder),
        ),
      ),
    ],
  ),
  A11yState(
    id: 'm6-video-error',
    pump: _pumpVideoError,
    proof: <A11yProof>[
      A11yProof(_inViewer(find.byType(VideoViewerView))),
      A11yProof(_inViewer(find.text(_videoUnavailable))),
    ],
  ),
  A11yState(
    id: 'm7-voice-unavailable',
    pump: _pumpVoiceUnavailable,
    proof: <A11yProof>[
      A11yProof(_inViewer(find.byType(VoicePlayerView))),
      A11yProof(_inViewer(find.text(_voiceUnavailable))),
    ],
  ),
];
