import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/media/decode_target.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../support/entry_cards_harness.dart';

void main() {
  group('MediaImage', () {
    late Directory root;
    late File file;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('fn_media_image');
      file = File('${root.path}/pic.png');
      await file.writeAsBytes(onePixelPngBytes());
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    MediaImage imageOf(MediaResolver resolver, {String? mediaId = 'p1'}) {
      return MediaImage(
        resolver: resolver,
        mediaId: mediaId,
        errorLabel: 'Photo',
        width: 72,
        height: 72,
      );
    }

    FakeMediaResolver resolverWithFile() => FakeMediaResolver()
      ..set(
        'p1',
        ResolvedMedia.available(
          blob: blobOf(id: 'p1', relPath: 'pic.png'),
          file: file,
        ),
      );

    testWidgets('renders the loading placeholder until the media resolves', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(cardHarness(imageOf(resolverWithFile())));

      expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders the corrupt placeholder when media is missing', (
      WidgetTester tester,
    ) async {
      final FakeMediaResolver resolver = FakeMediaResolver();
      await tester.pumpWidget(cardHarness(imageOf(resolver, mediaId: 'gone')));
      await tester.pump();

      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets(
      'does not render the corrupt placeholder when no id was ever assigned',
      (WidgetTester tester) async {
        final FakeMediaResolver resolver = FakeMediaResolver();
        await tester.pumpWidget(cardHarness(imageOf(resolver, mediaId: null)));
        await tester.pump();

        expect(find.byType(CorruptMediaPlaceholder), findsNothing);
        expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
      },
    );

    testWidgets('renders an Image when the file resolves', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(cardHarness(imageOf(resolverWithFile())));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    });

    testWidgets('a memo hit renders the image with no placeholder frame', (
      WidgetTester tester,
    ) async {
      final FakeMediaResolver resolver = resolverWithFile()..memoize('p1');

      await tester.pumpWidget(cardHarness(imageOf(resolver)));

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(NeutralMediaPlaceholder), findsNothing);
    });

    testWidgets('the decode target is quantised to a 64px bucket', (
      WidgetTester tester,
    ) async {
      final FakeMediaResolver resolver = resolverWithFile()..memoize('p1');

      await tester.pumpWidget(
        cardHarness(
          imageOf(resolver),
          data: const MediaQueryData(devicePixelRatio: 2),
        ),
      );

      final Image image = tester.widget<Image>(find.byType(Image));
      final ResizeImage provider = image.image as ResizeImage;
      expect(provider.width, 192);
      expect(provider.width! % decodeBucketPixels, 0);
      expect(provider.height, isNull);
    });

    testWidgets('an unsized box takes its decode target from its constraints', (
      WidgetTester tester,
    ) async {
      final FakeMediaResolver resolver = resolverWithFile()..memoize('p1');

      await tester.pumpWidget(
        cardHarness(
          MediaImage(
            resolver: resolver,
            mediaId: 'p1',
            errorLabel: 'Photo',
          ),
          width: 300,
          data: const MediaQueryData(devicePixelRatio: 1),
        ),
      );

      final Image image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).width, 320);
    });
  });
}
