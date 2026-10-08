import 'package:flutter/services.dart';

const MethodChannel cameraSettingsChannel = MethodChannel(
  'field_notes/camera_settings',
);

Future<void> openCameraPrivacySettings() =>
    cameraSettingsChannel.invokeMethod<void>('openCameraSettings');
