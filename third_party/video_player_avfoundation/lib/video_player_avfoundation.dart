// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';

export 'src/avfoundation_video_player.dart';

const MethodChannel _outputRouteChannel = MethodChannel(
  'field_notes/output_route/video_player_avfoundation',
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
