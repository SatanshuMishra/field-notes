import 'package:flutter/foundation.dart';

import 'reminder_service.dart';

class ReminderLedger {
  const ReminderLedger({required this.booked, required this.unsettled});

  final List<ReminderBooking> booked;
  final Set<int> unsettled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderLedger &&
          listEquals(booked, other.booked) &&
          setEquals(unsettled, other.unsettled);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(booked), Object.hashAllUnordered(unsettled));

  @override
  String toString() => 'ReminderLedger(booked: $booked, unsettled: $unsettled)';
}

abstract interface class ReminderLedgerStore {
  Future<ReminderLedger?> read();

  Future<void> write(ReminderLedger ledger);
}
