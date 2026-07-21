import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/capture/photo/photo_thumbnail.dart';
import 'package:field_notes/features/capture/photo/photo_tray.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_test_support.dart';

CaptureBytes _samplePhoto() =>
    CaptureBytes(bytes: tinyPngBytes, mime: 'image/png');

StickerButton _buttonFor(WidgetTester tester, String label) {
  return tester.widget<StickerButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(StickerButton),
    ),
  );
}

void main() {
  testWidgets('adds picked library photos in order and reports the selection',
      (WidgetTester tester) async {
    final CaptureMedia a = _samplePhoto();
    final CaptureMedia b = _samplePhoto();
    final List<List<CaptureMedia>> emitted = <List<CaptureMedia>>[];
    final FakePhotoPicker picker = FakePhotoPicker(
      supportsCamera: false,
      libraryResult: <CaptureMedia>[a, b],
    );

    await tester.pumpWidget(
      photoHarness(PhotoTray(picker: picker, onChanged: emitted.add)),
    );
    await tester.tap(find.text('Add from library'));
    await tester.pumpAndSettle();

    expect(picker.libraryCalls, 1);
    expect(find.byType(PhotoThumbnail), findsNWidgets(2));
    expect(emitted, hasLength(1));
    expect(emitted.single, <CaptureMedia>[a, b]);
  });

  testWidgets('removing a photo drops it and re-reports the selection',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final CaptureMedia a = _samplePhoto();
    final CaptureMedia b = _samplePhoto();
    final List<List<CaptureMedia>> emitted = <List<CaptureMedia>>[];
    final FakePhotoPicker picker = FakePhotoPicker(
      supportsCamera: false,
      libraryResult: <CaptureMedia>[a, b],
    );

    await tester.pumpWidget(
      photoHarness(PhotoTray(picker: picker, onChanged: emitted.add)),
    );
    await tester.tap(find.text('Add from library'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Remove photo 1'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoThumbnail), findsOneWidget);
    expect(emitted.last, <CaptureMedia>[b]);
    handle.dispose();
  });

  testWidgets('surfaces a clear message when the library pick fails',
      (WidgetTester tester) async {
    final List<List<CaptureMedia>> emitted = <List<CaptureMedia>>[];
    final FakePhotoPicker picker = FakePhotoPicker(
      supportsCamera: false,
      libraryError: const PhotoPickException(photoLibraryErrorMessage),
    );

    await tester.pumpWidget(
      photoHarness(PhotoTray(picker: picker, onChanged: emitted.add)),
    );
    await tester.tap(find.text('Add from library'));
    await tester.pumpAndSettle();

    expect(find.text(photoLibraryErrorMessage), findsOneWidget);
    expect(find.byType(PhotoThumbnail), findsNothing);
    expect(emitted, isEmpty);
  });

  testWidgets('offers camera capture only when the picker supports it',
      (WidgetTester tester) async {
    final CaptureMedia shot = _samplePhoto();
    final List<List<CaptureMedia>> emitted = <List<CaptureMedia>>[];
    final FakePhotoPicker picker =
        FakePhotoPicker(cameraResult: shot);

    await tester.pumpWidget(
      photoHarness(PhotoTray(picker: picker, onChanged: emitted.add)),
    );

    expect(find.text('Take a photo'), findsOneWidget);
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(picker.cameraCalls, 1);
    expect(emitted.single, <CaptureMedia>[shot]);
  });

  testWidgets('hides camera capture when the picker does not support it',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      photoHarness(
        PhotoTray(
          picker: FakePhotoPicker(supportsCamera: false),
          onChanged: (List<CaptureMedia> _) {},
        ),
      ),
    );

    expect(find.text('Take a photo'), findsNothing);
    expect(find.text('Add from library'), findsOneWidget);
  });

  testWidgets('stops adding once the maximum is reached',
      (WidgetTester tester) async {
    final List<List<CaptureMedia>> emitted = <List<CaptureMedia>>[];
    final FakePhotoPicker picker = FakePhotoPicker(
      supportsCamera: false,
      libraryResult: <CaptureMedia>[
        _samplePhoto(),
        _samplePhoto(),
        _samplePhoto(),
      ],
    );

    await tester.pumpWidget(
      photoHarness(
        PhotoTray(picker: picker, onChanged: emitted.add, maxPhotos: 2),
      ),
    );
    await tester.tap(find.text('Add from library'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoThumbnail), findsNWidgets(2));
    expect(emitted.last, hasLength(2));
    expect(_buttonFor(tester, 'Add from library').isEnabled, isFalse);
  });
}
