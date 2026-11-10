import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/features/note_engine/editor/text_input_focus.dart';

const Duration transportSkipStep = Duration(seconds: 10);
const Duration transportNudgeStep = Duration(seconds: 5);
const Duration transportFrameStep = Duration(microseconds: 33333);
const double transportVolumeStep = 0.05;

const List<LogicalKeyboardKey> _digitRow = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

const List<LogicalKeyboardKey> _numberPad = <LogicalKeyboardKey>[
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

final Set<LogicalKeyboardKey> _repeatableKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.keyJ,
  LogicalKeyboardKey.keyL,
  LogicalKeyboardKey.comma,
  LogicalKeyboardKey.period,
};

Map<LogicalKeyboardKey, VoidCallback> transportKeyBindings({
  required VoidCallback? onToggle,
  required ValueChanged<Duration>? onSeekBy,
  required ValueChanged<double>? onSeekToShare,
  required ValueChanged<double> onVolumeBy,
  required VoidCallback onMute,
  required VoidCallback? onFullScreen,
  required ValueChanged<Duration>? onFrameStep,
}) => Map<LogicalKeyboardKey, VoidCallback>.unmodifiable(
  <LogicalKeyboardKey, VoidCallback>{
    if (onToggle != null) ...<LogicalKeyboardKey, VoidCallback>{
      LogicalKeyboardKey.space: onToggle,
      LogicalKeyboardKey.keyK: onToggle,
    },
    if (onSeekBy != null) ...<LogicalKeyboardKey, VoidCallback>{
      LogicalKeyboardKey.keyJ: () => onSeekBy(-transportSkipStep),
      LogicalKeyboardKey.keyL: () => onSeekBy(transportSkipStep),
      LogicalKeyboardKey.arrowLeft: () => onSeekBy(-transportNudgeStep),
      LogicalKeyboardKey.arrowRight: () => onSeekBy(transportNudgeStep),
    },
    LogicalKeyboardKey.arrowUp: () => onVolumeBy(transportVolumeStep),
    LogicalKeyboardKey.arrowDown: () => onVolumeBy(-transportVolumeStep),
    LogicalKeyboardKey.keyM: onMute,
    LogicalKeyboardKey.keyF: ?onFullScreen,
    if (onSeekToShare != null) ...<LogicalKeyboardKey, VoidCallback>{
      LogicalKeyboardKey.home: () => onSeekToShare(0),
      LogicalKeyboardKey.end: () => onSeekToShare(1),
      for (
        int digit = 0;
        digit < _digitRow.length;
        digit++
      ) ...<LogicalKeyboardKey, VoidCallback>{
        _digitRow[digit]: () => onSeekToShare(digit / _digitRow.length),
        _numberPad[digit]: () => onSeekToShare(digit / _digitRow.length),
      },
    },
    if (onFrameStep != null) ...<LogicalKeyboardKey, VoidCallback>{
      LogicalKeyboardKey.comma: () => onFrameStep(-transportFrameStep),
      LogicalKeyboardKey.period: () => onFrameStep(transportFrameStep),
    },
  },
);

class TransportKeys extends StatelessWidget {
  const TransportKeys({
    super.key,
    required this.bindings,
    required this.child,
    this.takesFocus = false,
    this.autofocus = false,
    this.onHandled,
  });

  final Map<LogicalKeyboardKey, VoidCallback> bindings;
  final Widget child;
  final bool takesFocus;
  final bool autofocus;
  final VoidCallback? onHandled;

  bool get _chordHeld =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isAltPressed;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _chordHeld || isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (event is KeyRepeatEvent && !_repeatableKeys.contains(key)) {
      return KeyEventResult.ignored;
    }
    final VoidCallback? action = bindings[key];
    if (action == null) {
      return KeyEventResult.ignored;
    }
    action();
    onHandled?.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      debugLabel: 'transport keys',
      canRequestFocus: takesFocus,
      skipTraversal: true,
      autofocus: autofocus,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: child,
    );
  }
}
