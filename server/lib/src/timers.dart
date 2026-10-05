import 'dart:async';

typedef StartTimer = Timer Function(
  Duration duration,
  void Function() callback,
);
