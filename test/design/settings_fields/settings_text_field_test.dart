import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';

import 'settings_harness.dart';

void main() {
  group('SettingsTextField', () {
    testWidgets('shows the hint only while empty and updates the controller',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      String? seen;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 260,
            child: SettingsTextField(
              controller: controller,
              hintText: 'https://journal.example.com',
              onChanged: (String v) => seen = v,
            ),
          ),
        ),
      );

      expect(find.text('https://journal.example.com'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'https://a.b');
      await tester.pump();

      expect(controller.text, 'https://a.b');
      expect(seen, 'https://a.b');
      expect(find.text('https://journal.example.com'), findsNothing);
    });

    testWidgets('is read-only and dimmed when disabled',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 260,
            child: SettingsTextField(
              controller: controller,
              enabled: false,
            ),
          ),
        ),
      );

      final EditableText editable =
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.readOnly, isTrue);

      final double opacity = tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(SettingsTextField),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, 0.5);
    });

    testWidgets('gains focus when tapped', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 260,
            child: SettingsTextField(controller: controller),
          ),
        ),
      );

      final EditableText before =
          tester.widget<EditableText>(find.byType(EditableText));
      expect(before.focusNode.hasFocus, isFalse);

      await tester.tap(find.byType(SettingsTextField));
      await tester.pump();

      final EditableText after =
          tester.widget<EditableText>(find.byType(EditableText));
      expect(after.focusNode.hasFocus, isTrue);
    });

    testWidgets('gains focus when clicked in its padding',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 260,
            child: SettingsTextField(controller: controller),
          ),
        ),
      );

      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final Rect field = tester.getRect(find.byType(SettingsTextField));
      for (final Offset inset in const <Offset>[
        Offset(4, 4),
        Offset(130, 3),
        Offset(6, 20),
      ]) {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await mouse.moveTo(field.topLeft + inset);
        await tester.pump();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.text,
        );
        await mouse.down(field.topLeft + inset);
        await mouse.up();
        await tester.pump();
        final EditableText editable =
            tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.focusNode.hasFocus, isTrue, reason: 'click at $inset');
      }
    });

    testWidgets('cannot gain focus via tap when disabled',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 260,
            child: SettingsTextField(
              controller: controller,
              enabled: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SettingsTextField));
      await tester.pump();

      final EditableText editable =
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.canRequestFocus, isFalse);
      expect(editable.focusNode.hasFocus, isFalse);
    });
  });

  group('SettingsSecretField', () {
    testWidgets('obscures its input',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 260,
            child: SettingsSecretField(
              controller: controller,
              hintText: '••••••••',
            ),
          ),
        ),
      );

      final EditableText editable =
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isTrue);
    });
  });
}
