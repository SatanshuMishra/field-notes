import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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

    testWidgets('a file that cannot be decoded reports through onDecodeError', (
      WidgetTester tester,
    ) async {
      final File corrupt = File('${root.path}/corrupt.png')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'p1',
          ResolvedMedia.available(
            blob: blobOf(id: 'p1', relPath: 'corrupt.png'),
            file: corrupt,
          ),
        )
        ..memoize('p1');
      int failures = 0;

      await tester.runAsync(
        () => tester.pumpWidget(
          cardHarness(
            MediaImage(
              resolver: resolver,
              mediaId: 'p1',
              errorLabel: 'Photo',
              width: 72,
              height: 72,
              onDecodeError: () => failures++,
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump();

      expect(failures, greaterThanOrEqualTo(1));
      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
    });

    testWidgets('a photo keeps its frame while its box is resized', (
      WidgetTester tester,
    ) async {
      final File wide = File('${root.path}/wide.png')
        ..writeAsBytesSync(widePngBytes());
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'p1',
          ResolvedMedia.available(
            blob: blobOf(id: 'p1', relPath: 'wide.png'),
            file: wide,
          ),
        )
        ..memoize('p1');

      Widget at(double width) => cardHarness(
            MediaImage(
              resolver: resolver,
              mediaId: 'p1',
              errorLabel: 'Photo',
            ),
            width: width,
            data: const MediaQueryData(devicePixelRatio: 1),
          );

      await tester.runAsync(() async {
        await tester.pumpWidget(at(100));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      final int first =
          (tester.widget<Image>(find.byType(Image)).image as ResizeImage)
              .width!;
      expect(
        tester.renderObject<RenderImage>(find.byType(RawImage)).image,
        isNotNull,
        reason: 'the first decode never landed, so this test proves nothing',
      );

      await tester.pumpWidget(at(200));
      await tester.pump();

      expect(
        (tester.widget<Image>(find.byType(Image)).image as ResizeImage).width,
        isNot(first),
        reason: 'the resize did not cross a decode bucket',
      );
      expect(
        tester.renderObject<RenderImage>(find.byType(RawImage)).image,
        isNotNull,
        reason: 'the photo blanks while the new decode is in flight',
      );
    });

    testWidgets('a different photo does not inherit the last one\'s frame', (
      WidgetTester tester,
    ) async {
      final File wide = File('${root.path}/wide.png')
        ..writeAsBytesSync(widePngBytes());
      final File short = File('${root.path}/short.png')
        ..writeAsBytesSync(shortPngBytes());
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'p1',
          ResolvedMedia.available(
            blob: blobOf(id: 'p1', relPath: 'wide.png'),
            file: wide,
          ),
        )
        ..set(
          'p2',
          ResolvedMedia.available(
            blob: blobOf(id: 'p2', relPath: 'short.png'),
            file: short,
          ),
        )
        ..memoize('p1')
        ..memoize('p2');

      Widget of(String id) => cardHarness(
            MediaImage(
              resolver: resolver,
              mediaId: id,
              errorLabel: 'Photo',
            ),
            width: 100,
            data: const MediaQueryData(devicePixelRatio: 1),
          );

      await tester.runAsync(() async {
        await tester.pumpWidget(of('p1'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      final ui.Image? firstFrame =
          tester.renderObject<RenderImage>(find.byType(RawImage)).image;
      expect(firstFrame, isNotNull, reason: 'the first decode never landed');
      final int firstHeight = firstFrame!.height;

      await tester.pumpWidget(of('p2'));
      await tester.pump();

      final ui.Image? afterSwap =
          tester.renderObject<RenderImage>(find.byType(RawImage)).image;
      expect(
        afterSwap?.height,
        isNot(firstHeight),
        reason: 'the new photo is wearing the old photo\'s frame',
      );
    });

    testWidgets('a photo resolved while on screen keeps its frame', (
      WidgetTester tester,
    ) async {
      final File wide = File('${root.path}/wide.png')
        ..writeAsBytesSync(widePngBytes());
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'p1',
          ResolvedMedia.available(
            blob: blobOf(id: 'p1', relPath: 'wide.png'),
            file: wide,
          ),
        );

      Widget at(double width) => cardHarness(
            MediaImage(
              resolver: resolver,
              mediaId: 'p1',
              errorLabel: 'Photo',
            ),
            width: width,
            data: const MediaQueryData(devicePixelRatio: 1),
          );

      await tester.runAsync(() async {
        await tester.pumpWidget(at(100));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(
        tester.renderObject<RenderImage>(find.byType(RawImage)).image,
        isNotNull,
        reason: 'the first decode never landed, so this test proves nothing',
      );
      expect(
        resolver.resolved('p1'),
        isNotNull,
        reason: 'the memo never filled, so this test proves nothing',
      );
      final State<StatefulWidget> drawn = tester.state(find.byType(Image));

      await tester.pumpWidget(at(100));
      await tester.pump();

      expect(
        tester.state(find.byType(Image)),
        same(drawn),
        reason: 'the photo was remounted when the resolver memo filled',
      );
      expect(
        tester.renderObject<RenderImage>(find.byType(RawImage)).image,
        isNotNull,
        reason: 'the photo was remounted when the resolver memo filled',
      );
    });
  });
}
