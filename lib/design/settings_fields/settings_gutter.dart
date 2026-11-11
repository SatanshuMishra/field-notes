import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:flutter/widgets.dart';

const double settingsGutter = HoverStyle.fillInset;

abstract interface class CarriesSettingsGutter {}

class SettingsGutter extends InheritedWidget {
  const SettingsGutter({
    super.key,
    required this.padding,
    this.minHeight = 0,
    required super.child,
  });

  const SettingsGutter.none({super.key, required super.child})
    : padding = EdgeInsets.zero,
      minHeight = 0;

  final EdgeInsets padding;
  final double minHeight;

  bool get framesRows => padding != EdgeInsets.zero || minHeight > 0;

  @override
  bool updateShouldNotify(SettingsGutter oldWidget) =>
      oldWidget.padding != padding || oldWidget.minHeight != minHeight;
}

class SettingsGutterCarrier extends StatelessWidget
    implements CarriesSettingsGutter {
  const SettingsGutterCarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class SettingsRowFrame extends StatelessWidget {
  const SettingsRowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SettingsGutter? gutter = context
        .dependOnInheritedWidgetOfExactType<SettingsGutter>();
    if (gutter == null || !gutter.framesRows) {
      return child;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: gutter.minHeight),
      child: Padding(
        padding: gutter.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[SettingsGutter.none(child: child)],
        ),
      ),
    );
  }
}
