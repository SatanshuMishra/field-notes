import 'dart:async';

import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

abstract interface class LiveMedia {
  Stream<String> get arrivals;

  Stream<MediaDownloadProgress>? downloadProgress(String mediaId);
}

bool arrivalMatches(String arrivedId, String mediaId) =>
    mediaId.isNotEmpty && arrivedId.startsWith(mediaId);

final class MediaArrivalWatch {
  StreamSubscription<String>? _subscription;

  bool get isWatching => _subscription != null;

  void watch(
    MediaResolver resolver,
    String? mediaId,
    void Function() onArrived,
  ) {
    cancel();
    if (resolver is! LiveMedia || mediaId == null || mediaId.isEmpty) {
      return;
    }
    _subscription = (resolver as LiveMedia).arrivals.listen((String arrived) {
      if (arrivalMatches(arrived, mediaId)) {
        onArrived();
      }
    });
  }

  void cancel() {
    final StreamSubscription<String>? subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
  }
}
