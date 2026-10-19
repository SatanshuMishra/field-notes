import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const int _mousePointer = 41;
const int _mouseDevice = 1;
const Key _enabledKey = ValueKey<String>('enabled');
const Key _disabledKey = ValueKey<String>('disabled');
const Key _inertKey = ValueKey<String>('inert');

Widget _ring({
  required Key key,
  required VoidCallback? onPressed,
  bool enabled = true,
}) => FocusRing(
  key: key,
  enabled: enabled,
  onPressed: onPressed,
  child: const SizedBox(width: 120, height: 48),
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

void main() {
  testWidgets('a focus ring around an enabled action shows the click cursor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ring(key: _enabledKey, onPressed: () {}),
              const SizedBox(height: 24),
              _ring(key: _disabledKey, onPressed: () {}, enabled: false),
              const SizedBox(height: 24),
              _ring(key: _inertKey, onPressed: null),
            ],
          ),
        ),
      ),
    );
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: _mousePointer,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byKey(_enabledKey)));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.click);

    await mouse.moveTo(tester.getCenter(find.byKey(_disabledKey)));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.basic);

    await mouse.moveTo(tester.getCenter(find.byKey(_inertKey)));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.basic);
  });
}
