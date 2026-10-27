import 'dart:ui' as ui;

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/settings/sections/data_section.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/settings_harness.dart';
import '../../support/sync_overrides.dart';
import '../../support/face_boxes.dart';

const Size _phone = Size(412, 915);
const Size _desktop = Size(1280, 800);
const double _textContrast = 4.5;
const double _hueTolerance = 2;
const Color _pureWhite = Color(0xFFFFFFFF);
const Color _pureBlack = Color(0xFF000000);
const Color _letGoFill = Color(0xB81C1713);
const Key _boundaryKey = ValueKey<String>('destructive-boundary');
const Key _letGoKey = ValueKey<String>('let-go');
const Key _deleteKey = ValueKey<String>('viewer-delete');
const String _thirtyCharacters = 'Delete every entry on this Mac';

const List<TargetPlatform> _platforms = <TargetPlatform>[
  TargetPlatform.android,
  TargetPlatform.macOS,
  TargetPlatform.windows,
];

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double light = la > lb ? la : lb;
  final double dark = la > lb ? lb : la;
  return (light + 0.05) / (dark + 0.05);
}

Color _over(Color top, Color ground) => Color.alphaBlend(top, ground);

void _useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Size _surfaceFor(TargetPlatform platform) =>
    platform == TargetPlatform.android ? _phone : _desktop;

Widget _app(
  TargetPlatform platform,
  Widget home, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    key: UniqueKey(),
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: platform, brightness: brightness),
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: home,
  );
}

Widget _opener(String label, Future<void> Function(BuildContext) open) {
  return Scaffold(
    body: Center(
      child: Builder(
        builder: (BuildContext context) =>
            TextButton(onPressed: () => open(context), child: Text(label)),
      ),
    ),
  );
}

Future<void> Function(WidgetTester) _resettingPlatform(
  Future<void> Function(WidgetTester) body,
) {
  return (WidgetTester tester) async {
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  };
}

Future<void> _pumpOn(
  WidgetTester tester,
  TargetPlatform platform,
  Widget app,
) async {
  debugDefaultTargetPlatformOverride = platform;
  _useSurface(tester, _surfaceFor(platform));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

typedef _DestructiveFlow = ({
  String name,
  String destructive,
  String cancel,
  Widget Function(List<bool?> results) home,
});

final List<_DestructiveFlow> _flows = <_DestructiveFlow>[
  (
    name: 'showConfirmDialog',
    destructive: 'Delete',
    cancel: 'Cancel',
    home: (List<bool?> results) => _opener(
      'Open',
      (BuildContext context) async => results.add(
        await showConfirmDialog(
          context,
          title: 'Delete this entry?',
          message: 'This log will be removed. This can’t be undone.',
          confirmLabel: 'Delete',
          danger: true,
        ),
      ),
    ),
  ),
  (
    name: 'delete all',
    destructive: 'Delete everything',
    cancel: 'Keep my journal',
    home: (List<bool?> results) => _opener(
      'Open',
      (BuildContext context) async =>
          results.add(await confirmDeleteAll(context)),
    ),
  ),
  (
    name: 'composer discard',
    destructive: composerDiscardLabel,
    cancel: composerKeepEditingLabel,
    home: (List<bool?> results) => Scaffold(
      body: ComposerGuard(
        isDirty: () => true,
        onDiscard: () async => results.add(true),
        builder: (BuildContext context, VoidCallback requestClose) => Center(
          child: TextButton(onPressed: requestClose, child: const Text('Open')),
        ),
      ),
    ),
  ),
];

Future<Uint8List> _capture(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final Uint8List? pixels = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return pixels!;
}

Color _pixelAt(Uint8List pixels, int width, Offset point) {
  final int index = (point.dy.floor() * width + point.dx.floor()) * 4;
  return Color.fromARGB(
    pixels[index + 3],
    pixels[index],
    pixels[index + 1],
    pixels[index + 2],
  );
}

Rect _faceRect(WidgetTester tester, Finder button) =>
    tester.getRect(find.descendant(of: button, matching: faceBoxes()).first);

BoxDecoration _faceDecoration(WidgetTester tester, Finder button) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(of: button, matching: faceBoxes()).first,
            )
            .decoration
        as BoxDecoration;

Color _labelInk(WidgetTester tester, Finder button, String label) => tester
    .widget<Text>(find.descendant(of: button, matching: find.text(label)))
    .style!
    .color!;

int _lineCount(WidgetTester tester, Finder text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(text);
  final String label = paragraph.text.toPlainText();
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: label.length),
  );
  return boxes.map((TextBox box) => box.top.round()).toSet().length;
}

void _expectWrapsInFull(WidgetTester tester, String label) {
  final Finder text = find.text(label);
  expect(text, findsOneWidget, reason: label);
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(text);
  expect(paragraph.didExceedMaxLines, isFalse, reason: label);
  expect(_lineCount(tester, text), 2, reason: label);
  expect(tester.takeException(), isNull, reason: label);
}

void main() {
  testWidgets(
    'the danger sticker button is red ink with no fill',
    _resettingPlatform((WidgetTester tester) async {
      final double dangerHue = HSLColor.fromColor(Palette.danger).hue;
      for (final Brightness brightness in Brightness.values) {
        final FieldNotesColors colors = brightness == Brightness.light
            ? FieldNotesColors.light
            : FieldNotesColors.dark;
        await _pumpOn(
          tester,
          TargetPlatform.android,
          _app(
            TargetPlatform.android,
            Scaffold(
              backgroundColor: colors.page,
              body: Center(
                child: StickerButton(
                  label: 'Delete everything',
                  variant: StickerButtonVariant.danger,
                  onPressed: () {},
                ),
              ),
            ),
            brightness: brightness,
          ),
        );
        final Finder button = find.byType(StickerButton);
        final Color ink = _labelInk(tester, button, 'Delete everything');
        final BoxDecoration face = _faceDecoration(tester, button);
        expect(
          _contrast(ink, colors.page),
          greaterThanOrEqualTo(_textContrast),
          reason: '$brightness label on the page',
        );
        expect(
          (HSLColor.fromColor(ink).hue - dangerHue).abs(),
          lessThanOrEqualTo(_hueTolerance),
          reason: '$brightness label keeps the danger hue',
        );
        expect(face.color, isNull, reason: '$brightness face has no fill');
        expect(face.boxShadow, isNull, reason: '$brightness face has no lift');
        expect(
          (face.border! as Border).top.color,
          ink,
          reason: '$brightness edge is the danger ink',
        );
      }
    }),
  );

  testWidgets(
    'a destructive confirm defaults to cancel',
    _resettingPlatform((WidgetTester tester) async {
      for (final TargetPlatform platform in _platforms) {
        final List<bool?> results = <bool?>[];
        await _pumpOn(
          tester,
          platform,
          _app(platform, _flows.first.home(results)),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Delete this entry?'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(results, <bool?>[false], reason: '$platform');
        expect(
          find.text('Delete this entry?'),
          findsNothing,
          reason: '$platform',
        );
      }
    }),
  );

  testWidgets(
    'a destructive confirm orders its buttons per platform',
    _resettingPlatform((WidgetTester tester) async {
      for (final _DestructiveFlow flow in _flows) {
        for (final TargetPlatform platform in _platforms) {
          final List<bool?> results = <bool?>[];
          await _pumpOn(tester, platform, _app(platform, flow.home(results)));
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          final Offset destructive = tester.getCenter(
            find.text(flow.destructive).last,
          );
          final Offset cancel = tester.getCenter(find.text(flow.cancel).last);
          final String reason = '${flow.name} on $platform';
          switch (platform) {
            case TargetPlatform.windows:
              expect(cancel.dx, greaterThan(destructive.dx), reason: reason);
            case TargetPlatform.macOS:
              expect(cancel.dx, lessThan(destructive.dx), reason: reason);
            default:
              expect(destructive.dy, lessThan(cancel.dy), reason: reason);
          }
          expect(
            tester
                .widget<StickerButton>(
                  find.ancestor(
                    of: find.text(flow.destructive).last,
                    matching: find.byType(StickerButton),
                  ),
                )
                .variant,
            StickerButtonVariant.danger,
            reason: reason,
          );
        }
      }
    }),
  );

  testWidgets(
    'let it go and delete all use the danger look',
    _resettingPlatform((WidgetTester tester) async {
      for (final bool compact in <bool>[true, false]) {
        await _pumpOn(
          tester,
          TargetPlatform.android,
          _app(
            TargetPlatform.android,
            Scaffold(
              backgroundColor: _pureBlack,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LetGoPanel(
                    compact: compact,
                    letGoKey: _letGoKey,
                    onKeepGoing: () {},
                    onLetGo: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final Finder letGo = find.byKey(_letGoKey);
        expect(
          tester.widget<StickerButton>(letGo).variant,
          StickerButtonVariant.danger,
          reason: 'compact $compact',
        );
        expect(
          _faceDecoration(tester, letGo).color,
          isNull,
          reason: 'compact $compact',
        );
      }

      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.macOS,
      ]) {
        await _pumpOn(
          tester,
          platform,
          ProviderScope(
            overrides: <Override>[
              settingsDataControllerProvider.overrideWith(
                (Ref ref) async => FakeSettingsDataController(),
              ),
            ],
            child: _app(
              platform,
              Scaffold(
                body: SingleChildScrollView(
                  child: DataSection(
                    onFeedback: (String _) {},
                    confirmDelete: (BuildContext context) async => false,
                    openLink: (Uri _) async => false,
                  ),
                ),
              ),
            ),
          ),
        );
        final Finder deleteAll = find.widgetWithText(
          SettingsActionButton,
          'Delete all…',
        );
        expect(deleteAll, findsOneWidget, reason: '$platform');
        final Finder sticker = find.descendant(
          of: deleteAll,
          matching: find.byType(StickerButton),
        );
        expect(
          tester.widget<StickerButton>(sticker).variant,
          StickerButtonVariant.danger,
          reason: '$platform Delete all is the danger sticker button',
        );
        final BoxDecoration face = _faceDecoration(tester, deleteAll);
        final FieldNotesColors colors = FieldNotesColors.light;
        expect(
          face.color,
          isNull,
          reason: '$platform Delete all is not filled',
        );
        expect(
          _labelInk(tester, deleteAll, 'Delete all…'),
          colors.dangerInk,
          reason: '$platform Delete all draws the danger ink',
        );
      }
    }),
  );

  testWidgets(
    'delete all with sync on uses the danger look on the phone',
    _resettingPlatform((WidgetTester tester) async {
      await _pumpOn(
        tester,
        TargetPlatform.android,
        ProviderScope(
          overrides: syncOnOverrides(
            status: SyncedStatus(DateTime.now().toUtc()),
          ),
          child: _app(
            TargetPlatform.android,
            _opener('Open', (BuildContext context) async {
              await confirmDeleteAll(context);
            }),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final Finder everywhere = find.byKey(deleteEverywhereKey);
      expect(
        tester.widget<StickerButton>(everywhere).variant,
        StickerButtonVariant.danger,
      );
      expect(_faceDecoration(tester, everywhere).color, isNull);
    }),
  );

  testWidgets(
    'the danger look reads on media surfaces',
    _resettingPlatform((WidgetTester tester) async {
      for (final Brightness brightness in Brightness.values) {
        for (final Color frame in <Color>[_pureBlack, _pureWhite]) {
          final String reason = '$brightness over $frame';
          await _pumpOn(
            tester,
            TargetPlatform.android,
            _app(
              TargetPlatform.android,
              RepaintBoundary(
                key: _boundaryKey,
                child: ColoredBox(
                  color: frame,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LetGoPanel(
                        compact: true,
                        letGoKey: _letGoKey,
                        onKeepGoing: () {},
                        onLetGo: () {},
                      ),
                    ),
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          final Finder letGo = find.byKey(_letGoKey);
          final Color ink = _labelInk(tester, letGo, letGoConfirmLabel);
          final Rect face = _faceRect(tester, letGo);
          final Uint8List pixels = await _capture(tester);
          final int width = _phone.width.toInt();
          final List<Color> grounds = <Color>[
            _pixelAt(pixels, width, Offset(face.left + 6, face.center.dy)),
            _pixelAt(pixels, width, Offset(face.right - 6, face.center.dy)),
          ];
          final Color fill = _over(_letGoFill, frame);
          expect(
            (grounds.first.computeLuminance() - fill.computeLuminance()).abs(),
            lessThan(0.002),
            reason: '$reason samples the Let it go panel fill',
          );
          for (final Color ground in grounds) {
            expect(
              _contrast(ink, ground),
              greaterThanOrEqualTo(_textContrast),
              reason: '$reason Let it go label',
            );
          }

          await _pumpOn(
            tester,
            TargetPlatform.android,
            _app(
              TargetPlatform.android,
              RepaintBoundary(
                key: _boundaryKey,
                child: ColoredBox(
                  color: frame,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      const ViewerOverlayShade(top: true),
                      ViewerTopBar(
                        exitLabel: 'Close',
                        onExit: () {},
                        centre: const SizedBox.shrink(),
                        onDelete: () {},
                        deleteKey: _deleteKey,
                      ),
                    ],
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          final Finder delete = find.byKey(_deleteKey);
          final Rect glyph = tester.getRect(
            find.descendant(
              of: delete,
              matching: find.byType(IconStickerGlyphIcon),
            ),
          );
          final Uint8List viewerPixels = await _capture(tester);
          final List<Color> viewerGrounds = <Color>[
            for (double y = glyph.top; y < glyph.bottom; y += 1) ...<Color>[
              _pixelAt(viewerPixels, width, Offset(glyph.left - 4, y)),
              _pixelAt(viewerPixels, width, Offset(glyph.right + 4, y)),
            ],
          ];
          final Color glyphInk = tester
              .widget<IconStickerGlyphIcon>(
                find.descendant(
                  of: delete,
                  matching: find.byType(IconStickerGlyphIcon),
                ),
              )
              .color;
          final Color dangerOnMedia = StickerButtonVariant.danger.inkOn(
            StickerGround.media,
            brightness == Brightness.light
                ? FieldNotesColors.light
                : FieldNotesColors.dark,
          );
          for (final Color ground in viewerGrounds) {
            expect(
              _contrast(glyphInk, ground),
              greaterThanOrEqualTo(_textContrast),
              reason: '$reason viewer Delete glyph on $ground',
            );
            expect(
              _contrast(dangerOnMedia, ground),
              greaterThanOrEqualTo(_textContrast),
              reason: '$reason destructive media ink on $ground',
            );
          }
        }
      }
    }),
  );

  testWidgets(
    'destructive labels wrap at 2x text',
    _resettingPlatform((WidgetTester tester) async {
      const TextScaler twice = TextScaler.linear(2);
      expect(_thirtyCharacters.length, 30);

      await _pumpOn(
        tester,
        TargetPlatform.android,
        _app(
          TargetPlatform.android,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: StickerButton(
                  label: _thirtyCharacters,
                  variant: StickerButtonVariant.danger,
                  onPressed: () {},
                ),
              ),
            ),
          ),
          textScaler: twice,
        ),
      );
      _expectWrapsInFull(tester, _thirtyCharacters);

      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        _useSurface(tester, Size(320, _surfaceFor(platform).height));
        await tester.pumpWidget(
          _app(
            platform,
            _opener(
              'Open',
              (BuildContext context) => showConfirmDialog(
                context,
                title: 'Delete this entry?',
                message: 'This log will be removed.',
                confirmLabel: _thirtyCharacters,
                danger: true,
              ),
            ),
            textScaler: twice,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        _expectWrapsInFull(tester, _thirtyCharacters);

        await tester.pumpWidget(
          _app(
            platform,
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: SettingsActionButton(
                    label: _thirtyCharacters,
                    tone: SettingsActionTone.danger,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            textScaler: twice,
          ),
        );
        await tester.pumpAndSettle();
        _expectWrapsInFull(tester, _thirtyCharacters);
      }
    }),
  );
}
