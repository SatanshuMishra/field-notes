import 'dart:convert';

import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

HandedTask _part(int index, {bool requiresWiFi = true}) => HandedTask(
  taskId: 'part.upload.$index',
  group: mediaPartGroup,
  url: 'https://relay.test/v1/blobs/name/uploads/upload/parts/$index',
  method: 'PUT',
  headers: const <String, String>{'Authorization': 'UploadPass token'},
  filePath: '/data/sync_uploads/blob/$index',
  mimeType: 'application/octet-stream',
  requiresWiFi: requiresWiFi,
  metaData: jsonEncode(<String, Object?>{'blobId': 'blob', 'index': index}),
);

String _result(HandedTask task, String status, {int? code, String? body}) =>
    jsonEncode(<String, Object?>{
      'task': task.toJson(),
      'status': status,
      'statusCode': code,
      'body': body,
    });

final class _Native {
  _Native() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
  }

  static const MethodChannel channel = MethodChannel(backgroundUploadsChannel);

  final List<MethodCall> calls = <MethodCall>[];
  final List<String> stored = <String>[];
  final List<String> results = <String>[];

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'enqueue':
        final Map<Object?, Object?> arguments =
            call.arguments as Map<Object?, Object?>;
        stored.addAll((arguments['tasks']! as List<Object?>).cast<String>());
        return true;
      case 'queued':
        return List<String>.of(stored);
      case 'takeResults':
        final List<String> taken = List<String>.of(results);
        results.clear();
        return taken;
      default:
        return null;
    }
  }

  Future<void> announceResults() async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          backgroundUploadsChannel,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('resultsReady'),
          ),
          (ByteData? _) {},
        );
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Native native;

  setUp(() => native = _Native());
  tearDown(() => native.dispose());

  test('starting gives the native uploader its notification copy and collects results left from before', () async {
    native.results.add(
      _result(_part(0), 'complete', code: 200, body: '{"assembled":false}'),
    );
    final List<HandedResult> collected = <HandedResult>[];

    await ChannelBackgroundUploader().start(collected.add);

    final MethodCall configure = native.calls.firstWhere(
      (MethodCall call) => call.method == 'configure',
    );
    expect(configure.arguments, <String, String>{
      'title': mediaNotificationTitle,
      'body': mediaNotificationBody,
      'bodyWaitingForWiFi': mediaNotificationBodyWaitingForWiFi,
      'channelName': mediaNotificationChannelName,
    });
    final HandedResult result = collected.single;
    expect(result.status, HandedStatus.complete);
    expect(result.statusCode, 200);
    expect(result.body, '{"assembled":false}');
    expect(result.task.taskId, 'part.upload.0');
    expect(result.task.metaData, _part(0).metaData);
  });

  test(
    'results announced later by the native uploader are delivered',
    () async {
      final List<HandedResult> collected = <HandedResult>[];
      await ChannelBackgroundUploader().start(collected.add);
      expect(collected, isEmpty);

      native.results.add(
        _result(_part(1), 'failed', code: 401, body: 'denied'),
      );
      await native.announceResults();

      expect(collected.single.status, HandedStatus.failed);
      expect(collected.single.statusCode, 401);
      expect(collected.single.task.taskId, 'part.upload.1');
    },
  );

  test(
    'every task goes over in one call, in the shape the native side stores',
    () async {
      final ChannelBackgroundUploader uploader = ChannelBackgroundUploader();

      await uploader.enqueue(<HandedTask>[
        _part(0),
        _part(1, requiresWiFi: false),
      ]);

      expect(
        native.calls.where((MethodCall call) => call.method == 'enqueue'),
        hasLength(1),
      );
      final Map<String, Object?> first =
          jsonDecode(native.stored.first) as Map<String, Object?>;
      expect(first, <String, Object?>{
        'taskId': 'part.upload.0',
        'group': mediaPartGroup,
        'url': 'https://relay.test/v1/blobs/name/uploads/upload/parts/0',
        'method': 'PUT',
        'headers': <String, Object?>{'Authorization': 'UploadPass token'},
        'file': '/data/sync_uploads/blob/0',
        'mimeType': 'application/octet-stream',
        'requiresWiFi': true,
        'metaData': _part(0).metaData,
      });
      final List<HandedTask> queued = await uploader.queuedTasks();
      expect(queued.map((HandedTask task) => task.taskId), <String>[
        'part.upload.0',
        'part.upload.1',
      ]);
      expect(queued.last.requiresWiFi, isFalse);
    },
  );

  test(
    'an unreadable stored task is skipped and nothing is sent for empty lists',
    () async {
      final ChannelBackgroundUploader uploader = ChannelBackgroundUploader();
      native.stored.addAll(<String>['not json', jsonEncode(_part(2).toJson())]);

      final List<HandedTask> queued = await uploader.queuedTasks();
      await uploader.enqueue(const <HandedTask>[]);
      await uploader.cancel(const <String>[]);

      expect(queued.single.taskId, 'part.upload.2');
      expect(native.calls.map((MethodCall call) => call.method), <String>[
        'queued',
      ]);
    },
  );

  test('cancelling names the tasks to drop', () async {
    await ChannelBackgroundUploader().cancel(<String>['part.upload.0']);

    final MethodCall cancel = native.calls.single;
    expect(cancel.method, 'cancel');
    expect(cancel.arguments, <String, Object?>{
      'taskIds': <String>['part.upload.0'],
    });
  });
}
