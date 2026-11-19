import 'package:flutter/widgets.dart';

Future<T?> showFullWindowRoute<T>(
  BuildContext context, {
  required String barrierLabel,
  required Color barrierColor,
  required Duration transitionDuration,
  required RoutePageBuilder pageBuilder,
  required RouteTransitionsBuilder transitionBuilder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    FullWindowRoute<T>(
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      transitionDuration: transitionDuration,
      pageBuilder: pageBuilder,
      transitionBuilder: transitionBuilder,
    ),
  );
}

class FullWindowRoute<T> extends RawDialogRoute<T> {
  FullWindowRoute({
    required String super.barrierLabel,
    required Color super.barrierColor,
    required super.transitionDuration,
    required super.pageBuilder,
    required RouteTransitionsBuilder super.transitionBuilder,
  }) : super(barrierDismissible: false);

  @override
  Widget buildModalBarrier() {
    return BlockSemantics(
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: AbsorbPointer(child: _backdropFill()),
        ),
      ),
    );
  }

  Widget _backdropFill() {
    final Color? tint = barrierColor;
    if (tint == null || tint.a == 0) {
      return const SizedBox.expand();
    }
    return FadeTransition(
      opacity: animation!.drive(CurveTween(curve: barrierCurve)),
      child: SizedBox.expand(child: ColoredBox(color: tint)),
    );
  }
}
