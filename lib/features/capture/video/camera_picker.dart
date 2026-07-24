import 'package:flutter/material.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';

import 'camera_selection.dart';
import 'video_recorder.dart';

class CameraPicker extends StatelessWidget {
  const CameraPicker({
    super.key,
    required this.devices,
    required this.selectedDeviceId,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Camera',
  });

  final List<VideoCaptureDevice> devices;
  final String? selectedDeviceId;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String? resolved = resolveCameraDeviceId(
      devices: devices,
      rememberedId: selectedDeviceId,
    );
    if (resolved == null) {
      return const SizedBox.shrink();
    }
    return SettingsFieldRow(
      label: label,
      control: Material(
        type: MaterialType.transparency,
        child: SettingsSelect<String>(
          options: <SettingsSelectOption<String>>[
            for (final VideoCaptureDevice device in devices)
              SettingsSelectOption<String>(
                value: device.id,
                label: device.label,
              ),
          ],
          value: resolved,
          onChanged: onChanged,
          enabled: enabled,
        ),
      ),
    );
  }
}
