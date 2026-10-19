import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoSide, MdPhotoSize;
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/photo/photo_tray.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show ComposerMediaScope, NoteEditorController;
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/note_editor_driver.dart';
import '../../support/photo_line_fixture.dart';
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, photoIdB, prefixOf;
import 'photo/photo_test_support.dart';

const int _mousePointerId = 47;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _coral = Color(0xFFB8566A);
const Color _white = Color(0xFFFFFFFF);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _lightPill = _coral.withValues(alpha: 0.08).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();

const Key _cameraToggleKey = ValueKey<String>('camera-toggle');
const Key _flipKey = ValueKey<String>('camera-flip');
const Key _inputKey = ValueKey<String>('input-button');
const Key _keepGoingKey = ValueKey<String>('keep-going');
const Key _letGoKey = ValueKey<String>('let-go');

const Duration _hold = Duration(milliseconds: 110);

enum _Shape { circle, rounded }

class _Row {
  const _Row(this.label, this.control, this.fill, this.shape, [this.radius]);

  final String label;
  final Finder control;
  final int fill;
  final _Shape shape;
  final double? radius;
}

Finder _pressableAt(Key key) =>
    find.ancestor(of: find.byKey(key), matching: find.byType(Pressable)).first;

Finder _pressableOn(Key key) => find.byKey(key);

Finder _pressableIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(Pressable));

Finder _pressableAround(String text) => find
    .ancestor(of: find.text(text).last, matching: find.byType(Pressable))
    .first;

void _desktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _quietWindowChannel(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (MethodCall call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  Color background = Palette.mediaGround,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        reflectionPromptsEnabledProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(backgroundColor: background, body: body),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<TestGesture> _mousePointer(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: _mousePointerId,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    if (decoration is! BoxDecoration ||
        decoration.color?.toARGB32() != row.fill) {
      return false;
    }
    return switch (row.shape) {
      _Shape.circle => decoration.shape == BoxShape.circle,
      _Shape.rounded =>
        decoration.borderRadius == BorderRadius.circular(row.radius!),
    };
  }),
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  await mouse.moveTo(Offset.zero);
  await tester.pump();
  for (final _Row row in rows) {
    expect(row.control, findsOneWidget, reason: row.label);
    expect(_hoverFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(row), findsOneWidget, reason: row.label);
    expect(
      tester.getSemantics(row.control),
      isSemantics(label: row.label, isButton: true),
      reason: row.label,
    );

    await mouse.moveTo(Offset.zero);
    await tester.pump();
  }
}

Widget _photoEditor(
  NoteEditorController controller,
  FocusNode focus,
  UndoHistoryController undo,
  ScrollController scroll,
) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: TargetPlatform.macOS),
    home: Scaffold(
      body: ComposerMediaScope(
        resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(
            photoIdA,
            width: 1200,
            height: 900,
          ),
          prefixOf(photoIdB): availablePhoto(
            photoIdB,
            width: 1200,
            height: 900,
          ),
        })..memoizeAll(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 720,
            height: 700,
            child: noteEditorFor(
              NoteEditorConfig(
                controller: controller,
                focusNode: focus,
                undoController: undo,
                scrollController: scroll,
                photoImporter: () async => <String>[prefixOf(photoIdB)],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every capture control shows the click cursor and hover', (
    WidgetTester tester,
  ) async {
    _desktopView(tester);
    _quietWindowChannel(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestGesture mouse = await _mousePointer(tester);

    await _pump(
      tester,
      CaptureChooserSheet(
        availableTypes: const <EntryType>{
          EntryType.text,
          EntryType.voice,
          EntryType.video,
        },
        onOptionSelected: (EntryType _) {},
      ),
      background: const Color(0xFFF6EDDD),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'Write a note\nput the day into words',
        _pressableAround('Write a note'),
        _dark,
        _Shape.rounded,
        14,
      ),
      _Row(
        'Record voice\nspeak it, hands-free',
        _pressableAround('Record voice'),
        _lightRow,
        _Shape.rounded,
        14,
      ),
      _Row(
        'Record video\na moving snapshot',
        _pressableAround('Record video'),
        _lightRow,
        _Shape.rounded,
        14,
      ),
    ]);

    await _pump(
      tester,
      Center(
        child: LetGoPanel(
          onKeepGoing: () {},
          onLetGo: () {},
          compact: false,
          keepGoingKey: _keepGoingKey,
          letGoKey: _letGoKey,
        ),
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'Keep going',
        _pressableOn(_keepGoingKey),
        _dark,
        _Shape.rounded,
        20,
      ),
      _Row('Let it go', _pressableOn(_letGoKey), _dark, _Shape.rounded, 20),
    ]);

    await _pump(
      tester,
      RecorderSurface(
        onLeave: () {},
        arrangement: RecorderArrangement.video,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RecorderGlassButton(
              key: _cameraToggleKey,
              label: 'Turn camera off',
              glyph: const CaptureIcon(
                glyph: CaptureGlyph.video,
                color: Color(0xFFFFFFFF),
                size: 16,
              ),
              onPressed: () {},
              toggled: true,
            ),
            RecorderGlassButton(
              key: _flipKey,
              label: 'Flip camera',
              glyph: const CaptureIcon(
                glyph: CaptureGlyph.video,
                color: Color(0xFFFFFFFF),
                size: 16,
              ),
              onPressed: () {},
            ),
            RecorderGlassButton(
              key: _inputKey,
              label: 'Input',
              glyph: const CaptureIcon(
                glyph: CaptureGlyph.mic,
                color: Color(0xFFFFFFFF),
                size: 16,
              ),
              onPressed: () {},
            ),
          ],
        ),
        question: const ReflectionPrompt(
          phase: StagePhase.idle,
          showKicker: true,
          initialIndex: 0,
        ),
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row('Leave', _pressableOn(recorderLeaveKey), _dark, _Shape.rounded, 10),
      _Row(
        'Turn camera off',
        _pressableIn(_cameraToggleKey),
        _dark,
        _Shape.circle,
      ),
      _Row('Flip camera', _pressableIn(_flipKey), _dark, _Shape.circle),
      _Row('Input', _pressableIn(_inputKey), _dark, _Shape.circle),
      _Row(
        'Ask me something else',
        _pressableOn(reflectionShuffleKey),
        _dark,
        _Shape.rounded,
        14,
      ),
    ]);

    await _pump(
      tester,
      Center(
        child: PhotoTray(
          picker: FakePhotoPicker(),
          onChanged: (List<CaptureMedia> _) {},
          initialPhotos: <CaptureMedia>[
            CaptureBytes(bytes: tinyPngBytes, mime: 'image/png'),
          ],
        ),
      ),
      background: const Color(0xFFF6EDDD),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'Remove photo 1',
        _pressableAround('×'),
        _lightRow,
        _Shape.rounded,
        11,
      ),
      _Row(
        'Add from library',
        _pressableAround('Add from library'),
        _lightRow,
        _Shape.rounded,
        12,
      ),
      _Row(
        'Take a photo',
        _pressableAround('Take a photo'),
        _lightRow,
        _Shape.rounded,
        12,
      ),
    ]);

    await _pump(
      tester,
      TextComposerSheet(
        onSave: (String _) {},
        onCancel: () {},
        draftRestored: true,
        onDiscardDraft: () {},
        initialText: 'a morning walk',
        onAddPhoto: () async => const <String>[],
      ),
      background: const Color(0xFFF6EDDD),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'Cancel',
        _pressableAt(composerCloseKey),
        _lightRow,
        _Shape.rounded,
        10,
      ),
      _Row('Save', _pressableAt(composerSaveKey), _dark, _Shape.rounded, 13),
      _Row(
        'Discard',
        _pressableOn(draftRestoredDiscardKey),
        _lightPill,
        _Shape.rounded,
        13,
      ),
      _Row('Bold', _pressableIn(formatBoldKey), _lightRow, _Shape.rounded, 6),
      _Row(
        'Italic',
        _pressableIn(formatItalicKey),
        _lightRow,
        _Shape.rounded,
        6,
      ),
      _Row(
        'Heading',
        _pressableIn(formatHeadingKey),
        _lightRow,
        _Shape.rounded,
        6,
      ),
      _Row(
        'Bullet list',
        _pressableIn(formatListKey),
        _lightRow,
        _Shape.rounded,
        6,
      ),
      _Row(
        'Numbered list',
        _pressableIn(formatNumberedKey),
        _lightRow,
        _Shape.rounded,
        6,
      ),
      _Row(
        'Task list',
        _pressableIn(formatTaskKey),
        _lightRow,
        _Shape.rounded,
        6,
      ),
      _Row('Quote', _pressableIn(formatQuoteKey), _lightRow, _Shape.rounded, 6),
      _Row('Link', _pressableIn(formatLinkKey), _lightRow, _Shape.rounded, 6),
      _Row('Table', _pressableIn(formatTableKey), _lightRow, _Shape.rounded, 6),
      _Row(
        'More formats',
        _pressableIn(formatMoreKey),
        _lightRow,
        _Shape.rounded,
        6,
      ),
      _Row(
        'Add memory',
        _pressableOn(composerAddPhotoKey),
        _dark,
        _Shape.rounded,
        11,
      ),
    ]);

    await tester.tap(_pressableIn(formatMoreKey));
    await tester.pump();
    await tester.pump();
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'Strikethrough',
        _pressableOn(formatStrikethroughKey),
        _dark,
        _Shape.rounded,
        6,
      ),
      _Row(
        'Highlight',
        _pressableOn(formatHighlightKey),
        _dark,
        _Shape.rounded,
        6,
      ),
      _Row(
        'Inline code',
        _pressableOn(formatCodeKey),
        _dark,
        _Shape.rounded,
        6,
      ),
    ]);

    final NoteEditorController controller = NoteEditorController(
      text: 'one\n${mdPhotoLine(photoIdA)}\ntwo',
    );
    final FocusNode focus = FocusNode();
    final UndoHistoryController undo = UndoHistoryController();
    final ScrollController scroll = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    addTearDown(undo.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_photoEditor(controller, focus, undo, scroll));
    await tester.pump();
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    await driver.press(driver.photoFinder(0), _hold);
    await tester.pump();
    expect(find.byKey(photoToolbarKey), findsOneWidget);
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'Small size',
        _pressableAt(photoToolbarSizeKey(MdPhotoSize.small)),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Large size',
        _pressableAt(photoToolbarSizeKey(MdPhotoSize.large)),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Full size',
        _pressableAt(photoToolbarSizeKey(MdPhotoSize.full)),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Left side',
        _pressableAt(photoToolbarSideKey(MdPhotoSide.left)),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Centre side',
        _pressableAt(photoToolbarSideKey(MdPhotoSide.centre)),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Move up',
        _pressableAt(photoToolbarMoveUpKey),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Move down',
        _pressableAt(photoToolbarMoveDownKey),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Replace',
        _pressableAt(photoToolbarReplaceKey),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Caption',
        _pressableAt(photoToolbarCaptionKey),
        _dark,
        _Shape.rounded,
        7,
      ),
      _Row(
        'Remove',
        _pressableAt(photoToolbarRemoveKey),
        _dark,
        _Shape.rounded,
        7,
      ),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
