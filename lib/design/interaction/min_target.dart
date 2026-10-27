import 'package:flutter/material.dart';

const double _androidMinTarget = 48;
const double _macosMinTarget = 28;
const double _windowsMinTarget = 40;

double minTargetOn(TargetPlatform platform) => switch (platform) {
  TargetPlatform.macOS => _macosMinTarget,
  TargetPlatform.windows => _windowsMinTarget,
  _ => _androidMinTarget,
};

class MinTarget extends StatelessWidget {
  const MinTarget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double target = minTargetOn(Theme.of(context).platform);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: target, minHeight: target),
      child: child,
    );
  }
}
