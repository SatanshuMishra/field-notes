import 'package:background_downloader/background_downloader.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingDownloader extends Fake implements FileDownloader {
  final Map<String, TaskNotificationConfig> _registered =
      <String, TaskNotificationConfig>{};
  final List<(String, TaskNotificationConfig?)> enqueued =
      <(String, TaskNotificationConfig?)>[];

  @override
  FileDownloader configureNotificationForTask(
    Task task, {
    TaskNotification? running,
    TaskNotification? complete,
    TaskNotification? error,
    TaskNotification? paused,
    TaskNotification? canceled,
    bool progressBar = false,
    bool tapOpensFile = false,
    String groupNotificationId = '',
  }) {
    _registered[task.taskId] = TaskNotificationConfig(
      taskOrGroup: task,
      running: running,
      complete: complete,
      error: error,
      paused: paused,
      canceled: canceled,
      progressBar: progressBar,
      tapOpensFile: tapOpensFile,
      groupNotificationId: groupNotificationId,
    );
    return this;
  }

  @override
  Future<bool> enqueue(Task task) async {
    enqueued.add((task.taskId, _registered[task.taskId]));
    return true;
  }
}

UploadTask _part({TaskNotificationConfig? notification}) => UploadTask(
  taskId: 'part.upload.0',
  url: 'https://relay.test/v1/blobs/name/uploads/upload/parts/0',
  filename: 'part-0',
  group: mediaPartGroup,
  priority: userInitiatedPriority,
  notificationConfig: notification,
);

void main() {
  test(
    'a media part reaches the system uploader with its notification registered',
    () async {
      final _RecordingDownloader downloader = _RecordingDownloader();

      final bool enqueued = await PackageBackgroundUploader(downloader).enqueue(
        _part(
          notification: TaskNotificationConfig(
            running: TaskNotification(
              mediaNotificationTitle,
              mediaNotificationBodyWaitingForWiFi,
            ),
            progressBar: true,
            groupNotificationId: mediaNotificationGroup,
          ),
        ),
      );

      expect(enqueued, isTrue);
      final TaskNotificationConfig? registered = downloader.enqueued.single.$2;
      expect(registered, isNotNull);
      expect(registered!.running?.title, mediaNotificationTitle);
      expect(registered.running?.body, mediaNotificationBodyWaitingForWiFi);
      expect(registered.progressBar, isTrue);
      expect(registered.groupNotificationId, mediaNotificationGroup);
    },
  );

  test('a task without a notification is enqueued without one', () async {
    final _RecordingDownloader downloader = _RecordingDownloader();

    await PackageBackgroundUploader(downloader).enqueue(_part());

    expect(downloader.enqueued.single.$2, isNull);
  });
}
