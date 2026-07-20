import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/state/state.dart';

final FutureProvider<MediaResolver> dayDetailMediaResolverProvider =
    FutureProvider<MediaResolver>((Ref ref) async {
  return MediaStoreResolver(await ref.watch(mediaStoreProvider.future));
});
