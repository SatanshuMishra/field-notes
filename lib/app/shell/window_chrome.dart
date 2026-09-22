import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const double shellTitleBarHeight = 42;
const double shellTitleBarPadding = 16;
const double windowButtonsSlotWidth = 62;

const Key windowTitleBarKey = ValueKey<String>('window-titlebar');

const String windowChannelName = 'field_notes/window';
const String startDragMethod = 'startDrag';
const String titlebarDoubleClickMethod = 'titlebarDoubleClick';

const MethodChannel windowChannel = MethodChannel(windowChannelName);

Future<void> startWindowDrag() => _invokeWindow(startDragMethod);

Future<void> runTitlebarDoubleClick() =>
    _invokeWindow(titlebarDoubleClickMethod);

Future<void> _invokeWindow(String method) async {
  try {
    await windowChannel.invokeMethod<void>(method);
  } on MissingPluginException {
    return;
  }
}
