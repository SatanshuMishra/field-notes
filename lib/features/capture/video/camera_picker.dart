import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'camera_selection.dart';
import 'video_recorder.dart';

const Color _pickerFill = Color(0x80140F0C);
const Color _pickerEdge = Color(0x38F3E6D1);
const Color _pickerInk = Color(0xFFF3E6D1);

const double _minTapTarget = 48;
const double _edgeWidth = 1;
const double _labelSize = 11;
const double _sidebarChevronSize = 14;
const double _bottomBarChevronSize = 12;
const double _sidebarChevronGap = 4;
const double _bottomBarChevronGap = 2;
const double _disabledOpacity = 0.5;
const BorderRadius _pickerRadius = BorderRadius.all(Radius.circular(16));
const EdgeInsets _sidebarPadding = EdgeInsets.fromLTRB(12, 7, 8, 7);
const EdgeInsets _bottomBarPadding = EdgeInsets.fromLTRB(10, 6, 6, 6);

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
  final GlobalKey<PopupMenuButtonState<String>> _menuKey =
      GlobalKey<PopupMenuButtonState<String>>();

  bool get _canOpen => widget.enabled && widget.onChanged != null;

  void _openMenu() => _menuKey.currentState?.showButtonMenu();

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
      child: Semantics(
        container: true,
        button: true,
        enabled: _canOpen,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _canOpen ? _openMenu : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: FocusRing(
                enabled: _canOpen,
                onPressed: _openMenu,
                surface: FocusRingSurface.dark,
                borderRadius: _pickerRadius,
                includeFocusSemantics: false,
                child: Material(
                  type: MaterialType.transparency,
                  child: ExcludeFocus(
                    child: PopupMenuButton<String>(
                      key: _menuKey,
                      enabled: _canOpen,
                      initialValue: resolved,
                      onSelected: widget.onChanged,
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            for (final VideoCaptureDevice device
                                in widget.devices)
                              PopupMenuItem<String>(
                                value: device.id,
                                child: Text(
                                  device.label,
                                  style: TypographyTokens.bodySans,
                                ),
                              ),
                          ],
                      child: _face(
                        current.label,
                        sidebar:
                            resolveShellLayout(Theme.of(context).platform) ==
                            ShellLayout.sidebar,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(String deviceLabel, {required bool sidebar}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _pickerFill,
        border: Border.fromBorderSide(
          BorderSide(color: _pickerEdge, width: _edgeWidth),
        ),
        borderRadius: _pickerRadius,
      ),
      child: Padding(
        padding: sidebar ? _sidebarPadding : _bottomBarPadding,
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
            SizedBox(
              width: sidebar ? _sidebarChevronGap : _bottomBarChevronGap,
            ),
            Icon(
              Icons.expand_more,
              size: sidebar ? _sidebarChevronSize : _bottomBarChevronSize,
              color: _pickerInk,
            ),
          ],
        ),
      ),
    );
  }
}
