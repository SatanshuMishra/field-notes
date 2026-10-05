const int maxRequestsInFlight = 32;

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
