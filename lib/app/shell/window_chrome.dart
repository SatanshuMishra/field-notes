import 'package:field_notes/domain/settings/appearance.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const double shellTitleBarHeight = 42;
const double shellTitleBarPadding = 16;
const double windowButtonsSlotWidth = 62;
const double windowButtonsClearance =
    shellTitleBarPadding + windowButtonsSlotWidth;

const Key windowTitleBarKey = ValueKey<String>('window-titlebar');

const String windowChannelName = 'field_notes/window';
const String startDragMethod = 'startDrag';
const String titlebarDoubleClickMethod = 'titlebarDoubleClick';
const String setAppearanceMethod = 'setAppearance';

const MethodChannel windowChannel = MethodChannel(windowChannelName);

Future<void> startWindowDrag() => _invokeWindow(startDragMethod);

Future<void> runTitlebarDoubleClick() =>
    _invokeWindow(titlebarDoubleClickMethod);

Future<void> setWindowAppearance(Appearance value) =>
    _invokeWindow(setAppearanceMethod, value.id);

Future<void> _invokeWindow(String method, [Object? arguments]) async {
  try {
    await windowChannel.invokeMethod<void>(method, arguments);
  } on MissingPluginException {
    return;
  }
}
