import 'package:flutter/material.dart';

class DialogHost extends StatelessWidget {
  const DialogHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: child,
    );
  }
}
