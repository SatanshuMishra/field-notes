import 'package:flutter/foundation.dart';

import 'package:field_notes/features/garden/model/meadow_year.dart';

@immutable
class MeadowSceneKey {
  const MeadowSceneKey({required this.seed, required this.year});

  final int seed;
  final MeadowYear year;

  @override
  bool operator ==(Object other) =>
      other is MeadowSceneKey &&
      other.seed == seed &&
      other.year.year == year.year &&
      listEquals(other.year.days, year.days);

  @override
  int get hashCode => Object.hash(seed, year.year, year.days.length);
}

class MeadowSceneCache<K extends Object, V extends Object> {
  MeadowSceneCache({this._onRelease});

  final void Function(V value)? _onRelease;
  Map<K, _Held<V>> _held = Map<K, _Held<V>>.unmodifiable(<K, _Held<V>>{});

  int holdersOf(K key) => _held[key]?.holders ?? 0;

  V? acquire(K key) {
    final _Held<V>? held = _held[key];
    if (held == null) {
      return null;
    }
    _store(key, held.retained());
    return held.value;
  }

  V share(K key, V value) {
    final _Held<V>? held = _held[key];
    if (held == null) {
      _store(key, _Held<V>(value: value, holders: 1));
      return value;
    }
    if (!identical(held.value, value)) {
      _onRelease?.call(value);
    }
    _store(key, held.retained());
    return held.value;
  }

  void release(K key, V value) {
    final _Held<V>? held = _held[key];
    if (held == null || !identical(held.value, value)) {
      _onRelease?.call(value);
      return;
    }
    if (held.holders > 1) {
      _store(key, held.released());
      return;
    }
    _held = Map<K, _Held<V>>.unmodifiable(<K, _Held<V>>{
      for (final MapEntry<K, _Held<V>> entry in _held.entries)
        if (entry.key != key) entry.key: entry.value,
    });
    _onRelease?.call(value);
  }

  void _store(K key, _Held<V> held) {
    _held = Map<K, _Held<V>>.unmodifiable(<K, _Held<V>>{..._held, key: held});
  }
}

@immutable
class _Held<V extends Object> {
  const _Held({required this.value, required this.holders});

  final V value;
  final int holders;

  _Held<V> retained() => _Held<V>(value: value, holders: holders + 1);

  _Held<V> released() => _Held<V>(value: value, holders: holders - 1);
}
