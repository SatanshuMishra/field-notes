import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'macos_text_shortcuts.dart';

@immutable
final class MacosEditTarget {
  const MacosEditTarget({
    required this.focusNode,
    required this.undoController,
    required this.hasSelection,
  });

  final FocusNode focusNode;
  final UndoHistoryController undoController;
  final bool hasSelection;

  @override
  bool operator ==(Object other) =>
      other is MacosEditTarget &&
      identical(other.focusNode, focusNode) &&
      identical(other.undoController, undoController) &&
      other.hasSelection == hasSelection;

  @override
  int get hashCode => Object.hash(focusNode, undoController, hasSelection);
}

final class MacosEditRegistry extends ValueNotifier<MacosEditTarget?> {
  MacosEditRegistry() : super(null);

  static MacosEditRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MacosEditScope>()?.registry;

  void register(MacosEditTarget target) => value = target;

  void release(FocusNode focusNode) {
    if (identical(value?.focusNode, focusNode)) {
      value = null;
    }
  }
}

final class _MacosEditScope extends InheritedWidget {
  const _MacosEditScope({required this.registry, required super.child});

  final MacosEditRegistry registry;

  @override
  bool updateShouldNotify(_MacosEditScope oldWidget) =>
      !identical(oldWidget.registry, registry);
}

typedef _EditState = ({
  bool focused,
  bool canUndo,
  bool canRedo,
  bool hasSelection,
});

const _EditState _unfocused = (
  focused: false,
  canUndo: false,
  canRedo: false,
  hasSelection: false,
);

class MacosMenuBar extends StatefulWidget {
  const MacosMenuBar({super.key, required this.child});

  final Widget child;

  @override
  State<MacosMenuBar> createState() => _MacosMenuBarState();
}

class _MacosMenuBarState extends State<MacosMenuBar> {
  final MacosEditRegistry _registry = MacosEditRegistry();

  Listenable? _watched;
  bool _installed = false;
  bool _refreshScheduled = false;
  late _EditState _edit;
  late List<PlatformMenuItem> _menus;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_refresh);
    _registry.addListener(_refresh);
    _edit = _unfocused;
    _menus = _menusFor(_unfocused);
    _refreshAfterFrame();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_refresh);
    _registry
      ..removeListener(_refresh)
      ..dispose();
    _watched?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _refreshAfterFrame();
      return;
    }
    final _EditState next = _track();
    if (next == _edit && _installed) {
      return;
    }
    setState(() {
      _installed = true;
      if (next != _edit) {
        _edit = next;
        _menus = _menusFor(next);
      }
    });
  }

  void _refreshAfterFrame() {
    if (_refreshScheduled) {
      return;
    }
    _refreshScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((Duration _) {
        _refreshScheduled = false;
        _refresh();
      })
      ..ensureVisualUpdate();
  }

  _EditState _track() {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    final MacosEditTarget? target = _registry.value;
    if (focus != null && target != null && identical(target.focusNode, focus)) {
      _watch(target.undoController);
      final UndoHistoryValue history = target.undoController.value;
      return (
        focused: true,
        canUndo: history.canUndo,
        canRedo: history.canRedo,
        hasSelection: target.hasSelection,
      );
    }
    final EditableTextState? field = focusedEditableText();
    if (field == null) {
      _watch(null);
      return _unfocused;
    }
    _watch(field.widget.controller);
    final TextSelection selection = field.textEditingValue.selection;
    return (
      focused: true,
      canUndo: true,
      canRedo: true,
      hasSelection: selection.isValid && !selection.isCollapsed,
    );
  }

  void _watch(Listenable? next) {
    if (identical(next, _watched)) {
      return;
    }
    _watched?.removeListener(_refresh);
    _watched = next;
    next?.addListener(_refresh);
  }

  static void _invokeOnFocus(Intent intent) {
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) {
      return;
    }
    Actions.maybeInvoke<Intent>(context, intent);
  }

  static PlatformMenuItem _editItem(
    String label,
    SingleActivator shortcut,
    Intent intent, {
    required bool enabled,
  }) => PlatformMenuItem(
    label: label,
    shortcut: shortcut,
    onSelected: enabled ? () => _invokeOnFocus(intent) : null,
  );

  static List<PlatformMenuItem> _menusFor(
    _EditState edit,
  ) => <PlatformMenuItem>[
    const PlatformMenu(
      label: 'Field Notes',
      menus: <PlatformMenuItem>[
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.servicesSubmenu,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.hideOtherApplications,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.showAllApplications,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
      ],
    ),
    PlatformMenu(
      label: 'Edit',
      menus: <PlatformMenuItem>[
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            _editItem(
              'Undo',
              const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              const UndoTextIntent(SelectionChangedCause.keyboard),
              enabled: edit.canUndo,
            ),
            _editItem(
              'Redo',
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
              const RedoTextIntent(SelectionChangedCause.keyboard),
              enabled: edit.canRedo,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            _editItem(
              'Cut',
              const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
              enabled: edit.hasSelection,
            ),
            _editItem(
              'Copy',
              const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              CopySelectionTextIntent.copy,
              enabled: edit.hasSelection,
            ),
            _editItem(
              'Paste',
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              const PasteTextIntent(SelectionChangedCause.keyboard),
              enabled: edit.focused,
            ),
            _editItem(
              'Select All',
              const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
              const SelectAllTextIntent(SelectionChangedCause.keyboard),
              enabled: edit.focused,
            ),
          ],
        ),
      ],
    ),
    const PlatformMenu(
      label: 'Window',
      menus: <PlatformMenuItem>[
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: <PlatformMenuItem>[
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => _MacosEditScope(
    registry: _registry,
    child: Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        if (_installed)
          Positioned(
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            child: PlatformMenuBar(menus: _menus),
          ),
      ],
    ),
  );
}
