import 'dart:async';

const Duration largeBodyWaitLimit = Duration(seconds: 30);

final class _Waiter {
  _Waiter(this.accountId);

  final String accountId;
  final Completer<bool> admitted = Completer<bool>();
  late final Timer timer;
}

final class LargeBodySlots {
  LargeBodySlots({
    required this.total,
    required this.perAccount,
    this.waitLimit = largeBodyWaitLimit,
  });

  final int total;
  final int perAccount;
  final Duration waitLimit;
  final Map<String, int> _held = <String, int>{};
  final List<_Waiter> _queue = <_Waiter>[];
  int _active = 0;

  int get active => _active;

  int get waiting => _queue.length;

  Future<bool> acquire(String accountId) {
    if (_fits(accountId)) {
      _take(accountId);
      return Future<bool>.value(true);
    }
    final _Waiter waiter = _Waiter(accountId);
    waiter.timer = Timer(waitLimit, () {
      if (_queue.remove(waiter)) {
        waiter.admitted.complete(false);
      }
    });
    _queue.add(waiter);
    return waiter.admitted.future;
  }

  void release(String accountId) {
    _active--;
    final int remaining = (_held[accountId] ?? 1) - 1;
    if (remaining > 0) {
      _held[accountId] = remaining;
    } else {
      _held.remove(accountId);
    }
    for (final _Waiter waiter in _queue.toList()) {
      if (_fits(waiter.accountId)) {
        _queue.remove(waiter);
        waiter.timer.cancel();
        _take(waiter.accountId);
        waiter.admitted.complete(true);
      }
    }
  }

  bool _fits(String accountId) =>
      _active < total && (_held[accountId] ?? 0) < perAccount;

  void _take(String accountId) {
    _active++;
    _held[accountId] = (_held[accountId] ?? 0) + 1;
  }
}
