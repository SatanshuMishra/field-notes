import 'dart:async';
import 'dart:collection';

import 'package:shelf/shelf.dart';

import 'timers.dart';

const int maxRequestsInFlight = 32;
const int maxPullsInFlight = 2;
const int maxPushesInFlight = 4;
const Duration pushSlotWaitLimit = Duration(seconds: 30);

const String requestHoldContextKey = 'relay.request_hold';

final class _Waiter {
  final Completer<bool> admitted = Completer<bool>();
  late final Timer timer;
}

final class RequestsInFlight {
  RequestsInFlight({this.limit = maxRequestsInFlight});

  final int limit;
  final Map<String, int> _counts = <String, int>{};
  final Map<String, ListQueue<_Waiter>> _waiters =
      <String, ListQueue<_Waiter>>{};

  int count(String key) => _counts[key] ?? 0;

  int waiting(String key) => _waiters[key]?.length ?? 0;

  bool enter(String key) {
    final int current = count(key);
    if (current >= limit) {
      return false;
    }
    _counts[key] = current + 1;
    return true;
  }

  Future<bool> enterWithin(
    String key, {
    required Duration wait,
    required StartTimer startTimer,
  }) {
    if (enter(key)) {
      return Future<bool>.value(true);
    }
    final ListQueue<_Waiter> queue = _waiters.putIfAbsent(
      key,
      ListQueue<_Waiter>.new,
    );
    final _Waiter waiter = _Waiter();
    waiter.timer = startTimer(wait, () {
      if (queue.remove(waiter)) {
        _forgetIfIdle(key, queue);
        waiter.admitted.complete(false);
      }
    });
    queue.addLast(waiter);
    return waiter.admitted.future;
  }

  void leave(String key) {
    final ListQueue<_Waiter>? queue = _waiters[key];
    if (queue != null && queue.isNotEmpty) {
      final _Waiter next = queue.removeFirst();
      _forgetIfIdle(key, queue);
      next.timer.cancel();
      next.admitted.complete(true);
      return;
    }
    final int remaining = count(key) - 1;
    if (remaining > 0) {
      _counts[key] = remaining;
    } else {
      _counts.remove(key);
    }
  }

  void _forgetIfIdle(String key, ListQueue<_Waiter> queue) {
    if (queue.isEmpty) {
      _waiters.remove(key);
    }
  }
}

typedef _Entry = ({RequestsInFlight counts, String key});

final class RequestHold {
  final List<_Entry> _entries = <_Entry>[];
  bool _released = false;

  bool get released => _released;

  bool holds(RequestsInFlight counts, String key) => _entries.any(
    (_Entry entry) => identical(entry.counts, counts) && entry.key == key,
  );

  bool enter(RequestsInFlight counts, String key) {
    if (holds(counts, key)) {
      return true;
    }
    if (_released || !counts.enter(key)) {
      return false;
    }
    _entries.add((counts: counts, key: key));
    return true;
  }

  Future<bool> enterWithin(
    RequestsInFlight counts,
    String key, {
    required Duration wait,
    required StartTimer startTimer,
  }) async {
    if (holds(counts, key)) {
      return true;
    }
    if (_released ||
        !await counts.enterWithin(key, wait: wait, startTimer: startTimer)) {
      return false;
    }
    if (_released) {
      counts.leave(key);
      return false;
    }
    _entries.add((counts: counts, key: key));
    return true;
  }

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    for (final _Entry entry in _entries) {
      entry.counts.leave(entry.key);
    }
    _entries.clear();
  }
}

RequestHold? holdOf(Request request) =>
    request.context[requestHoldContextKey] as RequestHold?;

Future<Response> holding(
  Request request,
  FutureOr<Response> Function(RequestHold hold) handle,
) async {
  final RequestHold? shared = holdOf(request);
  final RequestHold hold = shared ?? RequestHold();
  try {
    return await handle(hold);
  } finally {
    if (shared == null) {
      hold.release();
    }
  }
}
