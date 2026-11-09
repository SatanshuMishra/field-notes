import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final Set<LogicalKeyboardKey> _traversalKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.tab,
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

bool _editsText(BuildContext context) =>
    Actions.maybeFind<ExtendSelectionByCharacterIntent>(context) != null;

final class InputModality extends ChangeNotifier {
  InputModality._();

  static final InputModality instance = InputModality._();

  bool _traversing = false;
  bool _watchingInput = false;
  FocusNode? _textFocusUnderTraversalKey;

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
      FocusManager.instance.addListener(_onPrimaryFocusChanged);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
      FocusManager.instance.removeListener(_onPrimaryFocusChanged);
      _traversing = false;
      _textFocusUnderTraversalKey = null;
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) {
      _textFocusUnderTraversalKey = null;
    } else if (_traversalKeys.contains(event.logicalKey)) {
      _onTraversalKey();
    } else if (_printsVisibleCharacter(event.character) &&
        !_holdsShortcutModifier(HardwareKeyboard.instance)) {
      _setTraversing(false);
    }
    return false;
  }

  void _onTraversalKey() {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    final BuildContext? context = focus?.context;
    if (context != null && _editsText(context)) {
      _textFocusUnderTraversalKey = focus;
    } else {
      _setTraversing(true);
    }
  }

  void _onPrimaryFocusChanged() {
    final FocusNode? textFocus = _textFocusUnderTraversalKey;
    if (textFocus != null &&
        !identical(FocusManager.instance.primaryFocus, textFocus)) {
      _textFocusUnderTraversalKey = null;
      _setTraversing(true);
    }
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
