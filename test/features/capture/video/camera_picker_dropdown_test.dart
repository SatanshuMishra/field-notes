import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/widgets/anchored_dropdown.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

void main() {
  testWidgets('the camera picker opens the input picker\'s drop-down', (
    WidgetTester tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Material(
          child: Align(
            alignment: Alignment.topCenter,
            child: CameraPicker(
              devices: fakeVideoDevices,
              selectedDeviceId: fakeVideoDevices.first.id,
              onChanged: (String id) => picked = id,
            ),
          ),
        ),
      ),
    );

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(Pressable)));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );

    await tester.tap(find.byType(Pressable));
    await tester.pumpAndSettle();

    final AnchoredDropdown<String> dropdown = tester
        .widget<AnchoredDropdown<String>>(
          find.byType(AnchoredDropdown<String>),
        );
    expect(dropdown.tone, GlassTone.media);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    for (final device in fakeVideoDevices) {
      expect(find.text(device.label), findsWidgets);
    }
    expect(find.text(fakeVideoDevices.last.label), findsOneWidget);

    await tester.tap(find.text(fakeVideoDevices.last.label));
    await tester.pumpAndSettle();
    expect(picked, fakeVideoDevices.last.id);
  });
}
