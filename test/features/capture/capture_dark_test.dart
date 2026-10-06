import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/icons/format_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/photo/photo_tray.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';

import '../../support/theme_harness.dart';
import 'photo/photo_test_support.dart';
import 'video/video_test_support.dart';

const Color _composerPaper = Color(0xFF292424);
const Color _panelTop = Color(0xFF1C1919);
const Color _cardBright = Color(0xFF1F1B1B);
const Color _line = Color(0xFF968888);
const Color _ink = Color(0xFFEDE1E1);
const Color _stage = Color(0xFF1C1713);
const Color _recorderLabel = Color(0xFFB7A58C);

const Size _desktop = Size(1280, 900);

Future<void> _pumpDark(
  WidgetTester tester,
  Widget child, {
  TargetPlatform? platform,
  Size? size,
}) => pumpThemed(
  tester,
  child,
  brightness: Brightness.dark,
  platform: platform,
  size: size,
);

List<BoxDecoration> _decorationsIn(WidgetTester tester, Finder owner) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: owner, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .toList();

Color? _borderColour(BoxDecoration decoration) =>
    (decoration.border as Border?)?.top.color;

Color? _textColour(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

void main() {
  test('capture names no light-only colour', () {
    expect(lightOnlyTokenUses(<String>['lib/features/capture']), isEmpty);
  });

  testWidgets('text composer and format bar draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      ComposerShell(
        child: TextComposerSheet(
          onSave: (String _) {},
          onCancel: () {},
          title: 'New note',
          kicker: 'Today · 14:30',
        ),
      ),
      platform: TargetPlatform.macOS,
      size: _desktop,
    );

    final BoxDecoration panel =
        tester.widget<Container>(find.byKey(composerPanelKey)).decoration!
            as BoxDecoration;
    expect(panel.color, _composerPaper);
    expect(_borderColour(panel), _line);

    final BoxDecoration surface = _decorationsIn(
      tester,
      find.byKey(composerWritingSurfaceKey),
    ).first;
    expect(surface.color, _composerPaper);

    final BoxDecoration exitPill =
        tester.widget<Container>(find.byKey(composerCloseKey)).decoration!
            as BoxDecoration;
    expect(_borderColour(exitPill), _line);

    final Iterable<FormatIcon> glyphs = tester.widgetList<FormatIcon>(
      find.descendant(
        of: find.byType(FormatBar),
        matching: find.byType(FormatIcon),
      ),
    );
    expect(glyphs, isNotEmpty);
    expect(glyphs.map((FormatIcon glyph) => glyph.color).toSet(), <Color>{
      _ink,
    });
    expect(
      tester.renderObject(
        find
            .descendant(
              of: find.byKey(formatNumberedKey),
              matching: find.byType(CustomPaint),
            )
            .last,
      ),
      paints..path(color: _ink),
    );
  });

  testWidgets('capture chooser and photo tray draw their dark colours', (
    WidgetTester tester,
  ) async {
    await _pumpDark(
      tester,
      CaptureChooserSheet(
        availableTypes: EntryType.values.toSet(),
        onOptionSelected: (EntryType _) {},
      ),
      platform: TargetPlatform.macOS,
      size: _desktop,
    );

    final BoxDecoration card = _decorationsIn(
      tester,
      find.byType(StickerCard),
    ).first;
    expect(card.color, _cardBright);
    expect(_borderColour(card), _line);
    expect(_textColour(tester, find.text('Record voice')), _ink);
    expect(_textColour(tester, find.text('Record video')), _ink);
    expect(_textColour(tester, find.text('Capture a moment')), _ink);

    await _pumpDark(
      tester,
      CaptureChooserSheet(
        availableTypes: EntryType.values.toSet(),
        onOptionSelected: (EntryType _) {},
        layout: ShellLayout.bottomBar,
      ),
      platform: TargetPlatform.android,
      size: const Size(412, 915),
    );

    final BoxDecoration sheet = _decorationsIn(
      tester,
      find.byType(CaptureChooserSheet),
    ).first;
    expect(sheet.color, _panelTop);
    expect(_borderColour(sheet), _line);
    expect(_textColour(tester, find.text('Record voice')), _ink);

    await _pumpDark(
      tester,
      PhotoTray(
        picker: FakePhotoPicker(supportsCamera: false),
        onChanged: (List<CaptureMedia> _) {},
        initialPhotos: <CaptureMedia>[
          CaptureBytes(bytes: tinyPngBytes, mime: 'image/png'),
        ],
      ),
    );

    final BoxDecoration tile =
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.text('×'),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(tile.color, _cardBright);
    expect(_borderColour(tile), _line);
    expect(_textColour(tester, find.text('×')), _ink);
  });

  testWidgets(
    'camera menu follows the theme while the recorder stages stay the same',
    (WidgetTester tester) async {
      await _pumpDark(
        tester,
        Center(
          child: CameraPicker(
            devices: fakeVideoDevices,
            selectedDeviceId: fakeVideoDevices.first.id,
            onChanged: (String _) {},
          ),
        ),
        platform: TargetPlatform.macOS,
        size: _desktop,
      );
      await tester.tap(find.byType(CameraPicker));
      await tester.pumpAndSettle();

      final Finder menuItem = find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text(fakeVideoDevices.last.label),
      );
      expect(
        tester.widget<Text>(menuItem).style,
        FieldNotesTextStyles(FieldNotesColors.dark).bodySans,
      );
      expect(_textColour(tester, menuItem), _ink);

      for (final Brightness brightness in Brightness.values) {
        await pumpThemed(
          tester,
          ProviderScope(
            overrides: [reflectionPromptsOff()],
            child: SizedBox(
              width: 860,
              height: 600,
              child: VoiceRecorderSheet(
                phase: VoiceRecorderPhase.recording,
                onStart: () {},
                onStop: () {},
                onCancel: () {},
                elapsed: const Duration(seconds: 7),
              ),
            ),
          ),
          brightness: brightness,
          platform: TargetPlatform.macOS,
          size: _desktop,
        );
        await tester.pump(const Duration(milliseconds: 50));
        _expectRecorderStage(tester, find.byType(VoiceRecorderSheet));

        await pumpThemed(
          tester,
          ProviderScope(
            overrides: [reflectionPromptsOff()],
            child: SizedBox(
              width: 860,
              height: 600,
              child: VideoRecorderSheet(
                phase: VideoRecorderPhase.recording,
                devices: fakeVideoDevices,
                selectedDeviceId: fakeVideoDevices.first.id,
                elapsed: const Duration(seconds: 7),
                onStart: () {},
                onStop: () {},
                onLeave: () {},
              ),
            ),
          ),
          brightness: brightness,
          platform: TargetPlatform.macOS,
          size: _desktop,
        );
        await tester.pump(const Duration(milliseconds: 50));
        _expectRecorderStage(
          tester,
          find.byType(VideoRecorderSheet),
          textLeave: false,
        );
      }
    },
  );
}

void _expectRecorderStage(
  WidgetTester tester,
  Finder sheet, {
  bool textLeave = true,
}) {
  final Iterable<Color> fills = tester
      .widgetList<ColoredBox>(
        find.descendant(of: sheet, matching: find.byType(ColoredBox)),
      )
      .map((ColoredBox box) => box.color);
  expect(fills, contains(_stage));
  expect(
    _textColour(
      tester,
      find.descendant(of: sheet, matching: find.byKey(recorderTimerKey)),
    ),
    _recorderLabel,
  );
  if (!textLeave) {
    return;
  }
  expect(
    _textColour(
      tester,
      find.descendant(of: sheet, matching: find.text(recorderLeaveLabel)),
    ),
    _recorderLabel,
  );
}
