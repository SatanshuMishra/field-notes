import 'dart:async';

import 'package:audioplayers_android/audioplayers_android.dart'
    as audioplayers_android;
import 'package:audioplayers_darwin/audioplayers_darwin.dart'
    as audioplayers_darwin;
import 'package:audioplayers_windows/audioplayers_windows.dart'
    as audioplayers_windows;
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:just_audio_windows/just_audio_windows.dart'
    as just_audio_windows;
import 'package:video_player_android/video_player_android.dart'
    as video_player_android;
import 'package:video_player_avfoundation/video_player_avfoundation.dart'
    as video_player_avfoundation;
import 'package:video_player_win/video_player_win.dart' as video_player_win;

const double _fullVolume = 1.0;
const int _outputVolumeScale = 100;

final ValueNotifier<double> playbackVolume = ValueNotifier<double>(_fullVolume);

typedef OutputRouteSetter = Future<void> Function(String? id);

List<OutputRouteSetter> outputRouteSettersFor(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.macOS => const <OutputRouteSetter>[
      just_audio.setPreferredOutputDevice,
      video_player_avfoundation.setPreferredOutputDevice,
      audioplayers_darwin.setPreferredOutputDevice,
    ],
    TargetPlatform.windows => const <OutputRouteSetter>[
      just_audio_windows.setPreferredOutputDevice,
      video_player_win.setPreferredOutputDevice,
      audioplayers_windows.setPreferredOutputDevice,
    ],
    TargetPlatform.android => const <OutputRouteSetter>[
      just_audio.setPreferredOutputDevice,
      video_player_android.setPreferredOutputDevice,
      audioplayers_android.setPreferredOutputDevice,
    ],
    TargetPlatform.iOS ||
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => const <OutputRouteSetter>[],
  };
}

@immutable
class _RouteRequest {
  const _RouteRequest(this.storedId, this.outputs);

  final String? storedId;
  final List<AudioOutputDevice> outputs;

  @override
  bool operator ==(Object other) =>
      other is _RouteRequest &&
      other.storedId == storedId &&
      listEquals(other.outputs, outputs);

  @override
  int get hashCode => Object.hash(storedId, Object.hashAll(outputs));
}

class OutputRouteSync {
  OutputRouteSync({ValueNotifier<double>? volume})
    : _volume = volume ?? playbackVolume;

  final ValueNotifier<double> _volume;
  AppSettings? _settings;
  List<AudioOutputDevice>? _outputs;
  _RouteRequest? _routed;

  void settingsChanged(AppSettings settings) {
    _settings = settings;
    _volume.value = settings.outputVolume / _outputVolumeScale;
    _route();
  }

  void outputsChanged(List<AudioOutputDevice> outputs) {
    _outputs = outputs;
    _route();
  }

  void _route() {
    final AppSettings? settings = _settings;
    final List<AudioOutputDevice>? outputs = _outputs;
    if (settings == null || outputs == null) {
      return;
    }
    final _RouteRequest request = _RouteRequest(
      settings.audioOutputId,
      outputs,
    );
    if (request == _routed) {
      return;
    }
    _routed = request;
    final String? id = resolveAudioOutput(outputs, settings.audioOutputId).id;
    for (final OutputRouteSetter setter in outputRouteSettersFor(
      defaultTargetPlatform,
    )) {
      unawaited(_send(setter, id));
    }
  }

  Future<void> _send(OutputRouteSetter setter, String? id) async {
    try {
      await setter(id);
    } on Object catch (error) {
      debugPrint('Choosing the playback output failed: $error');
    }
  }
}

ProviderSubscription<T> _follow<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
  void Function(T value) onValue,
) {
  final ProviderSubscription<T> subscription = container.listen<T>(
    provider,
    (T? _, T value) => onValue(value),
  );
  onValue(subscription.read());
  return subscription;
}

final Provider<OutputRouteSync> outputRouteSyncProvider =
    Provider<OutputRouteSync>((Ref ref) {
      final OutputRouteSync sync = OutputRouteSync();
      final ProviderSubscription<AsyncValue<AppSettings>> settings = _follow(
        ref.container,
        appSettingsProvider,
        (AsyncValue<AppSettings> settings) {
          final AppSettings? value = settings.value;
          if (value != null) {
            sync.settingsChanged(value);
          }
        },
      );
      final ProviderSubscription<AsyncValue<List<AudioOutputDevice>>> outputs =
          _follow(ref.container, audioOutputsProvider, (
            AsyncValue<List<AudioOutputDevice>> outputs,
          ) {
            final List<AudioOutputDevice>? value = outputs.value;
            if (value != null) {
              sync.outputsChanged(value);
            } else if (outputs.hasError) {
              sync.outputsChanged(const <AudioOutputDevice>[]);
            }
          });
      ref.onDispose(() {
        settings.close();
        outputs.close();
      });
      return sync;
    });
