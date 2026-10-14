import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/data/media/audio_peaks_decoder.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/entry_cards/media/live_media.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:field_notes/state/repository_providers.dart';

import 'voice_level.dart';

class VoicePeaksBackfill extends ConsumerStatefulWidget {
  const VoicePeaksBackfill({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VoicePeaksBackfill> createState() => _VoicePeaksBackfillState();
}

class _VoicePeaksBackfillState extends ConsumerState<VoicePeaksBackfill> {
  late final JournalRepository _journal;
  StreamSubscription<List<Entry>>? _listing;
  StreamSubscription<String>? _arrivals;
  Future<MediaStoreResolver>? _resolver;
  List<Entry> _listed = const <Entry>[];
  final Set<String> _tried = <String>{};
  final Map<String, String> _awaitingMedia = <String, String>{};
  String? _lookingUp;
  bool _arrivedDuringLookup = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _journal = ref.read(journalRepositoryProvider);
    _listing = _journal.watchVoiceEntriesWithoutPeaks().listen(
      _onListed,
      onError: _onListingError,
    );
  }

  @override
  void dispose() {
    unawaited(_listing?.cancel());
    unawaited(_arrivals?.cancel());
    super.dispose();
  }

  void _onListed(List<Entry> entries) {
    _listed = entries;
    _awaitingMedia.removeWhere(
      (String entryId, String _) => !_stillWaiting(entryId),
    );
    unawaited(_work());
  }

  void _onListingError(Object error, StackTrace stackTrace) {
    debugPrint('Voice peaks backfill could not list entries: $error');
  }

  void _onArrived(String arrived) {
    final String? lookingUp = _lookingUp;
    if (lookingUp != null && arrivalMatches(arrived, lookingUp)) {
      _arrivedDuringLookup = true;
    }
    final int awaiting = _awaitingMedia.length;
    _awaitingMedia.removeWhere(
      (String _, String mediaId) => arrivalMatches(arrived, mediaId),
    );
    if (_awaitingMedia.length != awaiting) {
      unawaited(_work());
    }
  }

  bool _needsPeaks(Entry entry) {
    final String? mediaId = entry.mediaId;
    return entry.type == EntryType.voice &&
        !entry.isDeleted &&
        entry.peaks == null &&
        mediaId != null &&
        mediaId.isNotEmpty;
  }

  bool _stillWaiting(String entryId) =>
      _listed.any((Entry entry) => entry.id == entryId && _needsPeaks(entry));

  Entry? _next() {
    for (final Entry entry in _listed) {
      if (_needsPeaks(entry) &&
          !_tried.contains(entry.id) &&
          !_awaitingMedia.containsKey(entry.id)) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _work() async {
    if (_working) {
      return;
    }
    _working = true;
    try {
      for (Entry? entry = _next(); entry != null && mounted; entry = _next()) {
        await _backfill(entry);
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _backfill(Entry entry) async {
    final String mediaId = entry.mediaId!;
    try {
      final MediaStoreResolver resolver = await (_resolver ??= _openStore());
      if (!mounted) {
        return;
      }
      _lookingUp = mediaId;
      _arrivedDuringLookup = false;
      final ResolvedMedia media;
      try {
        media = await resolver.resolve(mediaId);
      } finally {
        _lookingUp = null;
      }
      if (!mounted || !_stillWaiting(entry.id)) {
        return;
      }
      final File? file = media.file;
      if (!media.isAvailable || file == null) {
        if (!_arrivedDuringLookup) {
          _awaitingMedia[entry.id] = mediaId;
        }
        return;
      }
      _tried.add(entry.id);
      final List<double> rms = await ref
          .read(audioPeaksDecoderProvider)
          .windowRms(file.path);
      if (!mounted || !_stillWaiting(entry.id)) {
        return;
      }
      await _journal.setVoicePeaks(entry.id, _peaksFromRms(rms));
    } catch (error) {
      _tried.add(entry.id);
      debugPrint('Voice peaks backfill skipped entry ${entry.id}: $error');
    }
  }

  Future<MediaStoreResolver> _openStore() async {
    final MediaStore store = await ref.read(mediaStoreProvider.future);
    if (mounted && store is FilesystemMediaStore) {
      _arrivals = store.arrivals.listen(_onArrived);
    }
    return MediaStoreResolver(store);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

List<double> _peaksFromRms(List<double> rms) {
  final VoicePeaksAccumulator peaks = VoicePeaksAccumulator();
  for (final double value in rms) {
    peaks.add(roundVoicePeak(voiceLevelFromDbfs(20 * log(value) / ln10)));
  }
  return peaks.finish();
}
