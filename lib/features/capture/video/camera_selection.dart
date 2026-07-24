import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'video_recorder.dart';

part 'camera_selection.g.dart';

String? resolveCameraDeviceId({
  required List<VideoCaptureDevice> devices,
  required String? rememberedId,
}) {
  if (devices.isEmpty) {
    return null;
  }
  for (final VideoCaptureDevice device in devices) {
    if (device.id == rememberedId) {
      return device.id;
    }
  }
  return devices.first.id;
}

@Riverpod(keepAlive: true)
class SelectedCameraDevice extends _$SelectedCameraDevice {
  @override
  String? build() => null;

  void remember(String deviceId) => state = deviceId;
}
