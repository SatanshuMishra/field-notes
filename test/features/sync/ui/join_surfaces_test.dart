import 'dart:async';
import 'dart:math' as math;

import 'package:camera_macos/camera_macos.dart' show CameraImageData;
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraDescription, CameraPlatform;
import 'package:field_notes/app/shell/system_bars.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/settings_fields/settings_text_field.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/sync/ui/join_journal_flow.dart';
import 'package:field_notes/features/sync/ui/join_scan_page.dart';
import 'package:field_notes/features/sync/ui/join_window.dart';
import 'package:field_notes/features/sync/ui/mac_code_scanner.dart';
import 'package:field_notes/features/sync/ui/pairing_word_fields.dart';
import 'package:field_notes/features/sync/ui/qr_frame_decoder.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/features/sync/ui/sync_flow_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1440, 900);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _keyboard = 300;
const double _controlsLift = 22;
const double _control = 48;
const double _bracketSide = 0.76 * 384;
const double _titleBar = 42;
const double _columnGap = 28;
const double _sidePadding = 32;
const double _dividerWidth = 1.5;
const double _previewRadius = 18;
const double _previewBorder = 2;
const double _macBracketShare = 0.62;
const double _macBracketMax = 300;
const double _wordField = 48;
const double _dialogMaxWidth = 460;
const double _closeCorner = 60;
const int _rose = 0xFFB8566A;

const Key _previewKey = ValueKey<String>('fake-mac-preview');

const List<String> _words = <String>[
  'abandon',
  'ability',
  'able',
  'about',
  'above',
  'absent',
  'absorb',
  'abstract',
];

final Uri _syncServer = Uri.parse('https://sync.example.com');
final String _syncCode = PairingCode(
  secret: List<int>.filled(pairingSecretBytes, 3),
  relayUrl: _syncServer,
).qrPayload;
final String _refusedCode = _syncCode.replaceFirst(
  'https://sync.example.com',
  'https://sync.example.com@attacker.example',
);

final class _NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[];
}

final class _FakeJoin {
  final List<String> codes = <String>[];
  final Completer<void> answer = Completer<void>();

  Future<void> call(
    String code, {
    required JournalConfirmation confirmJournal,
    Uri? relayUrl,
    bool Function()? cancelled,
    void Function(String comparison)? onComparison,
  }) {
    codes.add(code);
    return answer.future;
  }
}

final class _FakeMacCamera implements MacScannerCamera {
  _FakeMacCamera({this.failure, this.ready});

  final Object? failure;
  final Future<void>? ready;
  Completer<CameraImageData?>? _request;
  int starts = 0;

  @override
  Widget preview() => const SizedBox.expand(key: _previewKey);

  @override
  Future<void> start() async {
    starts += 1;
    final Future<void>? ready = this.ready;
    if (ready != null) {
      await ready;
    }
    final Object? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<CameraImageData?> takeFrame() {
    final Completer<CameraImageData?> request = Completer<CameraImageData?>();
    _request = request;
    return request.future;
  }

  void send(CameraImageData? frame) {
    final Completer<CameraImageData?>? request = _request;
    _request = null;
    request?.complete(frame);
  }

  @override
  Future<void> stop() async => send(null);
}

final class _Host {
  late BuildContext context;
}

final PlatformException _cameraRefused = PlatformException(
  code: 'CAMERA_INITIALIZATION_ERROR',
  message: 'Permission not granted',
);

final PlatformException _noCamera = PlatformException(
  code: 'CAMERA_INITIALIZATION_ERROR',
  message: 'Could not find a suitable camera on this device',
);

final class _Opened {
  bool? result;
  bool closed = false;
}

CameraImageData _frame() =>
    CameraImageData(width: 4, height: 2, bytesPerRow: 16, bytes: Uint8List(32));

Future<String?> _decodeSyncCode(CameraImageData frame) async => _syncCode;

void _usePhoneCamera() {
  final CameraPlatform original = CameraPlatform.instance;
  CameraPlatform.instance = _NoCameras();
  addTearDown(() => CameraPlatform.instance = original);
}

void _useSurface(WidgetTester tester, TargetPlatform platform) {
  final bool phone = platform == TargetPlatform.android;
  final FakeViewPadding bars = phone
      ? const FakeViewPadding(top: _statusBar, bottom: _gestureBar)
      : FakeViewPadding.zero;
  tester.view.physicalSize = phone ? _phone : _mac;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = bars;
  tester.view.viewPadding = bars;
  addTearDown(tester.view.reset);
}

Future<_Opened> _openJoin(
  WidgetTester tester, {
  required TargetPlatform platform,
  required _FakeJoin join,
  Brightness brightness = Brightness.light,
  MacScannerCamera? macCamera,
  QrFrameDecode? macDecode,
}) async {
  _useSurface(tester, platform);
  final _Host host = _Host();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform, brightness: brightness),
        home: Builder(
          builder: (BuildContext context) {
            host.context = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final _Opened opened = _Opened();
  unawaited(
    showSyncFlow<bool>(
      host.context,
      builder: (BuildContext _) => JoinJournalFlow(
        join: join.call,
        macCamera: macCamera,
        macDecode: macDecode,
      ),
    ).then((bool? value) {
      opened.result = value;
      opened.closed = true;
    }),
  );
  await tester.pumpAndSettle();
  return opened;
}

void _scan(WidgetTester tester, String text) {
  tester.widget<ReaderWidget>(find.byType(ReaderWidget)).onScan!(
    Code(text: text, isValid: true),
  );
}

SystemUiOverlayStyle _annotationIn(WidgetTester tester, Finder surface) =>
    tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find
              .descendant(
                of: surface,
                matching: find.byWidgetPredicate(
                  (Widget widget) =>
                      widget is AnnotatedRegion<SystemUiOverlayStyle>,
                ),
              )
              .first,
        )
        .value;

SystemUiOverlayStyle? _statusBarStyle(WidgetTester tester) => tester
    .binding
    .renderViews
    .first
    .debugLayer!
    .find<SystemUiOverlayStyle>(Offset(_phone.width / 2, _statusBar / 2));

Finder _wordFields() => find.descendant(
  of: find.byType(PairingWordFields),
  matching: find.byType(SettingsTextField),
);

Finder _wordInput(int number) => find.descendant(
  of: _wordFields().at(number - 1),
  matching: find.byType(EditableText),
);

bool _isShade(Widget widget) =>
    widget is DecoratedBox &&
    widget.decoration is BoxDecoration &&
    (widget.decoration as BoxDecoration).gradient is LinearGradient;

void _expectTwoColumns(WidgetTester tester) {
  final List<Rect> fields = <Rect>[
    for (int index = 0; index < _words.length; index++)
      tester.getRect(_wordFields().at(index)),
  ];
  expect(fields, hasLength(8));
  for (int index = 0; index < fields.length; index++) {
    final Rect field = fields[index];
    final Rect first = fields[index % 2];
    expect(field.left, closeTo(first.left, 0.01), reason: 'word ${index + 1}');
    expect(
      field.top,
      closeTo(fields[index - index % 2].top, 0.01),
      reason: 'word ${index + 1}',
    );
  }
  expect(fields[1].left, greaterThan(fields[0].right));
  expect(fields[2].top, greaterThan(fields[0].bottom));
  expect(fields[6].top, greaterThan(fields[4].bottom));
}

void _expectPhoneSheet(WidgetTester tester, String title) {
  final Finder sheet = find.ancestor(
    of: find.text(title),
    matching: find.byType(PhoneSheet),
  );
  expect(sheet, findsOneWidget, reason: title);
  final Rect rect = tester.getRect(sheet);
  expect(rect.bottom, _phone.height, reason: title);
  expect(rect.width, _phone.width, reason: title);
  expect(rect.height, lessThan(_phone.height / 2), reason: title);
  expect(find.byType(StickerCard), findsNothing, reason: title);
}

void _expectMacDialog(WidgetTester tester, String title) {
  final Finder card = find.ancestor(
    of: find.text(title),
    matching: find.byType(StickerCard),
  );
  expect(card, findsOneWidget, reason: title);
  final Rect rect = tester.getRect(card);
  expect(rect.width, lessThanOrEqualTo(_dialogMaxWidth), reason: title);
  expect(rect.center.dx, closeTo(_mac.width / 2, 1), reason: title);
  expect(rect.height, lessThan(_mac.height / 2), reason: title);
  expect(find.byType(PhoneSheet), findsNothing, reason: title);
  expect(find.byType(JoinWindow), findsNothing, reason: title);
}

void main() {
  testWidgets('the phone join opens a full-screen camera', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeJoin join = _FakeJoin();
    await _openJoin(tester, platform: TargetPlatform.android, join: join);

    final Finder page = find.byType(JoinScanPage);
    expect(page, findsOneWidget);
    expect(tester.getRect(page), Offset.zero & _phone);
    expect(tester.getRect(find.byType(ReaderWidget)), Offset.zero & _phone);
    expect(find.byType(PhoneSheet), findsNothing);
    expect(find.byType(SyncFlowPage), findsNothing);
    final ReaderWidget reader = tester.widget<ReaderWidget>(
      find.byType(ReaderWidget),
    );
    expect(reader.codeFormat, Format.qrCode);
    expect(reader.showScannerOverlay, isFalse);
    expect(reader.cropPercent, closeTo(_bracketSide / _phone.width, 0.001));

    final List<Rect> shades = <Rect>[
      for (final Element element
          in find
              .descendant(of: page, matching: find.byWidgetPredicate(_isShade))
              .evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    expect(
      shades.any(
        (Rect shade) =>
            shade.top == 0 &&
            shade.width == _phone.width &&
            shade.bottom > _statusBar,
      ),
      isTrue,
    );
    expect(
      shades.any(
        (Rect shade) =>
            shade.bottom == _phone.height &&
            shade.width == _phone.width &&
            shade.top < _phone.height - _gestureBar,
      ),
      isTrue,
    );

    final Finder kicker = find.text('join my journal');
    final Finder message = find.text(
      'Point the camera at the code on your other device.',
    );
    final TextStyle kickerStyle = tester.widget<Text>(kicker).style!;
    final TextStyle messageStyle = tester.widget<Text>(message).style!;
    expect(kickerStyle.fontFamily, TypographyTokens.accent);
    expect(kickerStyle.color!.toARGB32(), Palette.mediaInk.toARGB32());
    expect(messageStyle.fontFamily, TypographyTokens.serif);
    expect(messageStyle.fontSize, 22);
    expect(messageStyle.color!.toARGB32(), Palette.mediaInk.toARGB32());
    expect(tester.getRect(kicker).top, greaterThanOrEqualTo(_statusBar));
    expect(
      tester.getRect(message).top,
      greaterThanOrEqualTo(tester.getRect(kicker).bottom),
    );

    final Rect frame = tester.getRect(find.byKey(joinScanFrameKey));
    expect(frame.width, closeTo(_bracketSide, 0.01));
    expect(frame.height, closeTo(_bracketSide, 0.01));
    expect(frame.center.dx, closeTo(_phone.width / 2, 0.01));
    expect(frame.center.dy, lessThan(_phone.height / 2));
    expect(frame.center.dy, greaterThan(_phone.height * 0.4));
    expect(frame.top, greaterThan(tester.getRect(message).bottom));
    final CustomPaint brackets = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(joinScanFrameKey),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      (brackets.painter! as JoinBracketsPainter).color.toARGB32(),
      Palette.mediaInk.toARGB32(),
    );

    final double controlsBottom = _phone.height - _gestureBar - _controlsLift;
    final Finder cancel = find.byWidgetPredicate(
      (Widget widget) =>
          widget is GlassCircleButton && widget.label == syncCancelLabel,
    );
    final GlassCircleButton cancelButton = tester.widget<GlassCircleButton>(
      cancel,
    );
    expect(cancelButton.tone, GlassTone.media);
    final Finder cancelGlass = find.descendant(
      of: cancel,
      matching: find.byType(GlassSurface),
    );
    final Rect cancelRect = tester.getRect(cancelGlass);
    expect(cancelRect.size, const Size(_control, _control));
    expect(cancelRect.bottom, controlsBottom);
    expect(tester.getRect(cancel).height, greaterThanOrEqualTo(_control));
    expect(
      tester
          .widget<IconStickerGlyphIcon>(
            find.descendant(
              of: cancel,
              matching: find.byType(IconStickerGlyphIcon),
            ),
          )
          .glyph,
      IconStickerGlyph.close,
    );
    final Finder cancelLabel = find.descendant(
      of: page,
      matching: find.text(syncCancelLabel),
    );
    final Rect cancelLabelRect = tester.getRect(cancelLabel);
    expect(cancelLabelRect.top, greaterThanOrEqualTo(cancelRect.bottom));
    expect(cancelLabelRect.center.dx, closeTo(cancelRect.center.dx, 0.5));
    expect(
      cancelLabelRect.bottom,
      lessThanOrEqualTo(_phone.height - _gestureBar),
    );
    expect(
      tester.widget<Text>(cancelLabel).style!.color!.toARGB32(),
      Palette.mediaInk.toARGB32(),
    );

    final Finder pill = find.byKey(typeWordsInsteadKey);
    final Finder pillGlass = find.descendant(
      of: pill,
      matching: find.byType(GlassSurface),
    );
    final GlassSurface pillSurface = tester.widget<GlassSurface>(pillGlass);
    expect(pillSurface.tone, GlassTone.media);
    expect(pillSurface.borderRadius, BorderRadius.circular(_control / 2));
    final Rect pillRect = tester.getRect(pillGlass);
    expect(pillRect.height, _control);
    expect(pillRect.bottom, controlsBottom);
    expect(pillRect.left, greaterThan(cancelRect.right));
    expect(pillRect.right, closeTo(_phone.width - cancelRect.left, 0.01));
    expect(
      find.descendant(
        of: pill,
        matching: find.text('Type the 8 words instead'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconStickerGlyphIcon>(
            find.descendant(
              of: pill,
              matching: find.byType(IconStickerGlyphIcon),
            ),
          )
          .glyph,
      IconStickerGlyph.edit,
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel(typeWordsInsteadLabel)),
      isSemantics(
        label: typeWordsInsteadLabel,
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(syncCancelLabel)),
      isSemantics(label: syncCancelLabel, isButton: true, hasTapAction: true),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    _scan(tester, _refusedCode);
    await tester.pump();
    final Finder error = find.text(pairingRetryMessage);
    expect(error, findsOneWidget);
    expect(find.textContaining('attacker'), findsNothing);
    final Finder errorGlass = find.ancestor(
      of: error,
      matching: find.byType(GlassSurface),
    );
    expect(tester.widget<GlassSurface>(errorGlass).tone, GlassTone.media);
    final Rect errorRect = tester.getRect(errorGlass);
    expect(
      errorRect.bottom,
      lessThanOrEqualTo(math.min(cancelRect.top, pillRect.top)),
    );
    expect(errorRect.left, greaterThanOrEqualTo(0));
    expect(errorRect.right, lessThanOrEqualTo(_phone.width));
    expect(
      tester.widget<Text>(error).style!.color!.toARGB32(),
      Palette.mediaInk.toARGB32(),
    );
    expect(find.byType(JoinScanPage), findsOneWidget);
    expect(join.codes, isEmpty);
    semantics.dispose();
  });

  testWidgets('the camera page asks for light status bar icons', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    expect(darkBackdropSystemBars.statusBarIconBrightness, Brightness.light);
    expect(
      darkBackdropSystemBars.systemNavigationBarIconBrightness,
      Brightness.light,
    );
    for (final Brightness brightness in Brightness.values) {
      await _openJoin(
        tester,
        platform: TargetPlatform.android,
        join: _FakeJoin(),
        brightness: brightness,
      );
      expect(
        _annotationIn(tester, find.byType(JoinScanPage)),
        darkBackdropSystemBars,
        reason: '$brightness',
      );
      expect(
        _statusBarStyle(tester),
        darkBackdropSystemBars,
        reason: '$brightness',
      );

      await tester.tap(find.byKey(typeWordsInsteadKey));
      await tester.pumpAndSettle();
      final SystemUiOverlayStyle paper = switch (brightness) {
        Brightness.light => systemBarsOver(Brightness.light),
        Brightness.dark => systemBarsOver(Brightness.dark),
      };
      expect(
        _annotationIn(tester, find.byType(SyncFlowPage)),
        paper,
        reason: '$brightness',
      );
      expect(_statusBarStyle(tester), paper, reason: '$brightness');
    }
  });

  testWidgets('typing the words is a full-screen page on the phone', (
    WidgetTester tester,
  ) async {
    _usePhoneCamera();
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeJoin join = _FakeJoin();
    final _Opened opened = await _openJoin(
      tester,
      platform: TargetPlatform.android,
      join: join,
    );
    await tester.tap(find.byKey(typeWordsInsteadKey));
    await tester.pumpAndSettle();

    final Finder page = find.byType(SyncFlowPage);
    expect(page, findsOneWidget);
    expect(tester.getRect(page), Offset.zero & _phone);
    expect(find.byType(JoinScanPage), findsNothing);
    expect(find.byType(ReaderWidget), findsNothing);
    expect(find.byType(PhoneSheet), findsNothing);
    expect(
      find.descendant(of: page, matching: find.text('Type the 8 words')),
      findsOneWidget,
    );
    final ColoredBox ground = tester.widget<ColoredBox>(
      find.descendant(of: page, matching: find.byType(ColoredBox)).first,
    );
    expect(ground.color.toARGB32(), FieldNotesColors.light.page.toARGB32());

    expect(_wordFields(), findsNWidgets(8));
    for (int number = 1; number <= 8; number++) {
      expect(
        find.descendant(
          of: find.byType(PairingWordFields),
          matching: find.text('$number'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Word $number'), findsOneWidget);
    }
    _expectTwoColumns(tester);
    expect(
      find.descendant(of: page, matching: find.text(serverAddressLabel)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(serverAddressLabel), findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text(serverAddressHint)),
      findsOneWidget,
    );

    final Rect close = tester.getRect(find.byKey(syncFlowPageCloseKey));
    expect(close.width, greaterThanOrEqualTo(_control));
    expect(close.height, greaterThanOrEqualTo(_control));
    expect(close.left, greaterThanOrEqualTo(0));
    expect(close.right, lessThanOrEqualTo(_closeCorner));
    expect(close.top, greaterThanOrEqualTo(_statusBar));
    expect(close.bottom, lessThanOrEqualTo(_statusBar + _closeCorner));

    final Finder footer = find.byKey(syncFlowPageFooterKey);
    final Finder back = find.descendant(
      of: footer,
      matching: find.text(joinBackLabel),
    );
    final Finder joinButton = find.descendant(
      of: footer,
      matching: find.byKey(joinConfirmKey),
    );
    expect(back, findsOneWidget);
    expect(joinButton, findsOneWidget);
    expect(
      tester.getCenter(back).dx,
      lessThan(tester.getCenter(joinButton).dx),
    );
    final List<int> joinColours = <int>[
      for (final Element element
          in find
              .descendant(of: joinButton, matching: find.byType(DecoratedBox))
              .evaluate())
        if ((element.widget as DecoratedBox).decoration
            case final BoxDecoration decoration when decoration.color != null)
          decoration.color!.toARGB32(),
    ];
    expect(joinColours, contains(_rose));
    expect(
      tester.getSemantics(find.bySemanticsLabel(joinLabel)),
      isSemantics(label: joinLabel, isButton: true, isEnabled: false),
    );

    await tester.enterText(_wordInput(1), _words.join(' '));
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel(joinLabel)),
      isSemantics(label: joinLabel, isButton: true, isEnabled: true),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    await tester.pump();
    expect(tester.getRect(page), Offset.zero & _phone);
    expect(
      tester.getRect(footer).bottom,
      lessThanOrEqualTo(_phone.height - _keyboard),
    );
    expect(
      tester.getRect(joinButton).bottom,
      lessThanOrEqualTo(_phone.height - _keyboard),
    );
    expect(tester.getRect(joinButton).height, greaterThanOrEqualTo(_control));
    tester.view.resetViewInsets();
    await tester.pump();

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(JoinScanPage), findsOneWidget);
    expect(find.byType(SyncFlowPage), findsNothing);
    await tester.tap(find.byKey(typeWordsInsteadKey));
    await tester.pumpAndSettle();
    expect(find.byType(SyncFlowPage), findsOneWidget);

    await tester.tap(find.byKey(syncFlowPageCloseKey));
    await tester.pumpAndSettle();
    expect(opened.closed, isTrue);
    expect(opened.result, isFalse);
    expect(join.codes, isEmpty);
    semantics.dispose();
  });

  testWidgets('the Mac join window gives scanning and typing equal width', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeJoin join = _FakeJoin();
    final _FakeMacCamera camera = _FakeMacCamera();
    await _openJoin(
      tester,
      platform: TargetPlatform.macOS,
      join: join,
      macCamera: camera,
    );

    final Finder window = find.byType(JoinWindow);
    expect(window, findsOneWidget);
    expect(tester.getRect(window), Offset.zero & _mac);
    expect(find.byType(StickerCard), findsNothing);
    expect(find.byType(SyncFlowPage), findsNothing);
    expect(
      tester.getRect(
        find.descendant(of: window, matching: find.byType(WindowDragBand)),
      ),
      const Rect.fromLTWH(0, 0, 1440, _titleBar),
    );
    final Finder paper = find.descendant(
      of: window,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is ColoredBox &&
            widget.color.toARGB32() == FieldNotesColors.light.page.toARGB32(),
      ),
    );
    expect(
      tester.getRect(paper.first),
      const Rect.fromLTRB(0, _titleBar, 1440, 900),
    );

    final Finder title = find.descendant(
      of: window,
      matching: find.text('Join my journal'),
    );
    expect(title, findsOneWidget);
    expect(tester.getCenter(title).dx, closeTo(_mac.width / 2, 0.5));
    expect(tester.getRect(title).top, greaterThanOrEqualTo(_titleBar));
    expect(
      tester.widget<Text>(title).style!.fontFamily,
      TypographyTokens.serif,
    );
    final Finder cancel = find.descendant(
      of: window,
      matching: find.widgetWithText(StickerButton, syncCancelLabel),
    );
    final Rect cancelRect = tester.getRect(cancel);
    expect(cancelRect.left, lessThanOrEqualTo(_sidePadding));
    expect(cancelRect.top, greaterThanOrEqualTo(_titleBar));
    expect(cancelRect.right, lessThan(tester.getRect(title).left));

    final Rect scan = tester.getRect(find.byKey(joinScanColumnKey));
    final Rect type = tester.getRect(find.byKey(joinTypeColumnKey));
    expect(scan.width, closeTo(type.width, 0.01));
    expect(scan.left, _sidePadding);
    expect(type.right, _mac.width - _sidePadding);
    final Finder divider = find.descendant(
      of: window,
      matching: find.byType(DashedDivider),
    );
    expect(tester.widget<DashedDivider>(divider).axis, Axis.vertical);
    final Rect dividerRect = tester.getRect(divider);
    expect(dividerRect.width, _dividerWidth);
    expect(dividerRect.top, closeTo(scan.top, 0.01));
    expect(dividerRect.bottom, closeTo(scan.bottom, 0.01));
    final Rect or = tester.getRect(
      find.descendant(of: window, matching: find.text('or')),
    );
    expect(or.center.dx, closeTo(dividerRect.center.dx, 0.5));
    expect(or.center.dy, closeTo(dividerRect.center.dy, 0.5));
    final Rect middle = or.expandToInclude(dividerRect);
    expect(middle.left - scan.right, closeTo(_columnGap, 0.01));
    expect(type.left - middle.right, closeTo(_columnGap, 0.01));

    final Finder scanColumn = find.byKey(joinScanColumnKey);
    expect(
      find.descendant(of: scanColumn, matching: find.text('Scan the code')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: scanColumn,
        matching: find.text("Hold your other device up to this Mac's camera."),
      ),
      findsOneWidget,
    );
    final Finder scanner = find.descendant(
      of: scanColumn,
      matching: find.byType(MacCodeScanner),
    );
    expect(
      find.descendant(of: scanner, matching: find.byKey(_previewKey)),
      findsOneWidget,
    );
    expect(camera.starts, 1);
    final Rect preview = tester.getRect(scanner);
    expect(preview.width, closeTo(scan.width, 0.01));
    expect(preview.bottom, closeTo(scan.bottom, 0.01));
    expect(
      tester
          .widget<ClipRRect>(
            find.ancestor(of: scanner, matching: find.byType(ClipRRect)).first,
          )
          .borderRadius,
      BorderRadius.circular(_previewRadius),
    );
    final Finder border = find.ancestor(
      of: scanner,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border is Border,
      ),
    );
    final Border previewBorder =
        (tester.widget<DecoratedBox>(border.first).decoration as BoxDecoration)
                .border!
            as Border;
    expect(previewBorder.top.width, _previewBorder);
    expect(
      previewBorder.top.color.toARGB32(),
      FieldNotesColors.light.ink.toARGB32(),
    );
    final Rect brackets = tester.getRect(
      find.descendant(of: scanColumn, matching: find.byKey(joinScanFrameKey)),
    );
    final double bracketSide = math.min(
      preview.height * _macBracketShare,
      _macBracketMax,
    );
    expect(brackets.width, closeTo(bracketSide, 0.01));
    expect(brackets.height, closeTo(bracketSide, 0.01));
    expect(brackets.center.dx, closeTo(preview.center.dx, 0.01));
    expect(brackets.center.dy, closeTo(preview.center.dy, 0.01));

    final Finder typeColumn = find.byKey(joinTypeColumnKey);
    expect(
      find.descendant(of: typeColumn, matching: find.text('Type the 8 words')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: typeColumn,
        matching: find.text(
          "They're under the code on your other device. Paste all 8 at once "
          'if you like.',
        ),
      ),
      findsOneWidget,
    );
    expect(_wordFields(), findsNWidgets(8));
    for (int index = 0; index < 8; index++) {
      expect(tester.getRect(_wordFields().at(index)).height, _wordField);
    }
    _expectTwoColumns(tester);
    expect(
      find.descendant(of: typeColumn, matching: find.text(serverAddressLabel)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: typeColumn,
        matching: find.text(
          'Leave it empty if your other device uses the usual server.',
        ),
      ),
      findsOneWidget,
    );

    final Finder counter = find.byKey(joinWordsCountKey);
    final Finder joinButton = find.byKey(joinConfirmKey);
    final StickerButton joinSticker = tester.widget<StickerButton>(joinButton);
    expect(joinSticker.variant, StickerButtonVariant.primary);
    expect(joinSticker.onPressed, isNull);
    expect(tester.widget<Text>(counter).data, '0 of 8');
    final Rect counterRect = tester.getRect(counter);
    final Rect joinRect = tester.getRect(joinButton);
    expect(joinRect.right, closeTo(type.right, 0.01));
    expect(joinRect.bottom, closeTo(type.bottom, 0.01));
    expect(counterRect.right, lessThanOrEqualTo(joinRect.left));
    expect(counterRect.center.dy, closeTo(joinRect.center.dy, 0.5));
    expect(
      counterRect.top,
      greaterThan(tester.getRect(_wordFields().last).bottom),
    );

    for (int number = 1; number <= 3; number++) {
      await tester.enterText(_wordInput(number), _words[number - 1]);
      await tester.pump();
    }
    expect(tester.widget<Text>(counter).data, '3 of 8');
    expect(tester.widget<StickerButton>(joinButton).onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(join.codes, isEmpty);
    expect(find.byType(JoinWindow), findsOneWidget);

    for (int number = 4; number <= 8; number++) {
      await tester.enterText(_wordInput(number), _words[number - 1]);
      await tester.pump();
    }
    expect(tester.widget<Text>(counter).data, 'All 8 words in');
    expect(tester.widget<StickerButton>(joinButton).onPressed, isNotNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.showKeyboard(_wordInput(3));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(join.codes, <String>[_words.join(' ')]);
    expect(find.byType(JoinWindow), findsNothing);
    expect(find.text(joinCheckingTitle), findsOneWidget);

    final _FakeJoin escaped = _FakeJoin();
    final _Opened opened = await _openJoin(
      tester,
      platform: TargetPlatform.macOS,
      join: escaped,
      macCamera: _FakeMacCamera(),
    );
    await tester.enterText(_wordInput(1), _words.first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(opened.closed, isTrue);
    expect(opened.result, isFalse);
    expect(find.byType(JoinWindow), findsNothing);
    expect(escaped.codes, isEmpty);
    semantics.dispose();
  });

  testWidgets('the Mac brackets show only over a live camera', (
    WidgetTester tester,
  ) async {
    final Finder brackets = find.byKey(joinScanFrameKey);
    final Completer<void> starting = Completer<void>();
    await _openJoin(
      tester,
      platform: TargetPlatform.macOS,
      join: _FakeJoin(),
      macCamera: _FakeMacCamera(ready: starting.future),
    );
    expect(find.byKey(_previewKey), findsOneWidget);
    expect(brackets, findsNothing);

    starting.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_previewKey), findsOneWidget);
    expect(brackets, findsOneWidget);

    await _openJoin(
      tester,
      platform: TargetPlatform.macOS,
      join: _FakeJoin(),
      macCamera: _FakeMacCamera(failure: _cameraRefused),
    );
    expect(find.text(cameraAccessRefusedMessage), findsOneWidget);
    expect(brackets, findsNothing);

    await _openJoin(
      tester,
      platform: TargetPlatform.macOS,
      join: _FakeJoin(),
      brightness: Brightness.dark,
      macCamera: _FakeMacCamera(failure: _noCamera),
    );
    expect(find.text(cameraUnavailableMessage), findsOneWidget);
    expect(brackets, findsNothing);
  });

  testWidgets(
    'the join checks stay a sheet on the phone and a dialog on the Mac',
    (WidgetTester tester) async {
      _usePhoneCamera();
      final String title = 'Join sync.example.com?';
      final _FakeJoin phoneJoin = _FakeJoin();
      await _openJoin(
        tester,
        platform: TargetPlatform.android,
        join: phoneJoin,
      );

      _scan(tester, _syncCode);
      await tester.pumpAndSettle();
      _expectPhoneSheet(tester, title);
      expect(find.byType(JoinScanPage), findsNothing);
      await tester.tap(find.text(joinDeclineLabel));
      await tester.pumpAndSettle();
      expect(find.byType(JoinScanPage), findsOneWidget);
      expect(find.byType(PhoneSheet), findsNothing);

      await tester.tap(find.byKey(typeWordsInsteadKey));
      await tester.pumpAndSettle();
      await tester.enterText(_wordInput(1), _syncCode);
      await tester.pump();
      await tester.tap(find.byKey(joinConfirmKey));
      await tester.pumpAndSettle();
      _expectPhoneSheet(tester, title);
      expect(find.byType(SyncFlowPage), findsNothing);
      await tester.tap(find.text(joinDeclineLabel));
      await tester.pumpAndSettle();
      expect(find.byType(SyncFlowPage), findsOneWidget);
      expect(find.text(joinTypeTitle), findsOneWidget);
      expect(find.byType(PhoneSheet), findsNothing);

      await tester.tap(find.byKey(joinConfirmKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(joinServerConfirmKey));
      await tester.pump();
      _expectPhoneSheet(tester, joinCheckingTitle);
      expect(phoneJoin.codes, <String>[_syncCode]);

      final _FakeJoin macJoin = _FakeJoin();
      final _FakeMacCamera camera = _FakeMacCamera();
      await _openJoin(
        tester,
        platform: TargetPlatform.macOS,
        join: macJoin,
        macCamera: camera,
        macDecode: _decodeSyncCode,
      );
      await tester.enterText(_wordInput(1), _syncCode);
      await tester.pump();
      await tester.tap(find.byKey(joinConfirmKey));
      await tester.pumpAndSettle();
      _expectMacDialog(tester, title);
      await tester.tap(find.text(joinDeclineLabel));
      await tester.pumpAndSettle();
      expect(find.byType(JoinWindow), findsOneWidget);
      expect(find.byType(StickerCard), findsNothing);

      camera.send(_frame());
      await tester.pump(macScanInterval);
      await tester.pumpAndSettle();
      _expectMacDialog(tester, title);
      await tester.tap(find.text(joinDeclineLabel));
      await tester.pumpAndSettle();
      expect(find.byType(JoinWindow), findsOneWidget);
      expect(find.byType(StickerCard), findsNothing);

      await tester.tap(find.byKey(joinConfirmKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(joinServerConfirmKey));
      await tester.pump();
      _expectMacDialog(tester, joinCheckingTitle);
      expect(macJoin.codes, <String>[_syncCode]);
    },
  );
}
