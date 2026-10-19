import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/anchored_dropdown.dart';

import 'camera_selection.dart';
import 'video_recorder.dart';

const Color _pickerFill = Color(0x80140F0C);
const Color _pickerEdge = Color(0x38F3E6D1);
const Color _pickerInk = Color(0xFFF3E6D1);

const double _minTapTarget = 48;
const double _edgeWidth = 1;
const double _labelSize = 11;
const double _chevronSize = 14;
const double _chevronGap = 4;
const double _disabledOpacity = 0.5;
const BorderRadius _pickerRadius = BorderRadius.all(Radius.circular(16));
const EdgeInsets _padding = EdgeInsets.fromLTRB(12, 7, 8, 7);

class CameraPicker extends StatefulWidget {
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
  State<CameraPicker> createState() => _CameraPickerState();
}

class _CameraPickerState extends State<CameraPicker> {
  bool get _canOpen => widget.enabled && widget.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final String? resolved = resolveCameraDeviceId(
      devices: widget.devices,
      rememberedId: widget.selectedDeviceId,
    );
    if (resolved == null) {
      return const SizedBox.shrink();
    }
    final VideoCaptureDevice current = widget.devices.firstWhere(
      (VideoCaptureDevice device) => device.id == resolved,
    );
    return Opacity(
      opacity: widget.enabled ? 1.0 : _disabledOpacity,
      child: AnchoredDropdown<String>(
        tone: GlassTone.media,
        ink: _pickerInk,
        choices: <AnchoredDropdownChoice<String>>[
          for (final VideoCaptureDevice device in widget.devices)
            AnchoredDropdownChoice<String>(
              value: device.id,
              label: device.label,
            ),
        ],
        current: resolved,
        onSelected: (String id) => widget.onChanged?.call(id),
        builder: (BuildContext context, bool open, VoidCallback toggle) =>
            Pressable(
              includeFocusSemantics: false,
              label: widget.label,
              onPressed: _canOpen ? toggle : null,
              borderRadius: _pickerRadius,
              surface: FocusRingSurface.dark,
              paintsHover: false,
              ringsFace: true,
              builder: (BuildContext context, bool hovered) => ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _minTapTarget,
                  minHeight: _minTapTarget,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: FocusRingFace(
                    child: HoverFill(
                      hovered: hovered,
                      surface: FocusRingSurface.dark,
                      borderRadius: _pickerRadius,
                      child: _face(current.label),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _face(String deviceLabel) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _pickerFill,
        border: Border.fromBorderSide(
          BorderSide(color: _pickerEdge, width: _edgeWidth),
        ),
        borderRadius: _pickerRadius,
      ),
      child: Padding(
        padding: _padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                deviceLabel,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: _labelSize,
                  fontWeight: FontWeight.w600,
                  color: _pickerInk,
                ),
              ),
            ),
            const SizedBox(width: _chevronGap),
            const Icon(
              Icons.expand_more,
              size: _chevronSize,
              color: _pickerInk,
            ),
          ],
        ),
      ),
    );
  }
}
