import 'package:camera/camera.dart' show CameraDescription, CameraLensDirection;
import 'package:field_notes/app/capture/app_capture_routes.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/chooser/capture_routes_provider.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart'
    show cameraDeviceLabels;
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/photo_caption_field.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart'
    show VideoCaptureDevice;
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/toolbars/table_toolbar.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:field_notes/state/state.dart' show journalRepositoryProvider;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/capture/core/capture_test_support.dart'
    show
        FakeDraftStore,
        FakeNoteWriter,
        captureHarness,
        draftIdleDebounceForTest;
import '../../features/capture/photo/photo_test_support.dart'
    show FakePhotoPicker;
import '../../features/capture/video/video_test_support.dart'
    show FakeVideoRecorder, videoHarness;
import '../../features/capture/voice/voice_test_support.dart'
    show FakeCaptureService, FakeVoiceRecorder, voiceHarness;
import '../../features/day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository, dayDetailHarness;
import '../../features/notes/support/notes_harness.dart'
    show
        FakeNoteMediaResolver,
        FakeNoteMediaStore,
        availablePhoto,
        photoIdA,
        prefixOf;
import '../../support/note_editor_driver.dart';
import '../../support/photo_line_fixture.dart';
import '../support/a11y_state.dart';

const Size _galaxySurface = Size(1080, 2280);
const double _galaxyPixelRatio = 2.625;
const double _keyboardInset = 300;

const String _today = '2026-09-18';
const String _launcherLabel = 'open';
const String _noteText = 'A quiet morning by the harbour.';
const String _crashDraft = 'left by a crash';
const String _selectionNote = 'The harbour was quiet.';
const int _insideHarbour = 8;
const String _tableNote =
    'Intro\n\n| a | b |\n| --- | --- |\n| c | d |\n| e | f |\n\nOutro';
const int _insideTable = 34;
const String _voicePausedHint = 'paused · resume when you’re ready';

const Duration _photoHold = Duration(milliseconds: 110);
const Duration _longPressHold = Duration(milliseconds: 600);
const Duration _recorderOpen = Duration(milliseconds: 250);
const Duration _recorderStep = Duration(milliseconds: 50);
const Duration _recorderSettle = Duration(milliseconds: 500);
const Duration _dialogOpen = Duration(milliseconds: 300);
const int _shutterSteps = 4;

DateTime _clock() => DateTime(2026, 9, 18, 9, 30);

final List<VideoCaptureDevice> _phoneCameras =
    cameraDeviceLabels(const <CameraDescription>[
      CameraDescription(
        name: '0',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      CameraDescription(
        name: '1',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ]);

typedef _Open = Future<Object?> Function(BuildContext context, WidgetRef ref);

class _Launcher extends ConsumerWidget {
  const _Launcher(this.open);

  final _Open open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => open(context, ref),
      child: const Text(_launcherLabel),
    );
  }
}

void _useGalaxySurface(WidgetTester tester, {double keyboard = 0}) {
  tester.view.physicalSize = _galaxySurface;
  tester.view.devicePixelRatio = _galaxyPixelRatio;
  tester.view.viewInsets = FakeViewPadding(
    bottom: keyboard * _galaxyPixelRatio,
  );
  addTearDown(tester.view.reset);
}

List<Override> _composerOverrides({
  FakeDraftStore? drafts,
  List<Override> extra = const <Override>[],
}) {
  return <Override>[
    todayClockProvider.overrideWithValue(_clock),
    noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
    draftStoreProvider.overrideWith((Ref ref) => drafts ?? FakeDraftStore()),
    mediaStoreProvider.overrideWith((Ref ref) async => FakeNoteMediaStore()),
    notePhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
    ...extra,
  ];
}

Override _photoResolver() => notesMediaResolverProvider.overrideWith(
  (Ref ref) async => FakeNoteMediaResolver(<String, ResolvedMedia>{
    prefixOf(photoIdA): availablePhoto(photoIdA, width: 1200, height: 900),
  })..memoizeAll(),
);

Future<void> _launch(WidgetTester tester) async {
  await tester.tap(find.text(_launcherLabel));
  await tester.pumpAndSettle();
}

Future<void> _pumpChooser(WidgetTester tester) async {
  _useGalaxySurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _composerOverrides(
        extra: <Override>[
          captureRoutesProvider.overrideWithValue(appCaptureRoutes),
        ],
      ),
      child: captureHarness(
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              openCapture(context, ref, date: _today),
        ),
      ),
    ),
  );
  await _launch(tester);
}

Future<void> _openComposer(
  WidgetTester tester, {
  FakeDraftStore? drafts,
  List<Override> extra = const <Override>[],
  double keyboard = 0,
}) async {
  _useGalaxySurface(tester, keyboard: keyboard);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _composerOverrides(drafts: drafts, extra: extra),
      child: captureHarness(
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              showTextComposer(context, _today),
        ),
      ),
    ),
  );
  await _launch(tester);
}

Future<void> _composeNote(
  WidgetTester tester,
  String text, {
  List<Override> extra = const <Override>[],
  double keyboard = 0,
}) async {
  await _openComposer(tester, extra: extra, keyboard: keyboard);
  await NoteEditorDriver(tester).enterText(text);
  await tester.pump(draftIdleDebounceForTest);
  await tester.pumpAndSettle();
}

Future<void> _pumpNewComposer(WidgetTester tester) =>
    _composeNote(tester, _noteText);

Future<void> _pumpComposerWithKeyboard(WidgetTester tester) =>
    _composeNote(tester, _noteText, keyboard: _keyboardInset);

Future<void> _pumpMoreFormats(WidgetTester tester) async {
  await _pumpComposerWithKeyboard(tester);
  await tester.ensureVisible(find.byKey(formatMoreKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(formatMoreKey));
  await tester.pumpAndSettle();
}

Entry _savedNote() => Entry(
  id: 'entry-1',
  dayId: 'day-1',
  type: EntryType.text,
  textContent: _noteText,
  createdAt: _clock().millisecondsSinceEpoch,
  updatedAt: 0,
);

Future<void> _pumpEditNote(WidgetTester tester) async {
  _useGalaxySurface(tester);
  final Entry entry = _savedNote();
  await tester.pumpWidget(
    ProviderScope(
      overrides: _composerOverrides(
        extra: <Override>[
          journalRepositoryProvider.overrideWithValue(
            FakeJournalRepository(entries: <Entry>[entry]),
          ),
        ],
      ),
      child: dayDetailHarness(
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              showEditNote(context, entry: entry, date: _today),
        ),
      ),
    ),
  );
  await _launch(tester);
}

Future<void> _pumpPhotoSelected(WidgetTester tester) async {
  await _composeNote(
    tester,
    'one\n${mdPhotoLine(photoIdA)}\ntwo',
    extra: <Override>[_photoResolver()],
  );
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.press(driver.photoFinder(0), _photoHold);
  await tester.pump();
}

Future<void> _pumpPhotoCaption(WidgetTester tester) async {
  await _pumpPhotoSelected(tester);
  await NoteEditorDriver(
    tester,
  ).press(find.byKey(photoToolbarCaptionKey), _photoHold);
  await tester.pump();
}

Future<void> _pumpPhotoRemoved(WidgetTester tester) async {
  await _pumpPhotoSelected(tester);
  await NoteEditorDriver(
    tester,
  ).press(find.byKey(photoToolbarRemoveKey), _photoHold);
  await tester.pumpAndSettle();
}

Future<void> _pumpTableToolbar(WidgetTester tester) async {
  await _composeNote(tester, _tableNote);
  await NoteEditorDriver(
    tester,
  ).setSelection(const TextSelection.collapsed(offset: _insideTable));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(tableToolbarAlignLeftKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpSelectionMenu(WidgetTester tester) async {
  await _composeNote(tester, _selectionNote);
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.setSelection(
    const TextSelection.collapsed(offset: _insideHarbour),
  );
  final TestGesture gesture = await tester.startGesture(
    driver.caretRect.center,
    kind: PointerDeviceKind.touch,
  );
  await tester.pump(_longPressHold);
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _pumpDiscardNote(WidgetTester tester) async {
  await _pumpNewComposer(tester);
  await tester.tap(find.byKey(composerCloseKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpDraftChip(WidgetTester tester) async {
  await _openComposer(
    tester,
    drafts: FakeDraftStore(
      drafts: <String, String>{'new-$_today': _crashDraft},
    ),
  );
}

void _requireVoicePhase(WidgetTester tester, VoiceRecorderPhase phase) {
  final VoiceRecorderPhase shown = tester
      .widget<VoiceRecorderSheet>(find.byType(VoiceRecorderSheet))
      .phase;
  if (shown != phase) {
    throw StateError('the voice recorder shows $shown, not $phase');
  }
}

void _requireVideoPhase(WidgetTester tester, VideoRecorderPhase phase) {
  final VideoRecorderPhase shown = tester
      .widget<VideoRecorderSheet>(find.byType(VideoRecorderSheet))
      .phase;
  if (shown != phase) {
    throw StateError('the video recorder shows $shown, not $phase');
  }
}

Future<void> _openVoice(WidgetTester tester) async {
  _useGalaxySurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        todayClockProvider.overrideWithValue(_clock),
        voiceRecorderProvider.overrideWith((Ref ref) => FakeVoiceRecorder()),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
      ],
      child: voiceHarness(
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              showVoiceComposer(context, _today),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_launcherLabel));
  await tester.pump();
  await tester.pump(_recorderOpen);
}

Future<void> _tapRecord(WidgetTester tester) async {
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.pump(_recorderStep);
  await tester.pump(_recorderSettle);
}

Future<void> _pumpVoiceIdle(WidgetTester tester) async {
  await _openVoice(tester);
  await tester.pump(_recorderSettle);
  _requireVoicePhase(tester, VoiceRecorderPhase.idle);
}

Future<void> _pumpVoiceRecording(WidgetTester tester) async {
  await _openVoice(tester);
  await _tapRecord(tester);
  _requireVoicePhase(tester, VoiceRecorderPhase.recording);
}

Future<void> _pumpVoicePaused(WidgetTester tester) async {
  await _pumpVoiceRecording(tester);
  await _tapRecord(tester);
  _requireVoicePhase(tester, VoiceRecorderPhase.paused);
}

Future<void> _pumpDiscardRecording(WidgetTester tester) async {
  await _pumpVoiceRecording(tester);
  await tester.tap(find.byKey(voiceDiscardPillKey));
  await tester.pump();
  await tester.pump(_dialogOpen);
}

Future<void> _openVideo(WidgetTester tester) async {
  _useGalaxySurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        todayClockProvider.overrideWithValue(_clock),
        videoRecorderProvider.overrideWith(
          (Ref ref) =>
              FakeVideoRecorder(devices: _phoneCameras, supportsPause: true),
        ),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
      ],
      child: videoHarness(
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              showVideoComposer(context, _today),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_launcherLabel));
  await tester.pump();
  await tester.pump(_recorderOpen);
}

Future<void> _tapShutter(WidgetTester tester) async {
  await tester.tap(find.byKey(videoShutterKey));
  for (int i = 0; i < _shutterSteps; i++) {
    await tester.pump(_recorderStep);
  }
  await tester.pump(_recorderSettle);
}

Future<void> _pumpVideoIdle(WidgetTester tester) async {
  await _openVideo(tester);
  await tester.pump(_recorderSettle);
  _requireVideoPhase(tester, VideoRecorderPhase.idle);
}

Future<void> _pumpVideoRecording(WidgetTester tester) async {
  await _openVideo(tester);
  await _tapShutter(tester);
  _requireVideoPhase(tester, VideoRecorderPhase.recording);
}

Future<void> _pumpVideoPaused(WidgetTester tester) async {
  await _pumpVideoRecording(tester);
  await _tapShutter(tester);
  _requireVideoPhase(tester, VideoRecorderPhase.paused);
}

List<A11yStatefulControl> _selectedControls(Iterable<Key> keys) =>
    <A11yStatefulControl>[
      for (final Key key in keys)
        A11yStatefulControl.finder(find.byKey(key), A11yStateKind.selected),
    ];

final List<A11yState> captureStates = <A11yState>[
  A11yState(
    id: 'c1-chooser',
    pump: _pumpChooser,
    proof: <A11yProof>[A11yProof(find.byType(CaptureChooserSheet))],
  ),
  A11yState(
    id: 'c2-composer-new',
    pump: _pumpNewComposer,
    proof: <A11yProof>[A11yProof(find.byType(TextComposerSheet))],
  ),
  A11yState(
    id: 'c3-composer-keyboard',
    pump: _pumpComposerWithKeyboard,
    proof: <A11yProof>[A11yProof(find.byType(TextComposerSheet))],
  ),
  A11yState(
    id: 'c4-more-formats',
    pump: _pumpMoreFormats,
    proof: <A11yProof>[A11yProof(find.byKey(formatStrikethroughKey))],
  ),
  A11yState(
    id: 'c5-edit-note',
    pump: _pumpEditNote,
    proof: <A11yProof>[A11yProof(find.text(editNoteSaveLabel))],
  ),
  A11yState(
    id: 'c6-photo-selected',
    pump: _pumpPhotoSelected,
    proof: <A11yProof>[A11yProof(find.byType(PhotoToolbar))],
  ),
  A11yState(
    id: 'c7-photo-caption',
    pump: _pumpPhotoCaption,
    proof: <A11yProof>[A11yProof(find.byType(PhotoCaptionField))],
  ),
  A11yState(
    id: 'c8-table-toolbar',
    pump: _pumpTableToolbar,
    proof: <A11yProof>[A11yProof(find.byType(TableToolbar))],
    stateful: _selectedControls(const <Key>[
      tableToolbarAlignLeftKey,
      tableToolbarAlignCentreKey,
      tableToolbarAlignRightKey,
    ]),
  ),
  A11yState(
    id: 'c9-selection-menu',
    pump: _pumpSelectionMenu,
    proof: <A11yProof>[A11yProof(find.text('Copy'))],
  ),
  A11yState(
    id: 'c10-discard-dialog',
    pump: _pumpDiscardNote,
    proof: <A11yProof>[A11yProof(find.byKey(composerDiscardKey))],
  ),
  A11yState(
    id: 'c11-draft-chip',
    pump: _pumpDraftChip,
    proof: <A11yProof>[A11yProof(find.byType(DraftRestoredChip))],
  ),
  A11yState(
    id: 'c12-voice-idle',
    pump: _pumpVoiceIdle,
    proof: <A11yProof>[A11yProof(find.byType(VoiceRecorderSheet))],
  ),
  A11yState(
    id: 'c13-voice-recording',
    pump: _pumpVoiceRecording,
    proof: <A11yProof>[A11yProof(find.byType(VoiceRecorderSheet))],
  ),
  A11yState(
    id: 'c14-voice-paused',
    pump: _pumpVoicePaused,
    proof: <A11yProof>[A11yProof(find.text(_voicePausedHint))],
  ),
  A11yState(
    id: 'c15-video-idle',
    pump: _pumpVideoIdle,
    proof: <A11yProof>[A11yProof(find.byType(VideoRecorderSheet))],
  ),
  A11yState(
    id: 'c16-video-recording',
    pump: _pumpVideoRecording,
    proof: <A11yProof>[A11yProof(find.byType(VideoRecorderSheet))],
  ),
  A11yState(
    id: 'c17-video-paused',
    pump: _pumpVideoPaused,
    proof: <A11yProof>[A11yProof(find.byType(VideoRecorderSheet))],
  ),
  A11yState(
    id: 'c18-discard-recording',
    pump: _pumpDiscardRecording,
    proof: <A11yProof>[A11yProof(find.byKey(voiceDiscardConfirmKey))],
  ),
  A11yState(
    id: 'c19-photo-removed-toast',
    pump: _pumpPhotoRemoved,
    proof: <A11yProof>[A11yProof(find.text(photoRemovedUndoLabel))],
  ),
];
