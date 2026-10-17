import 'package:flutter/services.dart';

const MethodChannel _outputRouteChannel = MethodChannel(
  'field_notes/output_route/audioplayers_darwin',
);

Future<void> setPreferredOutputDevice(String? id) async {
  try {
    await _outputRouteChannel.invokeMethod<void>(
      'setPreferredOutputDevice',
      <String, Object?>{'id': id},
    );
  } on MissingPluginException {
    return;
  }
}
