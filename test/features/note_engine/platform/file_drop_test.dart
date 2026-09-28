import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/platform/file_drop.dart';

Future<ByteData?> _deliver(String method, [Object? arguments]) {
  final Completer<ByteData?> reply = Completer<ByteData?>();
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        fileDropChannelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        reply.complete,
      )
      .then((_) => reply.future);
}

List<FileDropEvent> _collect(FileDropChannel channel) {
  final List<FileDropEvent> events = <FileDropEvent>[];
  final StreamSubscription<FileDropEvent> subscription = channel.events.listen(
    events.add,
  );
  addTearDown(subscription.cancel);
  return events;
}

String _block(String project, String header) {
  final int start = project.indexOf(header);
  expect(start, isNot(-1), reason: '$header must exist');
  final int end = project.indexOf('\t\t};', start);
  return project.substring(start, end);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileDropChannel', () {
    test(
      'the drop bridge reports hover positions and dropped file urls',
      () async {
        final List<FileDropEvent> events = _collect(FileDropChannel());

        await _deliver('hover', <String, Object?>{'x': 120.0, 'y': 48.5});
        await _deliver('drop', <String, Object?>{
          'x': 120,
          'y': 60.0,
          'paths': <String>['/Users/me/a.png', '/Users/me/b.pdf'],
        });
        await _deliver('leave');
        await pumpEventQueue();

        expect(events, <FileDropEvent>[
          const FileDropHover(Offset(120, 48.5)),
          const FileDropped(
            position: Offset(120, 60),
            paths: <String>['/Users/me/a.png', '/Users/me/b.pdf'],
          ),
          const FileDropLeave(),
        ]);
      },
    );

    test('the handler lives only while someone listens', () async {
      final FileDropChannel channel = FileDropChannel();

      expect(await _deliver('leave'), isNull);

      final StreamSubscription<FileDropEvent> first = channel.events.listen(
        (FileDropEvent event) {},
      );
      final StreamSubscription<FileDropEvent> second = channel.events.listen(
        (FileDropEvent event) {},
      );
      expect(await _deliver('leave'), isNotNull);

      await first.cancel();
      expect(await _deliver('leave'), isNotNull);

      await second.cancel();
      expect(await _deliver('leave'), isNull);
    });

    test(
      'malformed and unknown calls emit nothing and throw nothing',
      () async {
        final List<FileDropEvent> events = _collect(FileDropChannel());

        await _deliver('drop', <String, Object?>{'x': 1.0, 'y': 2.0});
        await _deliver('drop', <String, Object?>{
          'x': 1.0,
          'y': 2.0,
          'paths': <Object?>['/a.png', 3],
        });
        await _deliver('hover', <String, Object?>{'y': 2.0});
        await _deliver('hover', 'not a map');
        await _deliver('spin', <String, Object?>{'x': 1.0, 'y': 2.0});
        await pumpEventQueue();

        expect(events, isEmpty);
      },
    );

    test('two listeners receive the same events in order', () async {
      final FileDropChannel channel = FileDropChannel();
      final List<FileDropEvent> first = _collect(channel);
      final List<FileDropEvent> second = _collect(channel);

      await _deliver('hover', <String, Object?>{'x': 3, 'y': 4});
      await _deliver('leave');
      await pumpEventQueue();

      const List<FileDropEvent> expected = <FileDropEvent>[
        FileDropHover(Offset(3, 4)),
        FileDropLeave(),
      ];
      expect(first, expected);
      expect(second, expected);
    });

    test('the shared instance is one object', () {
      expect(
        identical(FileDropChannel.instance, FileDropChannel.instance),
        isTrue,
      );
    });

    test('events compare by value', () {
      expect(
        const FileDropped(position: Offset(1, 2), paths: <String>['/a']),
        FileDropped(position: const Offset(1, 2), paths: <String>['/a']),
      );
      expect(
        const FileDropped(position: Offset(1, 2), paths: <String>['/a']),
        isNot(const FileDropped(position: Offset(1, 2), paths: <String>['/b'])),
      );
      expect(
        const FileDropHover(Offset(1, 2)),
        const FileDropHover(Offset(1, 2)),
      );
      expect(const FileDropLeave(), const FileDropLeave());
    });
  });

  group('macOS file drop bridge sources', () {
    final String bridge = File(
      'macos/Runner/FileDropBridge.swift',
    ).readAsStringSync();
    final String window = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    final String project = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    test('the bridge sends hover, leave and drop from a pass-through view', () {
      for (final String fragment in <String>[
        '"$fileDropChannelName"',
        '"hover"',
        '"leave"',
        '"drop"',
        'registerForDraggedTypes([.fileURL])',
        'wantsPeriodicDraggingUpdates',
        'bounds.height -',
      ]) {
        expect(bridge, contains(fragment));
      }
      expect(
        bridge,
        matches(
          RegExp(
            r'override func hitTest\(_ point: NSPoint\) -> NSView\? \{\s*return nil\s*\}',
          ),
        ),
      );
    });

    test('the window registers every bridge', () {
      expect(window, contains('FileDropBridge(messenger:'));
      expect(window, contains('ImagePasteboardBridge(messenger:'));
      expect(window, contains('SpellCheckBridge(messenger:'));
    });

    test('the runner target compiles the bridge', () {
      expect(
        project,
        contains(
          'F1E1D0012EA0000100000005 /* FileDropBridge.swift */ = '
          '{isa = PBXFileReference;',
        ),
      );
      expect(
        _block(project, '\t\t33FAB671232836740065AC1E /* Runner */ = {'),
        contains('F1E1D0012EA0000100000005 /* FileDropBridge.swift */'),
      );
      expect(
        _block(project, '\t\t33CC10E92044A3C60003C045 /* Sources */ = {'),
        contains(
          'F1E1D0012EA0000100000006 /* FileDropBridge.swift in Sources */',
        ),
      );
      expect(
        _block(project, '\t\t331C80D1294CF70F00263BE5 /* Sources */ = {'),
        isNot(contains('FileDropBridge.swift')),
      );
    });
  });
}
