import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_editor_driver.dart';
import '../../../support/photo_line_fixture.dart';
import '../../notes/support/notes_harness.dart'
    show
        FakeNoteMediaResolver,
        FakeNoteMediaStore,
        availablePhoto,
        photoIdA,
        prefixOf;
import '../core/capture_test_support.dart'
    show
        FakeDraftStore,
        FakeNoteWriter,
        captureHarness,
        draftIdleDebounceForTest;
import '../photo/photo_test_support.dart' show FakePhotoPicker;

const Size _galaxySurface = Size(1080, 2280);
const double _galaxyPixelRatio = 2.625;
const double _keyboard = 330;
const double _statusBarPixels = 85;
const String _today = '2026-09-18';
const String _launcherLabel = 'open';
const Duration _photoHold = Duration(milliseconds: 110);
const String _taskPrefix = '- [ ] ';
const Size _macWindow = Size(1280, 800);
const double _toastGap = 16;
const Duration _toastRise = Duration(milliseconds: 300);

const List<Key> _composerControls = <Key>[
  formatHeadingKey,
  formatListKey,
  formatNumberedKey,
  formatTaskKey,
  composerAddPhotoKey,
];

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextComposer(context, _today),
      child: const Text(_launcherLabel),
    );
  }
}

void _useGalaxySurfaceWithKeyboard(WidgetTester tester) {
  tester.view.physicalSize = _galaxySurface;
  tester.view.devicePixelRatio = _galaxyPixelRatio;
  tester.view.padding = const FakeViewPadding(top: _statusBarPixels);
  tester.view.viewInsets = const FakeViewPadding(
    bottom: _keyboard * _galaxyPixelRatio,
  );
  addTearDown(tester.view.reset);
}

List<Override> _overrides() => <Override>[
  todayClockProvider.overrideWithValue(() => DateTime(2026, 9, 18, 9, 30)),
  noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
  draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
  mediaStoreProvider.overrideWith((Ref ref) async => FakeNoteMediaStore()),
  notePhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
  notesMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeNoteMediaResolver(<String, ResolvedMedia>{
      prefixOf(photoIdA): availablePhoto(photoIdA, width: 1200, height: 900),
    })..memoizeAll(),
  ),
];

Future<NoteEditorDriver> _removePhotoWithKeyboardUp(WidgetTester tester) async {
  _useGalaxySurfaceWithKeyboard(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: captureHarness(const _Launcher()),
    ),
  );
  await tester.tap(find.text(_launcherLabel));
  await tester.pumpAndSettle();
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.enterText('one\n${mdPhotoLine(photoIdA)}\ntwo');
  await tester.pump(draftIdleDebounceForTest);
  await tester.pumpAndSettle();
  await driver.press(driver.photoFinder(0), _photoHold);
  await tester.pump();
  await driver.press(find.byKey(photoToolbarRemoveKey), _photoHold);
  await tester.pumpAndSettle();
  expect(find.text(photoRemovedMessage), findsOneWidget);
  return driver;
}

void main() {
  testWidgets(
    'with the keyboard up the photo removed toast covers no format button '
    'or Add memory',
    (WidgetTester tester) async {
      await _removePhotoWithKeyboardUp(tester);

      final Rect toast = tester.getRect(find.byType(Toast));
      for (final Key control in _composerControls) {
        final Rect rect = tester.getRect(find.byKey(control));
        expect(toast.overlaps(rect), isFalse, reason: '$control at $rect');
      }

      await tester.pump(kToastActionLifetime);
    },
  );

  testWidgets('Task list still toggles while the toast shows', (
    WidgetTester tester,
  ) async {
    final NoteEditorDriver driver = await _removePhotoWithKeyboardUp(tester);
    expect(driver.source, isNot(contains(_taskPrefix)));

    await tester.tapAt(tester.getCenter(find.byKey(formatTaskKey)));
    await tester.pump();

    expect(driver.source, contains(_taskPrefix));

    await tester.pump(kToastActionLifetime);
  });

  testWidgets('on macOS the empty-save guard floats clear of the footer', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = _macWindow;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: DialogHost(
          child: ComposerShell(
            responsive: true,
            child: TextComposerSheet(
              onSave: (String _) {},
              onCancel: () {},
              onAddPhoto: () async => const <String>[],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(_toastRise);

    final Rect toast = tester.getRect(find.byType(Toast));
    final Rect footer = tester.getRect(find.byType(ComposerFooter));
    expect(find.text(emptySaveGuardMessage), findsOneWidget);
    expect(toast.bottom, closeTo(footer.top - _toastGap, 0.5));
    expect(
      toast.overlaps(tester.getRect(find.byKey(composerAddPhotoKey))),
      isFalse,
    );

    await tester.pump(kToastLifetime);
  });
}
