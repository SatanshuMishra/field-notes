import 'dart:ui';

import 'package:flutter/services.dart';

const String spellCheckChannelName = 'field_notes/spellcheck';
const String spellCheckMethod = 'check';
const int maxSpellSuggestions = 5;

final class MacosSpellCheckService implements SpellCheckService {
  const MacosSpellCheckService({
    this._channel = const MethodChannel(spellCheckChannelName),
  });

  final MethodChannel _channel;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (text.isEmpty) {
      return const <SuggestionSpan>[];
    }
    final List<Object?>? answer;
    try {
      answer = await _channel.invokeListMethod<Object?>(
        spellCheckMethod,
        <String, Object?>{'text': text},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    final List<SuggestionSpan> spans = <SuggestionSpan>[
      for (final Object? entry in answer ?? const <Object?>[])
        ?_spanFrom(entry, text.length),
    ];
    return spans..sort(
      (SuggestionSpan a, SuggestionSpan b) =>
          a.range.start.compareTo(b.range.start),
    );
  }
}

SuggestionSpan? _spanFrom(Object? entry, int textLength) {
  if (entry is! Map<Object?, Object?>) {
    return null;
  }
  final Object? start = entry['start'];
  final Object? end = entry['end'];
  if (start is! int || end is! int) {
    return null;
  }
  if (start < 0 || end > textLength || start >= end) {
    return null;
  }
  final Object? suggestions = entry['suggestions'];
  final List<String> words = suggestions is List<Object?>
      ? suggestions.whereType<String>().take(maxSpellSuggestions).toList()
      : const <String>[];
  return SuggestionSpan(TextRange(start: start, end: end), words);
}

SpellCheckService? noteSpellCheckService(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.macOS => const MacosSpellCheckService(),
    TargetPlatform.android => DefaultSpellCheckService(),
    TargetPlatform.iOS ||
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.fuchsia => null,
  };
}
