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

  Future<void> start(ValueChanged<CameraImageData> onFrame);

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
  Future<void> start(ValueChanged<CameraImageData> onFrame) async {
    await _ready.future;
    if (_stopped) {
      return;
    }
    await CameraMacOSPlatform.instance.startImageStream((
      CameraImageData? frame,
    ) {
      if (frame != null) {
        onFrame(frame);
      }
    }, onError: _skipFrame);
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    final CameraMacOSController? controller = _controller;
    _controller = null;
    if (controller != null) {
      await _release(controller);
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
  });

  final ValueChanged<String> onCode;
  final QrFrameDecode decode;
  final MacScannerCamera? camera;

  @override
  State<MacCodeScanner> createState() => _MacCodeScannerState();
}

enum _CameraFailure { refused, unavailable }

class _MacCodeScannerState extends State<MacCodeScanner> {
  late final MacScannerCamera _camera;
  _CameraFailure? _failure;
  Timer? _pause;
  bool _decoding = false;
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _camera = widget.camera ?? CameraMacosScannerCamera();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _camera.start(_onFrame);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = isCameraAccessRefusal(error)
            ? _CameraFailure.refused
            : _CameraFailure.unavailable;
      });
    }
  }

  void _onFrame(CameraImageData frame) {
    if (!mounted || _failure != null || _decoding || _pause != null) {
      return;
    }
    _decoding = true;
    _pause = Timer(macScanInterval, () => _pause = null);
    unawaited(_decode(frame));
  }

  Future<void> _decode(CameraImageData frame) async {
    final String? code = await _decodeOrNull(frame);
    _decoding = false;
    if (code == null || code == _lastCode || !mounted) {
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
    _pause?.cancel();
    unawaited(_camera.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: context.colors.panelTop,
        child: switch (_failure) {
          null => ExcludeSemantics(child: _camera.preview()),
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
