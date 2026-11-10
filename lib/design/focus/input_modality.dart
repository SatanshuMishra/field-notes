import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final Set<LogicalKeyboardKey> _arrowKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
};

const int _spaceCodePoint = 0x20;
const int _deleteCodePoint = 0x7f;

bool _printsVisibleCharacter(String? character) {
  if (character == null || character.isEmpty) {
    return false;
  }
  final int codePoint = character.runes.first;
  return codePoint > _spaceCodePoint && codePoint != _deleteCodePoint;
}

bool _holdsShortcutModifier(HardwareKeyboard keyboard) =>
    keyboard.isMetaPressed ||
    (keyboard.isControlPressed && !keyboard.isAltPressed);

bool _primaryFocusEditsText() {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      Actions.maybeFind<ExtendSelectionByCharacterIntent>(context) != null;
}

bool _isTraversalKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.tab ||
    (_arrowKeys.contains(key) && !_primaryFocusEditsText());

final class InputModality extends ChangeNotifier {
  InputModality._();

  static final InputModality instance = InputModality._();

  bool _traversing = false;
  bool _watchingInput = false;

  bool get traversing =>
      _traversing ||
      FocusManager.instance.highlightStrategy ==
          FocusHighlightStrategy.alwaysTraditional;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _matchWatchingToListeners();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _matchWatchingToListeners();
  }

  void _matchWatchingToListeners() {
    if (hasListeners == _watchingInput) {
      return;
    }
    _watchingInput = hasListeners;
    if (_watchingInput) {
      HardwareKeyboard.instance.addHandler(_onKey);
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
      _traversing = false;
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) {
      return false;
    }
    if (_isTraversalKey(event.logicalKey)) {
      _setTraversing(true);
    } else if (_printsVisibleCharacter(event.character) &&
        !_holdsShortcutModifier(HardwareKeyboard.instance)) {
      _setTraversing(false);
    }
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _setTraversing(false);
    }
  }

  void _setTraversing(bool traversing) {
    if (traversing != _traversing) {
      _traversing = traversing;
      notifyListeners();
    }
  }
}
