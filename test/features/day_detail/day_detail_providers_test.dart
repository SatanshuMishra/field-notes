import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/state/state.dart';

import 'support/day_detail_harness.dart';

void main() {
  test('the day-detail resolver resolves through the app media store',
      () async {
    final Directory root =
        await Directory.systemTemp.createTemp('fn_day_detail');
    addTearDown(() => root.deleteSync(recursive: true));
    File(p.join(root.path, 'photo.bin'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[1, 2, 3]);

    final FakeMediaStore store = FakeMediaStore(
      root,
      blobs: <String, MediaBlob>{
        'blob-1': blobOf(id: 'blob-1', relPath: 'photo.bin'),
      },
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        mediaStoreProvider.overrideWith((Ref ref) => store),
      ],
    );
    addTearDown(container.dispose);

    final MediaResolver resolver =
        await container.read(dayDetailMediaResolverProvider.future);

    expect((await resolver.resolve('blob-1')).isAvailable, isTrue);
    expect((await resolver.resolve('blob-missing')).isAvailable, isFalse);
  });
}
