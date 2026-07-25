// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_slots_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(videoSlots)
final videoSlotsProvider = VideoSlotsProvider._();

final class VideoSlotsProvider
    extends $FunctionalProvider<VideoSlots, VideoSlots, VideoSlots>
    with $Provider<VideoSlots> {
  VideoSlotsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoSlotsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoSlotsHash();

  @$internal
  @override
  $ProviderElement<VideoSlots> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VideoSlots create(Ref ref) {
    return videoSlots(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoSlots value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoSlots>(value),
    );
  }
}

String _$videoSlotsHash() => r'eb3b7ac5427f589beb35c7c867b11ebaf9ce9904';
