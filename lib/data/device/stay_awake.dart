import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String stayAwakeChannelName = 'field_notes/stay_awake';
const String stayAwakeHoldMethod = 'hold';
const String stayAwakeReleaseMethod = 'release';

abstract interface class StayAwake {
  Future<void> hold();

  Future<void> release();
}

class PlatformStayAwake implements StayAwake {
  const PlatformStayAwake([
    this._channel = const MethodChannel(stayAwakeChannelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<void> hold() => _ask(stayAwakeHoldMethod);

  @override
  Future<void> release() => _ask(stayAwakeReleaseMethod);

  Future<void> _ask(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException catch (error) {
      debugPrint('Stay awake "$method" has no platform handler: $error');
    } on PlatformException catch (error) {
      debugPrint('Stay awake "$method" failed on the platform: $error');
    }
  }
}
