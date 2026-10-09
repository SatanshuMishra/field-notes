import 'dart:async';

import 'package:field_notes/domain/settings/appearance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const double shellTitleBarHeight = 42;
const double shellTitleBarPadding = 16;
const double windowButtonsSlotWidth = 62;
const double windowButtonsClearance =
    shellTitleBarPadding + windowButtonsSlotWidth;
const double windowsCaptionButtonWidth = 46;
const double windowsCaptionButtonsWidth = 3 * windowsCaptionButtonWidth;
const double windowResizeBandHeight = 4;

const Key windowTitleBarKey = ValueKey<String>('window-titlebar');

const String windowChannelName = 'field_notes/window';
const String startDragMethod = 'startDrag';
const String titlebarDoubleClickMethod = 'titlebarDoubleClick';
const String setAppearanceMethod = 'setAppearance';
const String minimizeMethod = 'minimize';
const String maximizeOrRestoreMethod = 'maximizeOrRestore';
const String closeMethod = 'close';
const String startResizeMethod = 'startResize';
const String windowStateMethod = 'windowState';
const String stateChangedMethod = 'stateChanged';
const String windowHandleMethod = 'windowHandle';

const MethodChannel windowChannel = MethodChannel(windowChannelName);

double windowButtonsLeadingClearance(TargetPlatform platform) =>
    platform == TargetPlatform.macOS ? windowButtonsClearance : 0;

double windowButtonsTrailingClearance(TargetPlatform platform) =>
    platform == TargetPlatform.windows ? windowsCaptionButtonsWidth : 0;

double windowButtonsSlotWidthFor(TargetPlatform platform) =>
    platform == TargetPlatform.windows
    ? windowsCaptionButtonsWidth - shellTitleBarPadding
    : windowButtonsSlotWidth;

Future<void> startWindowDrag() => _invokeWindow(startDragMethod);

Future<void> runTitlebarDoubleClick() =>
    _invokeWindow(titlebarDoubleClickMethod);

Future<void> setWindowAppearance(Appearance value) =>
    _invokeWindow(setAppearanceMethod, value.id);

Future<void> minimizeWindow() => _invokeWindow(minimizeMethod);

Future<void> maximizeOrRestoreWindow() =>
    _invokeWindow(maximizeOrRestoreMethod);

Future<void> closeWindow() => _invokeWindow(closeMethod);

Future<void> startWindowResize(String edge) =>
    _invokeWindow(startResizeMethod, edge);

Future<int?> windowHandle() async {
  try {
    return await windowChannel.invokeMethod<int>(windowHandleMethod);
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<void> _invokeWindow(String method, [Object? arguments]) async {
  try {
    await windowChannel.invokeMethod<void>(method, arguments);
  } on MissingPluginException {
    return;
  }
}

@immutable
final class WindowState {
  const WindowState({required this.maximized, required this.active});

  final bool maximized;
  final bool active;

  @override
  bool operator ==(Object other) {
    return other is WindowState &&
        other.maximized == maximized &&
        other.active == active;
  }

  @override
  int get hashCode => Object.hash(maximized, active);
}

final class WindowStateChannel {
  WindowStateChannel({this._channel = windowChannel});

  static final WindowStateChannel instance = WindowStateChannel();

  final MethodChannel _channel;
  late final _WindowStateNotifier _state = _WindowStateNotifier(
    onFirstListener: _listen,
    onLastListener: () => _channel.setMethodCallHandler(null),
  );

  ValueListenable<WindowState> get state => _state;

  void _listen() {
    _channel.setMethodCallHandler(_handle);
    unawaited(_ask());
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method != stateChangedMethod) {
      return;
    }
    final WindowState? next = _windowStateFrom(call.arguments);
    if (next != null) {
      _state.value = next;
    }
  }

  Future<void> _ask() async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>(windowStateMethod);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
    final WindowState? current = _windowStateFrom(reply);
    if (current != null) {
      _state.value = current;
    }
  }
}

final class _WindowStateNotifier extends ValueNotifier<WindowState> {
  _WindowStateNotifier({
    required this.onFirstListener,
    required this.onLastListener,
  }) : super(const WindowState(maximized: false, active: true));

  final VoidCallback onFirstListener;
  final VoidCallback onLastListener;

  @override
  void addListener(VoidCallback listener) {
    final bool first = !hasListeners;
    super.addListener(listener);
    if (first) {
      onFirstListener();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      onLastListener();
    }
  }
}

WindowState? _windowStateFrom(Object? arguments) {
  if (arguments is! Map<Object?, Object?>) {
    return null;
  }
  final Object? maximized = arguments['maximized'];
  final Object? active = arguments['active'];
  if (maximized is! bool || active is! bool) {
    return null;
  }
  return WindowState(maximized: maximized, active: active);
}

class WindowDragBand extends StatelessWidget {
  const WindowDragBand({
    super.key,
    this.height = shellTitleBarHeight,
    this.child,
  });

  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onPanStart: (DragStartDetails _) => unawaited(startWindowDrag()),
      onDoubleTap: () => unawaited(runTitlebarDoubleClick()),
      child: SizedBox(width: double.infinity, height: height, child: child),
    );
  }
}
