import 'package:camera/camera.dart' show CameraDescription, CameraLensDirection;
import 'package:field_notes/app/capture/app_capture_routes.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart' show DialogHost;
import 'package:field_notes/design/widgets/widgets.dart'
    show PhoneSheet, StickerCard;
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/audio/cannot_hear_notice.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/chooser/capture_routes_provider.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart'
    show composerPanelKey;
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/immersive/stage_phase.dart'
    show stagePausedStatus;
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
import 'package:field_notes/state/settings_providers.dart'
    show reflectionPromptsEnabledProvider;
import 'package:field_notes/state/state.dart' show journalRepositoryProvider;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/capture/core/capture_test_support.dart'
    show FakeDraftStore, FakeNoteWriter, draftIdleDebounceForTest;
import '../../features/capture/photo/photo_test_support.dart'
    show FakePhotoPicker;
import '../../features/capture/video/video_test_support.dart'
    show FakeVideoRecorder, fakeVideoDevices;
import '../../features/capture/voice/voice_test_support.dart'
    show FakeCaptureService, FakeVoiceRecorder;
import '../../features/day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
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

const double _keyboardInset = 300;

const String _today = '2026-09-18';
const String _launcherLabel = 'open';
const Key _launcherKey = ValueKey<String>('capture-launcher');
const double _launcherSize = 48;
const String _noteText = 'A quiet morning by the harbour.';
const String _crashDraft = 'left by a crash';
const String _selectionNote = 'The harbour was quiet.';
const int _insideHarbour = 8;
const String _tableNote =
    'Intro\n\n| a | b |\n| --- | --- |\n| c | d |\n| e | f |\n\nOutro';
const int _insideTable = 34;

const Duration _photoHold = Duration(milliseconds: 110);
const Duration _longPressHold = Duration(milliseconds: 600);
const Duration _recorderOpen = Duration(milliseconds: 250);
const Duration _recorderStep = Duration(milliseconds: 50);
const Duration _recorderSettle = Duration(milliseconds: 500);
const Duration _letGoOpen = Duration(milliseconds: 300);
const int _shutterSteps = 4;

DateTime _clock() => DateTime(2026, 9, 18, 9, 30);

final List<VideoCaptureDevice> _phoneCameras = cameraDeviceLabels(
  const <CameraDescription>[
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
  ],
);

typedef _Open = Future<Object?> Function(BuildContext context, WidgetRef ref);

class _Launcher extends ConsumerWidget {
  const _Launcher(this.open);

  final _Open open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      key: _launcherKey,
      behavior: HitTestBehavior.opaque,
      onTap: () async => open(context, ref),
      child: Semantics(
        button: true,
        label: _launcherLabel,
        child: const SizedBox.square(dimension: _launcherSize),
      ),
    );
  }
}

void _useSurface(
  WidgetTester tester,
  A11yVariant variant, {
  double keyboard = 0,
}) {
  variant.useWindow(tester);
  tester.view.viewInsets = FakeViewPadding(
    bottom: variant.desktop ? 0 : keyboard * variant.window.devicePixelRatio,
  );
}

Widget _harness(A11yVariant variant, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: variant.theme,
  builder: variant.scaleText,
  home: Scaffold(body: Center(child: child)),
);

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
  await tester.tap(find.byKey(_launcherKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpChooser(WidgetTester tester, A11yVariant variant) async {
  _useSurface(tester, variant);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _composerOverrides(
        extra: <Override>[
          captureRoutesProvider.overrideWithValue(appCaptureRoutes),
        ],
      ),
      child: _harness(
        variant,
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
  WidgetTester tester,
  A11yVariant variant, {
  FakeDraftStore? drafts,
  List<Override> extra = const <Override>[],
  double keyboard = 0,
}) async {
  _useSurface(tester, variant, keyboard: keyboard);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _composerOverrides(drafts: drafts, extra: extra),
      child: _harness(
        variant,
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
  A11yVariant variant,
  String text, {
  List<Override> extra = const <Override>[],
  double keyboard = 0,
}) async {
  await _openComposer(tester, variant, extra: extra, keyboard: keyboard);
  await NoteEditorDriver(tester).enterText(text);
  await tester.pump(draftIdleDebounceForTest);
  await tester.pumpAndSettle();
}

Future<void> _pumpNewComposer(WidgetTester tester, A11yVariant variant) =>
    _composeNote(tester, variant, _noteText);

Future<void> _pumpComposerWithKeyboard(
  WidgetTester tester,
  A11yVariant variant,
) => _composeNote(tester, variant, _noteText, keyboard: _keyboardInset);

Future<void> _pumpMoreFormats(WidgetTester tester, A11yVariant variant) async {
  await _pumpComposerWithKeyboard(tester, variant);
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

Future<void> _pumpEditNote(WidgetTester tester, A11yVariant variant) async {
  _useSurface(tester, variant);
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
      child: _harness(
        variant,
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              showEditNote(context, entry: entry, date: _today),
        ),
      ),
    ),
  );
  await _launch(tester);
}

Future<void> _pumpPhotoSelected(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _composeNote(
    tester,
    variant,
    'one\n${mdPhotoLine(photoIdA)}\ntwo',
    extra: <Override>[_photoResolver()],
  );
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.press(driver.photoFinder(0), _photoHold);
  await tester.pump();
}

Future<void> _pumpPhotoCaption(WidgetTester tester, A11yVariant variant) async {
  await _pumpPhotoSelected(tester, variant);
  await NoteEditorDriver(tester)
      .press(find.byKey(photoToolbarCaptionKey), _photoHold);
  await tester.pump();
}

Future<void> _pumpPhotoRemoved(WidgetTester tester, A11yVariant variant) async {
  await _pumpPhotoSelected(tester, variant);
  await NoteEditorDriver(tester)
      .press(find.byKey(photoToolbarRemoveKey), _photoHold);
  await tester.pumpAndSettle();
}

Future<void> _pumpTableToolbar(WidgetTester tester, A11yVariant variant) async {
  await _composeNote(tester, variant, _tableNote);
  await NoteEditorDriver(tester)
      .setSelection(const TextSelection.collapsed(offset: _insideTable));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(tableToolbarAlignLeftKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpSelectionMenu(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _composeNote(tester, variant, _selectionNote);
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

Future<void> _pumpDiscardNote(WidgetTester tester, A11yVariant variant) async {
  await _pumpNewComposer(tester, variant);
  await tester.tap(find.byKey(composerCloseKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpDraftChip(WidgetTester tester, A11yVariant variant) async {
  await _openComposer(
    tester,
    variant,
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

Future<void> _openVoice(
  WidgetTester tester,
  A11yVariant variant, {
  MicrophoneHearing hearing = MicrophoneHearing.hearing,
}) async {
  _useSurface(tester, variant);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        todayClockProvider.overrideWithValue(_clock),
        voiceRecorderProvider.overrideWith(
          (Ref ref) => FakeVoiceRecorder()..hearingNow = hearing,
        ),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: _harness(
        variant,
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              showVoiceComposer(context, _today),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_launcherKey));
  await tester.pump();
  await tester.pump(_recorderOpen);
}

Future<void> _tapRecord(WidgetTester tester) async {
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.pump(_recorderStep);
  await tester.pump(_recorderSettle);
}

Future<void> _pumpVoiceIdle(WidgetTester tester, A11yVariant variant) async {
  await _openVoice(tester, variant);
  await tester.pump(_recorderSettle);
  _requireVoicePhase(tester, VoiceRecorderPhase.idle);
}

Future<void> _pumpVoiceRecording(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVoice(tester, variant);
  await _tapRecord(tester);
  _requireVoicePhase(tester, VoiceRecorderPhase.breathing);
  await _tapRecord(tester);
  _requireVoicePhase(tester, VoiceRecorderPhase.recording);
}

Future<void> _pumpVoicePaused(WidgetTester tester, A11yVariant variant) async {
  await _pumpVoiceRecording(tester, variant);
  await _tapRecord(tester);
  _requireVoicePhase(tester, VoiceRecorderPhase.paused);
}

Future<void> _pumpDiscardRecording(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _pumpVoiceRecording(tester, variant);
  await tester.tap(find.byKey(voiceDiscardPillKey));
  await tester.pump();
  await tester.pump(_letGoOpen);
  _requireVoicePhase(tester, VoiceRecorderPhase.paused);
}

Future<void> _openVideo(
  WidgetTester tester,
  A11yVariant variant, {
  bool cameras = true,
}) async {
  _useSurface(tester, variant);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        todayClockProvider.overrideWithValue(_clock),
        videoRecorderProvider.overrideWith(
          (Ref ref) => FakeVideoRecorder(
            devices: switch ((cameras, variant.desktop)) {
              (false, _) => const <VideoCaptureDevice>[],
              (true, true) => fakeVideoDevices,
              (true, false) => _phoneCameras,
            },
            supportsPause: true,
          ),
        ),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: _harness(
        variant,
        _Launcher(
          (BuildContext context, WidgetRef ref) =>
              showVideoComposer(context, _today),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_launcherKey));
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

Future<void> _pumpVideoIdle(WidgetTester tester, A11yVariant variant) async {
  await _openVideo(tester, variant);
  await tester.pump(_recorderSettle);
  _requireVideoPhase(tester, VideoRecorderPhase.idle);
}

Future<void> _pumpVideoNoCamera(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVideo(tester, variant, cameras: false);
  await tester.pump(_recorderSettle);
  _requireVideoPhase(tester, VideoRecorderPhase.denied);
}

Future<void> _pumpVoiceCannotHear(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _openVoice(tester, variant, hearing: MicrophoneHearing.cannotHear);
  await tester.pump(_recorderSettle);
  _requireVoicePhase(tester, VoiceRecorderPhase.idle);
}

Future<void> _pumpVideoRecording(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _pumpVideoIdle(tester, variant);
  await _tapShutter(tester);
  _requireVideoPhase(tester, VideoRecorderPhase.breathing);
  await _tapShutter(tester);
  _requireVideoPhase(tester, VideoRecorderPhase.recording);
}

Future<void> _pumpVideoPaused(WidgetTester tester, A11yVariant variant) async {
  await _pumpVideoRecording(tester, variant);
  await _tapShutter(tester);
  _requireVideoPhase(tester, VideoRecorderPhase.paused);
}

final Finder _fullScreenComposer = find.byElementPredicate(
  (Element element) =>
      element.widget.key == composerPanelKey &&
      switch (element.renderObject) {
        final RenderBox box when box.hasSize =>
          box.size == MediaQuery.sizeOf(element),
        _ => false,
      },
  description: 'the composer filling the phone screen',
);

final Finder _panelComposer = find.byElementPredicate(
  (Element element) =>
      element.widget.key == composerPanelKey &&
      switch (element.renderObject) {
        final RenderBox box when box.hasSize =>
          box.size.width < MediaQuery.sizeOf(element).width,
        _ => false,
      },
  description: 'the composer as a panel narrower than the desktop window',
);

final Finder _desktopChooser = find.descendant(
  of: find.byType(DialogHost),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is CaptureChooserSheet && widget.layout == ShellLayout.sidebar,
  ),
);

List<A11yStatefulControl> _selectedControls(Iterable<Key> keys) =>
    <A11yStatefulControl>[
      for (final Key key in keys)
        A11yStatefulControl.finder(find.byKey(key), A11yStateKind.selected),
    ];

final List<A11yState> captureStates = <A11yState>[
  ...a11yInBothLayouts(
    id: 'c1-chooser',
    desktopId: 'c1-chooser-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpChooser,
      proof: <A11yProof>[
        A11yProof(
          find.descendant(
            of: find.byType(CaptureChooserSheet),
            matching: find.byType(PhoneSheet),
          ),
        ),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpChooser,
      proof: <A11yProof>[A11yProof(_desktopChooser)],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'c2-composer-new',
    desktopId: 'c2-composer-new-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpNewComposer,
      proof: <A11yProof>[
        A11yProof(find.byType(TextComposerSheet)),
        A11yProof(_fullScreenComposer),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpNewComposer,
      proof: <A11yProof>[
        A11yProof(find.byType(TextComposerSheet)),
        A11yProof(_panelComposer),
      ],
    ),
  ),
  A11yState(
    id: 'c3-composer-keyboard',
    platforms: const <TargetPlatform>{TargetPlatform.android},
    pump: _pumpComposerWithKeyboard,
    proof: <A11yProof>[
      A11yProof(find.byType(TextComposerSheet)),
      A11yProof(_fullScreenComposer),
    ],
  ),
  A11yState(
    id: 'c4-more-formats',
    pump: _pumpMoreFormats,
    proof: <A11yProof>[A11yProof(find.byKey(formatStrikethroughKey))],
  ),
  ...a11yInBothLayouts(
    id: 'c5-edit-note',
    desktopId: 'c5-edit-note-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpEditNote,
      proof: <A11yProof>[
        A11yProof(find.text(editNoteSaveLabel)),
        A11yProof(_fullScreenComposer),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpEditNote,
      proof: <A11yProof>[
        A11yProof(find.text(editNoteSaveLabel)),
        A11yProof(_panelComposer),
      ],
    ),
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
  ...a11yInBothLayouts(
    id: 'c10-discard-dialog',
    desktopId: 'c10-discard-dialog-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpDiscardNote,
      proof: <A11yProof>[
        A11yProof(
          find.descendant(
            of: find.byType(PhoneSheet),
            matching: find.byKey(composerDiscardKey),
          ),
        ),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpDiscardNote,
      proof: <A11yProof>[
        A11yProof(
          find.descendant(
            of: find.byType(StickerCard),
            matching: find.byKey(composerDiscardKey),
          ),
        ),
      ],
    ),
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
    proof: <A11yProof>[A11yProof(find.text(stagePausedStatus))],
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
  A11yState(
    id: 'c20-video-no-camera',
    pump: _pumpVideoNoCamera,
    proof: <A11yProof>[A11yProof(find.byKey(videoTryAgainKey))],
  ),
  A11yState(
    id: 'c21-voice-cannot-hear',
    pump: _pumpVoiceCannotHear,
    proof: <A11yProof>[A11yProof(find.byKey(cannotHearNoticeKey))],
  ),
];
