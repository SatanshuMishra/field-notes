import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver_provider.dart';

final FutureProvider<MediaResolver> dayDetailMediaResolverProvider =
    FutureProvider<MediaResolver>(
      (Ref ref) => ref.watch(mediaResolverProvider.future),
    );
