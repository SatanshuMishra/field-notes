import 'dart:async';

import 'package:camera_macos/camera_macos.dart' show CameraImageData;
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/design/tokens/tokens.dart' show FieldNotesColors;
import 'package:field_notes/features/sync/ui/mac_code_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _refusedMessage =
    'Field Notes needs camera access to scan the code.';
const String _settingsLabel = 'Open System Settings';
const String _unavailableMessage =
    "The camera isn't available. Type the 8 words instead.";

const MethodChannel _settingsChannel = MethodChannel(
  'field_notes/camera_settings',
);
const MethodChannel _pluginChannel = MethodChannel('camera_macos');

final String _pairing = _payload(1);
final String _otherPairing = _payload(2);

String _payload(int fill) => PairingCode(
  secret: List<int>.filled(pairingSecretBytes, fill),
  relayUrl: Uri.parse('https://relay.example'),
).qrPayload;

final PlatformException _refusal = PlatformException(
  code: 'CAMERA_INITIALIZATION_ERROR',
  message: 'Permission not granted',
);

final PlatformException _noCamera = PlatformException(
  code: 'CAMERA_INITIALIZATION_ERROR',
  message: 'Could not find a suitable camera on this device',
);

CameraImageData _frame() =>
    CameraImageData(width: 4, height: 2, bytesPerRow: 16, bytes: Uint8List(32));

class _FakeCamera implements MacScannerCamera {
  _FakeCamera({this.failure});

  final Object? failure;
  ValueChanged<CameraImageData>? _onFrame;
  int stops = 0;

  @override
  Widget preview() => const SizedBox.expand();

  @override
  Future<void> start(ValueChanged<CameraImageData> onFrame) async {
    final Object? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    _onFrame = onFrame;
  }

  void send(CameraImageData frame) => _onFrame?.call(frame);

  @override
  Future<void> stop() async {
    stops += 1;
  }
}

Future<void> _pumpScanner(
  WidgetTester tester,
  MacCodeScanner scanner, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<Brightness>(brightness),
      theme: fieldNotesTheme(
        platform: TargetPlatform.macOS,
        brightness: brightness,
      ),
      home: Scaffold(
        body: Center(child: SizedBox(width: 560, height: 480, child: scanner)),
      ),
    ),
  );
  await tester.pump();
}

List<String> _recordCalls(WidgetTester tester, MethodChannel channel) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    MethodCall call,
  ) async {
    calls.add(call.method);
    if (channel == _pluginChannel && call.method == 'initialize') {
      return <String, Object?>{
        'error': <String, Object?>{
          'code': 'CAMERA_INITIALIZATION_ERROR',
          'message': 'Permission not granted',
          'details': null,
        },
      };
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return calls;
}

void main() {
  testWidgets('a refused camera offers System Settings', (
    WidgetTester tester,
  ) async {
    final List<String> settingsCalls = _recordCalls(tester, _settingsChannel);
    await _pumpScanner(
      tester,
      MacCodeScanner(
        onCode: (String code) {},
        camera: _FakeCamera(failure: _refusal),
      ),
    );

    expect(find.text(_refusedMessage), findsOneWidget);
    expect(find.text(_unavailableMessage), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_settingsLabel)),
      isSemantics(label: _settingsLabel, isButton: true),
    );
    await tester.tap(find.text(_settingsLabel));
    await tester.pump();
    expect(settingsCalls, <String>['openCameraSettings']);

    await _pumpScanner(
      tester,
      MacCodeScanner(
        key: const ValueKey<String>('no-camera'),
        onCode: (String code) {},
        camera: _FakeCamera(failure: _noCamera),
      ),
    );

    expect(find.text(_unavailableMessage), findsOneWidget);
    expect(find.text(_refusedMessage), findsNothing);
    expect(find.text(_settingsLabel), findsNothing);

    final _FakeCamera camera = _FakeCamera();
    final List<String> codes = <String>[];
    int decodes = 0;
    await _pumpScanner(
      tester,
      MacCodeScanner(
        key: const ValueKey<String>('streaming'),
        onCode: codes.add,
        decode: (CameraImageData frame) async {
          decodes += 1;
          return _pairing;
        },
        camera: camera,
      ),
    );
    for (int sent = 0; sent < 5; sent += 1) {
      camera.send(_frame());
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(decodes, 5);
    expect(codes, <String>[_pairing]);
  });

  testWidgets('the plugin refusing camera access shows the access message', (
    WidgetTester tester,
  ) async {
    final List<String> pluginCalls = _recordCalls(tester, _pluginChannel);
    await _pumpScanner(tester, MacCodeScanner(onCode: (String code) {}));
    await tester.pumpAndSettle();

    expect(pluginCalls, contains('initialize'));
    expect(find.text(_refusedMessage), findsOneWidget);
    expect(find.text(_settingsLabel), findsOneWidget);
    expect(find.text(_unavailableMessage), findsNothing);
  });

  testWidgets('frames are decoded one at a time and at most every 200 ms', (
    WidgetTester tester,
  ) async {
    final _FakeCamera camera = _FakeCamera();
    final List<Completer<String?>> decodes = <Completer<String?>>[];
    await _pumpScanner(
      tester,
      MacCodeScanner(
        onCode: (String code) {},
        decode: (CameraImageData frame) {
          final Completer<String?> pending = Completer<String?>();
          decodes.add(pending);
          return pending.future;
        },
        camera: camera,
      ),
    );

    camera.send(_frame());
    camera.send(_frame());
    expect(decodes, hasLength(1));

    await tester.pump(const Duration(milliseconds: 300));
    camera.send(_frame());
    expect(decodes, hasLength(1));

    decodes.last.complete(null);
    await tester.pump();
    camera.send(_frame());
    expect(decodes, hasLength(2));

    decodes.last.complete(null);
    await tester.pump();
    camera.send(_frame());
    await tester.pump(const Duration(milliseconds: 150));
    camera.send(_frame());
    expect(decodes, hasLength(2));

    await tester.pump(const Duration(milliseconds: 60));
    camera.send(_frame());
    expect(decodes, hasLength(3));
    decodes.last.complete(null);
  });

  testWidgets(
    'each distinct code is offered once and leaving stops the camera',
    (WidgetTester tester) async {
      final _FakeCamera camera = _FakeCamera();
      final List<String?> results = <String?>[
        _pairing,
        _pairing,
        null,
        _otherPairing,
        _otherPairing,
      ];
      int next = 0;
      final List<String> codes = <String>[];
      await _pumpScanner(
        tester,
        MacCodeScanner(
          onCode: codes.add,
          decode: (CameraImageData frame) async => results[next++],
          camera: camera,
        ),
      );
      for (int sent = 0; sent < results.length; sent += 1) {
        camera.send(_frame());
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(codes, <String>[_pairing, _otherPairing]);
      expect(camera.stops, 0);

      await tester.pumpWidget(const SizedBox());

      expect(camera.stops, 1);
    },
  );

  testWidgets('the camera notices follow the light and the dark theme', (
    WidgetTester tester,
  ) async {
    for (final Brightness brightness in Brightness.values) {
      await _pumpScanner(
        tester,
        MacCodeScanner(
          onCode: (String code) {},
          camera: _FakeCamera(failure: _refusal),
        ),
        brightness: brightness,
      );
      final FieldNotesColors colors = brightness == Brightness.dark
          ? FieldNotesColors.dark
          : FieldNotesColors.light;

      final ColoredBox panel = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(MacCodeScanner),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      final Text message = tester.widget<Text>(find.text(_refusedMessage));

      expect(panel.color.toARGB32(), colors.panelTop.toARGB32());
      expect(message.style?.color?.toARGB32(), colors.ink.toARGB32());
    }
  });
}
