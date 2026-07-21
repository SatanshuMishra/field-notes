import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/photo_thumbnail.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_test_support.dart';

void main() {
  testWidgets('renders decodable photo bytes as an image',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      photoHarness(
        PhotoThumbnail(
          media: CaptureBytes(bytes: tinyPngBytes, mime: 'image/png'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PhotoThumbnail), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
