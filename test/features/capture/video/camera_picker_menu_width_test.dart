import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const List<VideoCaptureDevice> _cameras = <VideoCaptureDevice>[
  VideoCaptureDevice(id: 'built-in', label: 'MacBook Pro Camera'),
  VideoCaptureDevice(id: 'desk', label: 'Logitech BRIO 4K Stream Edition'),
];

void main() {
  for (final MapEntry<String, Alignment> placement in <String, Alignment>{
    'start': Alignment.topLeft,
    'centre': Alignment.topCenter,
    'end': Alignment.topRight,
  }.entries) {
    testWidgets(
      'the camera picker at the ${placement.key} shows every camera in full, on screen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: fieldNotesTheme(platform: TargetPlatform.macOS),
            home: Material(
              child: Align(
                alignment: placement.value,
                child: CameraPicker(
                  devices: _cameras,
                  selectedDeviceId: _cameras.first.id,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(_cameras.first.label));
        await tester.pumpAndSettle();
        final Rect screen =
            Offset.zero &
            tester.view.physicalSize / tester.view.devicePixelRatio;
        for (final VideoCaptureDevice camera in _cameras) {
          final Finder label = find.text(camera.label).last;
          expect(
            tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isFalse,
            reason: '${camera.label} is cut off',
          );
          final Rect shown = tester.getRect(label);
          expect(
            shown.left >= screen.left &&
                shown.top >= screen.top &&
                shown.right <= screen.right &&
                shown.bottom <= screen.bottom,
            isTrue,
            reason: '${camera.label} drawn at $shown outside $screen',
          );
        }
      },
    );
  }
}
