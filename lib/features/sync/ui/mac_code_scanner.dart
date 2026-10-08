import 'dart:async';

import 'package:camera_macos/camera_macos.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/sticker_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'camera_settings_opener.dart';
import 'qr_frame_decoder.dart';

const String cameraAccessRefusedMessage =
    'Field Notes needs camera access to scan the code.';
const String cameraSettingsLabel = 'Open System Settings';
const String cameraUnavailableMessage =
    "The camera isn't available. Type the 8 words instead.";

const Duration macScanInterval = Duration(milliseconds: 200);

const String _refusalText = 'Permission not granted';
const EdgeInsets _noticePadding = EdgeInsets.all(24);
const double _noticeGap = 16;

abstract interface class MacScannerCamera {
  Widget preview();

  Future<void> start();

  Future<CameraImageData?> takeFrame();

  Future<void> stop();
}

bool isCameraAccessRefusal(Object? error) => switch (error) {
  PlatformException() => error.message == _refusalText,
  CameraMacOSException() => error.message == _refusalText,
  {'error': final Object? reply} => isCameraAccessRefusal(reply),
  {'message': _refusalText} => true,
  _ => false,
};

class CameraMacosScannerCamera implements MacScannerCamera {
  CameraMacosScannerCamera();

  final Completer<CameraMacOSController> _ready =
      Completer<CameraMacOSController>();
  CameraMacOSController? _controller;
  Completer<CameraImageData?>? _frame;
  Future<void> _streamStopped = Future<void>.value();
  bool _stopped = false;

  late final Widget _view = CameraMacOSView(
    cameraMode: CameraMacOSMode.photo,
    enableAudio: false,
    fit: BoxFit.cover,
    resolution: PictureResolution.high,
    onCameraInizialized: _onInitialized,
    onCameraLoading: _onLoading,
  );

  @override
  Widget preview() => _view;

  @override
  Future<void> start() async {
    await _ready.future;
  }

  @override
  Future<CameraImageData?> takeFrame() async {
    await _streamStopped;
    if (_stopped || _controller == null) {
      return null;
    }
    final Completer<CameraImageData?> frame = Completer<CameraImageData?>();
    _frame = frame;
    try {
      await CameraMacOSPlatform.instance.startImageStream(
        _receive,
        onError: _skipFrame,
      );
    } catch (error, stackTrace) {
      debugPrint('Scanner image stream start failed: $error\n$stackTrace');
      _settleFrame(null);
    }
    return frame.future;
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _settleFrame(null);
    final CameraMacOSController? controller = _controller;
    _controller = null;
    if (controller != null) {
      await _release(controller);
    }
  }

  void _receive(CameraImageData? image) {
    if (image == null || _frame == null) {
      return;
    }
    _streamStopped = _stopStream();
    _settleFrame(image);
  }

  void _settleFrame(CameraImageData? image) {
    final Completer<CameraImageData?>? frame = _frame;
    _frame = null;
    if (frame != null && !frame.isCompleted) {
      frame.complete(image);
    }
  }

  void _onInitialized(CameraMacOSController controller) {
    if (_stopped) {
      unawaited(_release(controller));
      return;
    }
    _controller = controller;
    if (!_ready.isCompleted) {
      _ready.complete(controller);
    }
  }

  Widget _onLoading(Object? error) {
    if (error != null && !_ready.isCompleted) {
      _ready.completeError(error);
    }
    return const SizedBox.expand();
  }

  void _skipFrame(Object? error) {}

  Future<void> _stopStream() async {
    try {
      await CameraMacOSPlatform.instance.stopImageStream();
    } catch (error, stackTrace) {
      debugPrint('Scanner image stream stop failed: $error\n$stackTrace');
    }
  }

  Future<void> _release(CameraMacOSController controller) async {
    try {
      await controller.stopImageStream();
      await controller.destroy();
    } catch (error, stackTrace) {
      debugPrint('Scanner camera release failed: $error\n$stackTrace');
    }
  }
}

class MacCodeScanner extends StatefulWidget {
  const MacCodeScanner({
    super.key,
    required this.onCode,
    this.decode = decodeQrFrame,
    this.camera,
    this.overlay,
  });

  final ValueChanged<String> onCode;
  final QrFrameDecode decode;
  final MacScannerCamera? camera;
  final Widget? overlay;

  @override
  State<MacCodeScanner> createState() => _MacCodeScannerState();
}

enum _CameraFailure { refused, unavailable }

class _MacCodeScannerState extends State<MacCodeScanner> {
  late final AppLifecycleListener _lifecycle;
  MacScannerCamera? _camera;
  int _session = 0;
  bool _live = false;
  _CameraFailure? _failure;
  Timer? _rest;
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _sleep,
      onShow: _wake,
      onResume: _retry,
    );
    _open();
  }

  void _open() {
    final MacScannerCamera camera = widget.camera ?? CameraMacosScannerCamera();
    _session += 1;
    _camera = camera;
    _live = false;
    _failure = null;
    unawaited(_scan(camera, _session));
  }

  void _close() {
    final MacScannerCamera? camera = _camera;
    _session += 1;
    _camera = null;
    _live = false;
    _failure = null;
    _rest?.cancel();
    if (camera != null) {
      unawaited(camera.stop());
    }
  }

  void _sleep() {
    if (_camera != null) {
      setState(_close);
    }
  }

  void _wake() {
    if (_camera == null) {
      setState(_open);
    }
  }

  void _retry() {
    if (_failure != null) {
      setState(() {
        _close();
        _open();
      });
    }
  }

  bool _current(int session) => mounted && session == _session;

  Future<void> _scan(MacScannerCamera camera, int session) async {
    try {
      await camera.start();
    } catch (error) {
      if (_current(session)) {
        setState(() {
          _failure = isCameraAccessRefusal(error)
              ? _CameraFailure.refused
              : _CameraFailure.unavailable;
        });
      }
      return;
    }
    if (!_current(session)) {
      return;
    }
    setState(() => _live = true);
    while (_current(session)) {
      final CameraImageData? frame = await camera.takeFrame();
      if (frame == null || !_current(session)) {
        return;
      }
      final Completer<void> rested = Completer<void>();
      _rest = Timer(macScanInterval, rested.complete);
      final String? code = await _decodeOrNull(frame);
      if (!_current(session)) {
        return;
      }
      _offer(code);
      await rested.future;
    }
  }

  void _offer(String? code) {
    if (code == null || code == _lastCode) {
      return;
    }
    _lastCode = code;
    widget.onCode(code);
  }

  Future<String?> _decodeOrNull(CameraImageData frame) async {
    try {
      return await widget.decode(frame);
    } catch (error, stackTrace) {
      debugPrint('Camera frame decode failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> _openSettings() async {
    try {
      await openCameraPrivacySettings();
    } catch (error) {
      debugPrint('Could not open camera privacy settings: $error');
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MacScannerCamera? camera = _camera;
    final Widget? overlay = widget.overlay;
    return SizedBox.expand(
      child: ColoredBox(
        color: context.colors.panelTop,
        child: switch (_failure) {
          null when camera != null => ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                KeyedSubtree(
                  key: ValueKey<int>(_session),
                  child: camera.preview(),
                ),
                if (_live && overlay != null) overlay,
              ],
            ),
          ),
          null => const SizedBox.expand(),
          _CameraFailure.refused => _notice(
            cameraAccessRefusedMessage,
            action: StickerButton(
              label: cameraSettingsLabel,
              variant: StickerButtonVariant.secondary,
              onPressed: _openSettings,
            ),
          ),
          _CameraFailure.unavailable => _notice(cameraUnavailableMessage),
        },
      ),
    );
  }

  Widget _notice(String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: _noticePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textStyles.bodySans,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: _noticeGap),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
