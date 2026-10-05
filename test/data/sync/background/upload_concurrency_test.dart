import 'package:background_downloader/background_downloader.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingDownloader implements FileDownloader {
  final List<Object?> androidConfigs = <Object?>[];
  final List<String> groups = <String>[];
  int starts = 0;

  @override
  FileDownloader registerCallbacks({
    String group = FileDownloader.defaultGroup,
    TaskStatusCallback? taskStatusCallback,
    TaskProgressCallback? taskProgressCallback,
    TaskNotificationTapCallback? taskNotificationTapCallback,
  }) {
    groups.add(group);
    return this;
  }

  @override
  Future<List<(String, String)>> configure({
    dynamic globalConfig,
    dynamic androidConfig,
    dynamic iOSConfig,
    dynamic desktopConfig,
  }) async {
    androidConfigs.add(androidConfig);
    return const <(String, String)>[];
  }

  @override
  Future<void> start({
    bool doTrackTasks = true,
    bool markDownloadedComplete = true,
    bool doRescheduleKilledTasks = true,
    bool autoCleanDatabase = false,
  }) async {
    starts += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'the system uploader sends at most two parts at once per relay',
    () async {
      final _RecordingDownloader downloader = _RecordingDownloader();

      await PackageBackgroundUploader(downloader)
          .start((TaskStatusUpdate _) {});

      final Object? android = downloader.androidConfigs.single;
      expect(android, isA<List<(String, Object)>>());
      final List<(String, Object)> config = android! as List<(String, Object)>;
      expect(config, contains((Config.holdingQueue, (null, 2, null))));
      expect(config, contains((Config.runInForeground, Config.always)));
      expect(downloader.groups, <String>[mediaPartGroup, recordPushGroup]);
      expect(downloader.starts, 1);
    },
  );
}
