import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/photo_intrinsics.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/photos/photo_drag.dart';
import 'package:field_notes/features/note_engine/photos/photo_import_flow.dart';
import 'package:field_notes/features/note_engine/photos/photo_paste_drop.dart';
import 'package:field_notes/features/note_engine/platform/android_clipboard_image.dart';
import 'package:field_notes/features/note_engine/platform/image_pasteboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String canonicalOf(String reference) => '![](photo/$reference "right medium")';

const List<PhotoDropTarget> _fourTargets = <PhotoDropTarget>[
  PhotoDropTarget(boundary: 0, y: 0),
  PhotoDropTarget(boundary: 1, y: 30),
  PhotoDropTarget(boundary: 4, y: 60),
  PhotoDropTarget(boundary: 7, y: 90),
];

final class _Rig {
  _Rig(
    String source, {
    int caret = 0,
    TargetPlatform platform = TargetPlatform.macOS,
    Map<String, Object?> pasteboard = const <String, Object?>{},
    Map<String, Object?> clipboard = const <String, Object?>{},
    List<PhotoDropTarget> targets = const <PhotoDropTarget>[],
    Object? captureFailure,
  }) : state = EditorState.create(
         source,
         parse: parseNoteTree,
         selection: NoteSelection.collapsed(caret),
       ) {
    _mock(imagePasteboardChannelName, pasteboard, pasteboardCalls);
    _mock(androidClipboardImageChannelName, clipboard, clipboardCalls);
    flow = PhotoImportFlow(
      readState: () => state,
      onOutcome: (PhotoImportOutcome outcome) {
        events.add(outcome);
        if (outcome is PhotoImportInserted) {
          state = state.apply(outcome.result.transaction);
        }
      },
    );
    flow.addListener(() {
      if (flow.placeholders.isNotEmpty) {
        placeholderSeen = true;
      }
    });
    drop = PhotoPasteDrop(
      platform: platform,
      imports: flow,
      importPhoto: (CaptureMedia photo) async {
        imported.add(photo);
        return references[imported.length - 1];
      },
      dropTargets: () => targets,
      onSkipped: (String message) => events.add(message),
      captureFromPath: (String path) async {
        pathCaptures.add(path);
        if (captureFailure != null) {
          throw captureFailure;
        }
        return CaptureBytes(
          bytes: const <int>[1, 2, 3],
          mime: 'image/jpeg',
          width: 3,
          height: 2,
        );
      },
      captureFromBytes: (Uint8List bytes, String mime) async {
        byteCaptures.add((bytes, mime));
        return CaptureBytes(bytes: bytes, mime: mime, width: 3, height: 2);
      },
    );
    drop.addListener(() => hoverNotifications += 1);
  }

  static const List<String> references = <String>[
    'aaa111aaa111',
    'bbb222bbb222',
  ];

  EditorState state;
  late final PhotoImportFlow flow;
  late final PhotoPasteDrop drop;
  final List<MethodCall> pasteboardCalls = <MethodCall>[];
  final List<MethodCall> clipboardCalls = <MethodCall>[];
  final List<Object> events = <Object>[];
  final List<CaptureMedia> imported = <CaptureMedia>[];
  final List<String> pathCaptures = <String>[];
  final List<(Uint8List, String)> byteCaptures = <(Uint8List, String)>[];
  int hoverNotifications = 0;
  bool placeholderSeen = false;

  List<PhotoImportOutcome> get outcomes =>
      List<PhotoImportOutcome>.unmodifiable(
        events.whereType<PhotoImportOutcome>(),
      );

  List<String> get skippedMessages =>
      List<String>.unmodifiable(events.whereType<String>());

  List<String> get pasteboardMethods => <String>[
    for (final MethodCall call in pasteboardCalls) call.method,
  ];

  List<String> get clipboardMethods => <String>[
    for (final MethodCall call in clipboardCalls) call.method,
  ];

  void _mock(
    String channel,
    Map<String, Object?> answers,
    List<MethodCall> calls,
  ) {
    final MethodChannel methodChannel = MethodChannel(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          calls.add(call);
          return answers[call.method];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null),
    );
  }
}

final Uint8List _pngHead = Uint8List.fromList(<int>[137, 80, 78, 71]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image file urls on the pasteboard win over text', () async {
    expect(
      planMacosPaste(
        const PasteboardContents(
          filePaths: <String>['/Users/me/a.png', '/Users/me/notes.txt'],
          imageTypes: <PasteboardImageType>{PasteboardImageType.png},
          hasText: true,
        ),
      ),
      const PastePhotoFiles(paths: <String>['/Users/me/a.png'], skipped: 1),
    );

    final _Rig rig = _Rig(
      'A\n\nB',
      pasteboard: <String, Object?>{
        'contents': <String, Object?>{
          'paths': <String>['/Users/me/a.png', '/Users/me/notes.txt'],
          'imageTypes': <String>['png'],
          'hasText': true,
        },
      },
    );
    final bool handled = await rig.drop.paste();
    await pumpEventQueue();

    expect(handled, isTrue);
    expect(rig.pasteboardMethods, <String>['contents']);
    expect(rig.skippedMessages, <String>[
      '1 file skipped — only photos can be added to a note',
    ]);
    expect(rig.pathCaptures, <String>['/Users/me/a.png']);
    expect(rig.outcomes.single, isA<PhotoImportInserted>());
    expect(rig.state.source, 'A\n${canonicalOf('aaa111aaa111')}\n\nB');
  });

  test('image data is pasted only when no text is present', () async {
    expect(
      planMacosPaste(
        const PasteboardContents(
          imageTypes: <PasteboardImageType>{PasteboardImageType.tiff},
          hasText: true,
        ),
      ),
      const PastePlainText(),
    );
    final _Rig withText = _Rig(
      'A\n\nB',
      pasteboard: <String, Object?>{
        'contents': <String, Object?>{
          'paths': <String>[],
          'imageTypes': <String>['tiff'],
          'hasText': true,
        },
      },
    );
    expect(await withText.drop.paste(), isFalse);
    await pumpEventQueue();
    expect(withText.pasteboardMethods, <String>['contents']);
    expect(withText.outcomes, isEmpty);
    expect(withText.placeholderSeen, isFalse);

    expect(
      planMacosPaste(
        const PasteboardContents(
          imageTypes: <PasteboardImageType>{PasteboardImageType.tiff},
        ),
      ),
      const PastePhotoData(),
    );
    final _Rig withoutText = _Rig(
      'A\n\nB',
      pasteboard: <String, Object?>{
        'contents': <String, Object?>{
          'paths': <String>[],
          'imageTypes': <String>['tiff'],
          'hasText': false,
        },
        'image': <String, Object?>{'bytes': _pngHead, 'mime': 'image/png'},
      },
    );
    expect(await withoutText.drop.paste(), isTrue);
    await pumpEventQueue();
    expect(withoutText.pasteboardMethods, <String>['contents', 'image']);
    expect(withoutText.byteCaptures.single.$1, _pngHead);
    expect(withoutText.byteCaptures.single.$2, 'image/png');
    expect(withoutText.pathCaptures, isEmpty);
    expect(withoutText.state.source, 'A\n${canonicalOf('aaa111aaa111')}\n\nB');

    expect(
      planMacosPaste(
        const PasteboardContents(
          filePaths: <String>['/x/readme.md'],
          hasText: true,
        ),
      ),
      const PastePlainText(),
    );
  });

  test('a drop lands at the insertion line boundary', () async {
    final _Rig rig = _Rig('A\n\nB\n\nC', targets: _fourTargets);

    rig.drop.hover(const Offset(10, 58));
    expect(rig.drop.hoverTarget, const PhotoDropTarget(boundary: 4, y: 60));
    expect(rig.hoverNotifications, 1);

    await rig.drop.drop(const Offset(10, 58), <String>[
      '/p/one.jpg',
      '/p/two.png',
    ]);
    expect(rig.drop.hoverTarget, isNull);
    await pumpEventQueue();

    expect(rig.pathCaptures, <String>['/p/one.jpg', '/p/two.png']);
    final String second = canonicalOf('bbb222bbb222');
    final String expected =
        'A\n\nB\n${canonicalOf('aaa111aaa111')}\n$second\n\nC';
    expect(rig.state.source, expected);
    expect(rig.outcomes.single, isA<PhotoImportInserted>());
    final int secondStart = expected.indexOf(second);
    expect(
      rig.state.selection,
      NoteSelection(anchor: secondStart, head: secondStart + second.length),
    );
  });

  test('skipped files show the counted toast', () async {
    final _Rig one = _Rig('A\n\nB\n\nC', targets: _fourTargets);
    await one.drop.drop(const Offset(10, 58), <String>['/a.pdf']);
    await pumpEventQueue();
    expect(one.skippedMessages, <String>[
      '1 file skipped — only photos can be added to a note',
    ]);
    expect(one.placeholderSeen, isFalse);
    expect(one.outcomes, isEmpty);
    expect(one.state.source, 'A\n\nB\n\nC');

    final _Rig three = _Rig('A\n\nB\n\nC', targets: _fourTargets);
    await three.drop.drop(const Offset(10, 58), <String>[
      '/a.pdf',
      '/b.zip',
      '/c.txt',
    ]);
    await pumpEventQueue();
    expect(three.skippedMessages, <String>[
      '3 files skipped — only photos can be added to a note',
    ]);
    expect(three.placeholderSeen, isFalse);
    expect(three.outcomes, isEmpty);

    final _Rig mixed = _Rig('A\n\nB\n\nC', targets: _fourTargets);
    await mixed.drop.drop(const Offset(10, 58), <String>[
      '/a.jpg',
      '/b.pdf',
      '/c.doc',
    ]);
    await pumpEventQueue();
    expect(
      mixed.events.first,
      '2 files skipped — only photos can be added to a note',
    );
    expect(mixed.events.length, 2);
    expect(mixed.events.last, isA<PhotoImportInserted>());
    expect(mixed.pathCaptures, <String>['/a.jpg']);
    expect(mixed.state.source, 'A\n\nB\n${canonicalOf('aaa111aaa111')}\n\nC');
  });

  test('isPhotoFilePath reads the last segment extension', () {
    expect(isPhotoFilePath('/Users/me/IMG.JPG'), isTrue);
    expect(isPhotoFilePath('/tmp/png'), isFalse);
    expect(isPhotoFilePath('/tmp/a.png.txt'), isFalse);
    expect(isPhotoFilePath('/tmp/dir.png/readme'), isFalse);
    for (final String extension in photoFileMimeTypes.keys) {
      expect(isPhotoFilePath('/p/a.$extension'), isTrue, reason: extension);
      expect(
        isPhotoFilePath('/p/a.${extension.toUpperCase()}'),
        isTrue,
        reason: extension,
      );
    }
    expect(photoFileMimeTypes.keys.toSet(), <String>{
      'png',
      'jpg',
      'jpeg',
      'heic',
      'gif',
      'webp',
      'tiff',
    });
  });

  test('skippedFilesToastMessage counts the files', () {
    expect(
      skippedFilesToastMessage(1),
      '1 file skipped — only photos can be added to a note',
    );
    expect(
      skippedFilesToastMessage(2),
      '2 files skipped — only photos can be added to a note',
    );
    expect(
      skippedFilesToastMessage(12),
      '12 files skipped — only photos can be added to a note',
    );
  });

  test('macOS converts heic and tiff through the pasteboard bridge', () async {
    final Uint8List converted = Uint8List.fromList(<int>[9, 8, 7]);
    final _Rig dropped = _Rig(
      'A\n\nB\n\nC',
      targets: _fourTargets,
      pasteboard: <String, Object?>{
        'imageFile': <String, Object?>{'bytes': converted, 'mime': 'image/png'},
      },
    );
    await dropped.drop.drop(const Offset(10, 58), <String>['/p/IMG_1.HEIC']);
    await pumpEventQueue();
    expect(dropped.pasteboardMethods, <String>['imageFile']);
    expect(dropped.pasteboardCalls.single.arguments, <String, Object?>{
      'path': '/p/IMG_1.HEIC',
    });
    expect(dropped.pathCaptures, isEmpty);
    expect(dropped.byteCaptures.single.$1, converted);
    expect(dropped.byteCaptures.single.$2, 'image/png');
    expect(dropped.state.source, 'A\n\nB\n${canonicalOf('aaa111aaa111')}\n\nC');

    final _Rig pasted = _Rig(
      'A\n\nB',
      pasteboard: <String, Object?>{
        'contents': <String, Object?>{
          'paths': <String>['/p/scan.tiff'],
          'imageTypes': <String>[],
          'hasText': true,
        },
        'imageFile': <String, Object?>{'bytes': converted, 'mime': 'image/png'},
      },
    );
    expect(await pasted.drop.paste(), isTrue);
    await pumpEventQueue();
    expect(pasted.pasteboardMethods, <String>['contents', 'imageFile']);
    expect(pasted.pasteboardCalls.last.arguments, <String, Object?>{
      'path': '/p/scan.tiff',
    });
    expect(pasted.pathCaptures, isEmpty);
    expect(pasted.byteCaptures.single.$1, converted);
    expect(pasted.state.source, 'A\n${canonicalOf('aaa111aaa111')}\n\nB');

    final _Rig unreadable = _Rig('A\n\nB\n\nC', targets: _fourTargets);
    await unreadable.drop.drop(const Offset(10, 58), <String>['/p/scan.tiff']);
    await pumpEventQueue();
    expect(unreadable.pasteboardMethods, <String>['imageFile']);
    expect(unreadable.outcomes, <PhotoImportOutcome>[
      const PhotoImportFailed(undecodablePhotoMessage),
    ]);
    expect(unreadable.imported, isEmpty);
    expect(unreadable.state.source, 'A\n\nB\n\nC');
  });

  test(
    'a null image after the platform reported one fails as undecodable',
    () async {
      final _Rig macos = _Rig(
        'A\n\nB',
        pasteboard: <String, Object?>{
          'contents': <String, Object?>{
            'paths': <String>[],
            'imageTypes': <String>['png'],
            'hasText': false,
          },
        },
      );
      expect(await macos.drop.paste(), isTrue);
      await pumpEventQueue();
      expect(macos.pasteboardMethods, <String>['contents', 'image']);
      expect(macos.outcomes, <PhotoImportOutcome>[
        const PhotoImportFailed(undecodablePhotoMessage),
      ]);
      expect(macos.state.source, 'A\n\nB');

      final _Rig android = _Rig(
        'A\n\nB',
        platform: TargetPlatform.android,
        clipboard: <String, Object?>{'hasImage': true},
      );
      expect(await android.drop.paste(), isTrue);
      await pumpEventQueue();
      expect(android.clipboardMethods, <String>['hasImage', 'image']);
      expect(android.outcomes, <PhotoImportOutcome>[
        const PhotoImportFailed(undecodablePhotoMessage),
      ]);
      expect(android.state.source, 'A\n\nB');
    },
  );

  test(
    'Android pastes a clipboard image and other platforms do nothing',
    () async {
      final _Rig without = _Rig(
        'A\n\nB',
        platform: TargetPlatform.android,
        clipboard: <String, Object?>{'hasImage': false},
      );
      expect(await without.drop.paste(), isFalse);
      await pumpEventQueue();
      expect(without.clipboardMethods, <String>['hasImage']);
      expect(without.pasteboardCalls, isEmpty);
      expect(without.outcomes, isEmpty);

      final _Rig withImage = _Rig(
        'A\n\nB',
        platform: TargetPlatform.android,
        clipboard: <String, Object?>{
          'hasImage': true,
          'image': <String, Object?>{'bytes': _pngHead, 'mime': 'image/png'},
        },
      );
      expect(await withImage.drop.paste(), isTrue);
      await pumpEventQueue();
      expect(withImage.clipboardMethods, <String>['hasImage', 'image']);
      expect(withImage.pasteboardCalls, isEmpty);
      expect(withImage.byteCaptures.single.$1, _pngHead);
      expect(withImage.byteCaptures.single.$2, 'image/png');
      expect(withImage.state.source, 'A\n${canonicalOf('aaa111aaa111')}\n\nB');

      final _Rig linux = _Rig(
        'A\n\nB',
        platform: TargetPlatform.linux,
        pasteboard: <String, Object?>{
          'contents': <String, Object?>{
            'paths': <String>['/p/a.png'],
            'imageTypes': <String>['png'],
            'hasText': false,
          },
        },
        clipboard: <String, Object?>{'hasImage': true},
      );
      expect(await linux.drop.paste(), isFalse);
      await pumpEventQueue();
      expect(linux.pasteboardCalls, isEmpty);
      expect(linux.clipboardCalls, isEmpty);
      expect(linux.outcomes, isEmpty);
    },
  );

  test('keyboard image content is imported after the caret block', () async {
    final Uint8List gif = Uint8List.fromList(<int>[71, 73, 70]);
    final _Rig rig = _Rig('A\n\nB', platform: TargetPlatform.android);
    expect(
      await rig.drop.insertKeyboardContent(
        KeyboardInsertedContent(
          mimeType: 'image/gif',
          uri: 'content://keyboard/1',
          data: gif,
        ),
      ),
      isTrue,
    );
    await pumpEventQueue();
    expect(rig.byteCaptures.single.$1, gif);
    expect(rig.byteCaptures.single.$2, 'image/gif');
    expect(rig.clipboardCalls, isEmpty);
    expect(rig.state.source, 'A\n${canonicalOf('aaa111aaa111')}\n\nB');

    final _Rig text = _Rig('A\n\nB', platform: TargetPlatform.android);
    expect(
      await text.drop.insertKeyboardContent(
        KeyboardInsertedContent(
          mimeType: 'text/plain',
          uri: 'content://keyboard/2',
          data: gif,
        ),
      ),
      isFalse,
    );
    expect(
      await text.drop.insertKeyboardContent(
        const KeyboardInsertedContent(
          mimeType: 'image/png',
          uri: 'content://keyboard/3',
        ),
      ),
      isFalse,
    );
    await pumpEventQueue();
    expect(text.placeholderSeen, isFalse);
    expect(text.byteCaptures, isEmpty);
    expect(text.outcomes, isEmpty);
  });

  test('a failing capture fails the whole job with no transaction', () async {
    final _Rig rig = _Rig(
      'A\n\nB\n\nC',
      targets: _fourTargets,
      captureFailure: const PhotoPickException(undecodablePhotoMessage),
    );
    await rig.drop.drop(const Offset(10, 58), <String>[
      '/p/one.jpg',
      '/p/two.png',
    ]);
    await pumpEventQueue();
    expect(rig.pathCaptures, <String>['/p/one.jpg']);
    expect(rig.imported, isEmpty);
    expect(rig.outcomes, <PhotoImportOutcome>[
      const PhotoImportFailed(undecodablePhotoMessage),
    ]);
    expect(rig.flow.placeholders, isEmpty);
    expect(rig.state.source, 'A\n\nB\n\nC');
  });

  test('hover notifies only when the target changes', () {
    final _Rig rig = _Rig('A\n\nB\n\nC', targets: _fourTargets);
    rig.drop.leave();
    expect(rig.hoverNotifications, 0);

    rig.drop.hover(const Offset(10, 58));
    rig.drop.hover(const Offset(40, 62));
    expect(rig.drop.hoverTarget, const PhotoDropTarget(boundary: 4, y: 60));
    expect(rig.hoverNotifications, 1);

    rig.drop.hover(const Offset(10, 88));
    expect(rig.drop.hoverTarget, const PhotoDropTarget(boundary: 7, y: 90));
    expect(rig.hoverNotifications, 2);

    rig.drop.leave();
    expect(rig.drop.hoverTarget, isNull);
    expect(rig.hoverNotifications, 3);
    rig.drop.leave();
    expect(rig.hoverNotifications, 3);
  });

  testWidgets('photoCaptureFromBytes reads a real PNG', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final CaptureMedia? capture = await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 2, 1),
        ui.Paint()..color = const ui.Color(0xFF336699),
      );
      final ui.Image image = await recorder.endRecording().toImage(2, 1);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      return photoCaptureFromBytes(data!.buffer.asUint8List(), 'image/png');
    });
    expect(capture, isA<CaptureBytes>());
    expect(capture!.width, 2);
    expect(capture.height, 1);
    expect(capture.mime, 'image/png');
  });
}
