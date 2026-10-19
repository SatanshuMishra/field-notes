import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

bool _bareOverlay(Decoration d) =>
    d is BoxDecoration &&
    d.color == null &&
    d.border == null &&
    d.boxShadow == null &&
    d.gradient == null &&
    d.image == null;

Finder faceBoxes() => find.byWidgetPredicate(
  (Widget w) =>
      w is DecoratedBox &&
      w.key != pressableHoverFillKey &&
      !_bareOverlay(w.decoration),
);
