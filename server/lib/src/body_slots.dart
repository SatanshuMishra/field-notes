import 'dart:async';

import 'timers.dart';

const Duration largeBodyWaitLimit = Duration(seconds: 30);
const Duration largeBodyHoldLimit = Duration(seconds: 60);
const int maxLargeBodyWaitersPerAccount = 8;

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
    this.holdLimit = largeBodyHoldLimit,
    this.waitersPerAccount = maxLargeBodyWaitersPerAccount,
    this._startTimer = Timer.new,
  });

  final int total;
  final int perAccount;
  final Duration waitLimit;
  final Duration holdLimit;
  final int waitersPerAccount;
  final StartTimer _startTimer;
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
    if (_queue
            .where((_Waiter waiter) => waiter.accountId == accountId)
            .length >=
        waitersPerAccount) {
      return Future<bool>.value(false);
    }
    final _Waiter waiter = _Waiter(accountId);
    waiter.timer = _startTimer(waitLimit, () {
      if (_queue.remove(waiter)) {
        waiter.admitted.complete(false);
      }
    });
    _queue.add(waiter);
    return waiter.admitted.future;
  }

  Timer holdDeadline(void Function() onExpired) =>
      _startTimer(holdLimit, onExpired);

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
