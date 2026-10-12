import 'dart:async';

import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/update_installer.dart';
import 'package:flutter/services.dart';

const String macUpdaterChannelName = 'field_notes/updater';
const String macUpdaterEventChannelName = 'field_notes/updater/events';
const MethodChannel macUpdaterChannel = MethodChannel(macUpdaterChannelName);
const EventChannel macUpdaterEvents = EventChannel(macUpdaterEventChannelName);

final class MacUpdateInstaller implements UpdateInstaller {
  const MacUpdateInstaller({
    this._channel = macUpdaterChannel,
    this._events = macUpdaterEvents,
  });

  final MethodChannel _channel;
  final EventChannel _events;

  @override
  InstallRoute get route => InstallRoute.restartInPlace;

  @override
  Stream<InstallEvent> install(ReleaseInfo release) {
    final _SparkleSession session = _SparkleSession(_channel, _events, release);
    return session.events.stream;
  }
}

final class _SparkleSession {
  _SparkleSession(this._channel, this._sparkle, this._release) {
    events = StreamController<InstallEvent>(
      onListen: _start,
      onCancel: _stopListening,
    );
  }

  final MethodChannel _channel;
  final EventChannel _sparkle;
  final ReleaseInfo _release;
  late final StreamController<InstallEvent> events;
  StreamSubscription<Object?>? _subscription;
  bool _restarting = false;
  bool _finished = false;

  void _start() {
    _subscription = _sparkle.receiveBroadcastStream().listen(
      _onSparkleEvent,
      onError: (Object error) => _fail(InstallFailure.installer),
      onDone: () {
        if (!_restarting) {
          _fail(InstallFailure.installer);
        }
      },
    );
    unawaited(_requestInstall());
  }

  Future<void> _requestInstall() async {
    try {
      await _channel.invokeMethod<void>('install', <String, Object?>{
        'version': _release.version.toString(),
      });
    } on PlatformException {
      _fail(InstallFailure.installer);
    } on MissingPluginException {
      _fail(InstallFailure.installer);
    }
  }

  void _onSparkleEvent(Object? message) {
    if (_finished || message is! Map) {
      return;
    }
    switch (message['event']) {
      case 'progress':
        final Object? received = message['received'];
        final Object? total = message['total'];
        if (received is! int) {
          return;
        }
        events.add(
          InstallDownloading(
            received,
            total is int && total > 0 ? total : null,
          ),
        );
      case 'verifying':
        events.add(const InstallVerifying());
      case 'restarting':
        _restarting = true;
        events.add(const InstallRestarting());
      case 'mismatch' || 'notFound':
        _fail(InstallFailure.notReady);
      case 'error':
        _fail(InstallFailure.installer);
      case 'dismissed':
        if (!_restarting) {
          _fail(InstallFailure.installer);
        }
    }
  }

  void _fail(InstallFailure failure) {
    if (_finished) {
      return;
    }
    _finished = true;
    events.add(InstallFailed(failure));
    unawaited(_stopListening());
    unawaited(events.close());
  }

  Future<void> _stopListening() async {
    final StreamSubscription<Object?>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
