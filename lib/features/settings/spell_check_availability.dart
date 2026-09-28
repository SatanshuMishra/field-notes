import 'dart:async';
import 'dart:ui';

import 'package:field_notes/features/note_engine/platform/spell_check_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'spell_check_availability.g.dart';

enum SpellCheckAvailability { available, unavailable }

const String spellCheckProbeWord = 'teh';
const Duration spellCheckProbeTimeout = Duration(seconds: 2);

@Riverpod(keepAlive: true)
TargetPlatform spellCheckAvailabilityPlatform(Ref ref) {
  return defaultTargetPlatform;
}

@Riverpod(keepAlive: true)
SpellCheckService? spellCheckAvailabilityService(Ref ref) {
  return noteSpellCheckService(
    ref.watch(spellCheckAvailabilityPlatformProvider),
  );
}

@Riverpod(keepAlive: true)
Future<SpellCheckAvailability> spellCheckAvailability(Ref ref) {
  if (ref.watch(spellCheckAvailabilityPlatformProvider) !=
      TargetPlatform.android) {
    return Future<SpellCheckAvailability>.value(
      SpellCheckAvailability.available,
    );
  }
  final SpellCheckService? service = ref.watch(
    spellCheckAvailabilityServiceProvider,
  );
  if (service == null) {
    return Future<SpellCheckAvailability>.value(
      SpellCheckAvailability.unavailable,
    );
  }
  final Completer<SpellCheckAvailability> answer =
      Completer<SpellCheckAvailability>();
  void settle(SpellCheckAvailability availability) {
    if (!answer.isCompleted) {
      answer.complete(availability);
    }
  }

  final Timer timeout = Timer(
    spellCheckProbeTimeout,
    () => settle(SpellCheckAvailability.unavailable),
  );
  ref.onDispose(timeout.cancel);
  unawaited(
    _probe(service, PlatformDispatcher.instance.locale).then((
      SpellCheckAvailability availability,
    ) {
      timeout.cancel();
      settle(availability);
    }),
  );
  return answer.future;
}

Future<SpellCheckAvailability> _probe(
  SpellCheckService service,
  Locale locale,
) async {
  try {
    final List<SuggestionSpan>? spans = await service
        .fetchSpellCheckSuggestions(locale, spellCheckProbeWord);
    return spans == null || spans.isEmpty
        ? SpellCheckAvailability.unavailable
        : SpellCheckAvailability.available;
  } on Object {
    return SpellCheckAvailability.unavailable;
  }
}
