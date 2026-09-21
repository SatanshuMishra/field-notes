import 'package:flutter/widgets.dart';

class NoteRenderBudget extends InheritedWidget {
  const NoteRenderBudget({
    super.key,
    this.floatEnabled = true,
    required super.child,
  });

  final bool floatEnabled;

  static bool floatEnabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NoteRenderBudget>()
          ?.floatEnabled ??
      true;

  @override
  bool updateShouldNotify(NoteRenderBudget oldWidget) =>
      floatEnabled != oldWidget.floatEnabled;
}
