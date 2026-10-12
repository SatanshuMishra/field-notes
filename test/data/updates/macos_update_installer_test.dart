import 'dart:async';

import 'package:field_notes/data/updates/macos_update_installer.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ReleaseInfo _release() => ReleaseInfo(
  version: AppVersion.tryParse('1.2.0')!,
  tag: 'v1.2.0',
  publishedAt: DateTime.utc(2026, 10, 11, 9),
  notes: ReleaseNotes.empty,
  pageUrl: Uri.parse(
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v1.2.0',
  ),
  assets: const <ReleaseAsset>[],
);

final class _Sparkle {
  final List<MethodCall> calls = <MethodCall>[];
  int listens = 0;
  int cancels = 0;
  MockStreamHandlerEventSink? _sink;

  void emit(Map<String, Object?> event) => _sink!.success(event);

  void fail() => _sink!.error(code: 'broken', message: 'The updater broke.');
}

final class _Run {
  _Run(this.events, this.done);

  final List<InstallEvent> events;
  final bool done;
}

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

_Sparkle _mockSparkle({
  required void Function(_Sparkle sparkle, MethodCall call)? onInstall,
}) {
  final _Sparkle sparkle = _Sparkle();
  _messenger.setMockStreamHandler(
    macUpdaterEvents,
    MockStreamHandler.inline(
      onListen: (Object? arguments, MockStreamHandlerEventSink events) {
        sparkle.listens++;
        sparkle._sink = events;
      },
      onCancel: (Object? arguments) => sparkle.cancels++,
    ),
  );
  if (onInstall == null) {
    _messenger.setMockMethodCallHandler(macUpdaterChannel, null);
  } else {
    _messenger.setMockMethodCallHandler(macUpdaterChannel, (
      MethodCall call,
    ) async {
      sparkle.calls.add(call);
      onInstall(sparkle, call);
      return null;
    });
  }
  return sparkle;
}

Future<_Run> _install() async {
  final List<InstallEvent> events = <InstallEvent>[];
  bool done = false;
  final StreamSubscription<InstallEvent> subscription =
      const MacUpdateInstaller()
          .install(_release())
          .listen(events.add, onDone: () => done = true);
  addTearDown(subscription.cancel);
  await pumpEventQueue();
  return _Run(events, done);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    _messenger.setMockStreamHandler(macUpdaterEvents, null);
    _messenger.setMockMethodCallHandler(macUpdaterChannel, null);
  });

  test(
    'the Mac installer follows Sparkle and refuses a different version',
    () async {
      expect(const MacUpdateInstaller().route, InstallRoute.restartInPlace);
      expect(macUpdaterChannel.name, 'field_notes/updater');
      expect(macUpdaterEvents.name, 'field_notes/updater/events');

      final _Sparkle updating = _mockSparkle(
        onInstall: (_Sparkle sparkle, MethodCall call) {
          sparkle
            ..emit(<String, Object?>{'event': 'found'})
            ..emit(<String, Object?>{
              'event': 'progress',
              'received': 0,
              'total': 1000,
            })
            ..emit(<String, Object?>{
              'event': 'progress',
              'received': 400,
              'total': 1000,
            })
            ..emit(<String, Object?>{
              'event': 'progress',
              'received': 1000,
              'total': 1000,
            })
            ..emit(<String, Object?>{'event': 'verifying'})
            ..emit(<String, Object?>{'event': 'restarting'})
            ..emit(<String, Object?>{'event': 'installing'})
            ..emit(<String, Object?>{'event': 'dismissed'});
        },
      );
      final _Run updated = await _install();
      expect(updating.calls, hasLength(1));
      expect(updating.calls.single.method, 'install');
      expect(updating.calls.single.arguments, <String, Object?>{
        'version': '1.2.0',
      });
      expect(updating.listens, 1);
      expect(updated.events, const <InstallEvent>[
        InstallDownloading(0, 1000),
        InstallDownloading(400, 1000),
        InstallDownloading(1000, 1000),
        InstallVerifying(),
        InstallRestarting(),
      ]);
      expect(updated.done, isFalse);

      _mockSparkle(
        onInstall: (_Sparkle sparkle, MethodCall call) {
          sparkle
            ..emit(<String, Object?>{'event': 'found'})
            ..emit(<String, Object?>{
              'event': 'progress',
              'received': 0,
              'total': 0,
            })
            ..emit(<String, Object?>{
              'event': 'progress',
              'received': 2048,
              'total': 0,
            });
        },
      );
      expect((await _install()).events, const <InstallEvent>[
        InstallDownloading(0, null),
        InstallDownloading(2048, null),
      ]);

      final _Sparkle mismatched = _mockSparkle(
        onInstall: (_Sparkle sparkle, MethodCall call) {
          sparkle
            ..emit(<String, Object?>{'event': 'mismatch', 'version': '1.3.0'})
            ..emit(<String, Object?>{'event': 'dismissed'})
            ..emit(<String, Object?>{
              'event': 'progress',
              'received': 10,
              'total': 100,
            });
        },
      );
      final _Run mismatch = await _install();
      expect(mismatch.events, const <InstallEvent>[
        InstallFailed(InstallFailure.notReady),
      ]);
      expect(mismatch.done, isTrue);
      expect(mismatched.cancels, 1);

      _mockSparkle(
        onInstall: (_Sparkle sparkle, MethodCall call) {
          sparkle.emit(<String, Object?>{'event': 'notFound'});
        },
      );
      final _Run notFound = await _install();
      expect(notFound.events, const <InstallEvent>[
        InstallFailed(InstallFailure.notReady),
      ]);
      expect(notFound.done, isTrue);

      _mockSparkle(
        onInstall: (_Sparkle sparkle, MethodCall call) {
          sparkle
            ..emit(<String, Object?>{'event': 'found'})
            ..emit(<String, Object?>{
              'event': 'error',
              'message': 'The update is improperly signed.',
            });
        },
      );
      final _Run errored = await _install();
      expect(errored.events, const <InstallEvent>[
        InstallFailed(InstallFailure.installer),
      ]);
      expect(errored.done, isTrue);

      _mockSparkle(
        onInstall: (_Sparkle sparkle, MethodCall call) {
          sparkle
            ..emit(<String, Object?>{'event': 'found'})
            ..emit(<String, Object?>{
              'event': 'progress',
              'received': 0,
              'total': 500,
            })
            ..emit(<String, Object?>{'event': 'dismissed'});
        },
      );
      final _Run dismissed = await _install();
      expect(dismissed.events, const <InstallEvent>[
        InstallDownloading(0, 500),
        InstallFailed(InstallFailure.installer),
      ]);
      expect(dismissed.done, isTrue);

      _mockSparkle(
        onInstall: (_Sparkle sparkle, MethodCall call) => sparkle.fail(),
      );
      final _Run broken = await _install();
      expect(broken.events, const <InstallEvent>[
        InstallFailed(InstallFailure.installer),
      ]);
      expect(broken.done, isTrue);

      final _Sparkle refused = _mockSparkle(onInstall: null);
      _messenger.setMockMethodCallHandler(macUpdaterChannel, (
        MethodCall call,
      ) async {
        refused.calls.add(call);
        throw PlatformException(
          code: 'unavailable',
          message: 'This build carries no update key.',
        );
      });
      final _Run unavailable = await _install();
      expect(refused.calls.single.arguments, <String, Object?>{
        'version': '1.2.0',
      });
      expect(unavailable.events, const <InstallEvent>[
        InstallFailed(InstallFailure.installer),
      ]);
      expect(unavailable.done, isTrue);
      expect(refused.cancels, 1);

      _mockSparkle(onInstall: null);
      final _Run missing = await _install();
      expect(missing.events, const <InstallEvent>[
        InstallFailed(InstallFailure.installer),
      ]);
      expect(missing.done, isTrue);
    },
  );
}
