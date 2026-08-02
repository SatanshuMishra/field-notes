import 'package:flutter/material.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'camera_selection.dart';
import 'video_recorder.dart';

const double _pickerBorderWidth = 1.5;

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
      labelColor: Palette.onDark72,
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
          surface: Palette.viewportScrim,
          foreground: Palette.onAccent,
          border: Border.all(
            color: Palette.onDark40,
            width: _pickerBorderWidth,
          ),
        ),
      ),
    );
  }
}
