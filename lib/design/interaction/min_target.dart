import 'package:flutter/material.dart';

const double _androidMinTarget = 48;
const double _windowsMinTarget = 40;
const double _macosDenseControlMinTarget = 28;
const double _macosIconMinTarget = 32;
const double _macosButtonMinTarget = 36;

double _targetOn(TargetPlatform platform, {required double macos}) =>
    switch (platform) {
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => _windowsMinTarget,
      _ => _androidMinTarget,
    };

double minTargetOn(TargetPlatform platform) =>
    _targetOn(platform, macos: _macosDenseControlMinTarget);

double minIconTargetOn(TargetPlatform platform) =>
    _targetOn(platform, macos: _macosIconMinTarget);

double minButtonTargetOn(TargetPlatform platform) =>
    _targetOn(platform, macos: _macosButtonMinTarget);

class MinTarget extends StatelessWidget {
  const MinTarget({super.key, required this.child}) : _targetFor = minTargetOn;

  const MinTarget.icon({super.key, required this.child})
    : _targetFor = minIconTargetOn;

  const MinTarget.button({super.key, required this.child})
    : _targetFor = minButtonTargetOn;

  final Widget child;
  final double Function(TargetPlatform platform) _targetFor;

  @override
  Widget build(BuildContext context) {
    final double target = _targetFor(Theme.of(context).platform);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: target, minHeight: target),
      child: child,
    );
  }
}
