import 'dart:async';

import 'package:shelf/shelf.dart';

const int maxRequestsInFlight = 32;
const int maxPullsInFlight = 2;
const int maxPushesInFlight = 4;

const String requestHoldContextKey = 'relay.request_hold';

final class RequestsInFlight {
  RequestsInFlight({this.limit = maxRequestsInFlight});

  final int limit;
  final Map<String, int> _counts = <String, int>{};

  int count(String key) => _counts[key] ?? 0;

  bool enter(String key) {
    final int current = count(key);
    if (current >= limit) {
      return false;
    }
    _counts[key] = current + 1;
    return true;
  }

  void leave(String key) {
    final int remaining = count(key) - 1;
    if (remaining > 0) {
      _counts[key] = remaining;
    } else {
      _counts.remove(key);
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
