import 'dart:convert';

import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/domain/services/reminder_ledger.dart';
import 'package:field_notes/domain/services/reminder_service.dart';

import 'settings_keys.dart';

const String _bookedField = 'booked';
const String _unsettledField = 'unsettled';
const String _idField = 'id';
const String _atField = 'at';
const String _bodyField = 'body';

class DriftReminderLedgerStore implements ReminderLedgerStore {
  DriftReminderLedgerStore(this._db);

  final AppDatabase _db;

  @override
  Future<ReminderLedger?> read() async {
    final Setting? row =
        await (_db.select(_db.settings)
              ..where((t) => t.key.equals(SettingsKeys.reminderLedger)))
            .getSingleOrNull();
    return row == null ? null : _decode(row.value);
  }

  @override
  Future<void> write(ReminderLedger ledger) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: SettingsKeys.reminderLedger,
            value: _encode(ledger),
          ),
        );
  }

  String _encode(ReminderLedger ledger) => jsonEncode(<String, Object>{
    _bookedField: <Map<String, Object>>[
      for (final ReminderBooking booking in ledger.booked)
        <String, Object>{
          _idField: booking.id,
          _atField: booking.at.microsecondsSinceEpoch,
          _bodyField: booking.body,
        },
    ],
    _unsettledField: <int>[
      for (final int id in ReminderService.bookingIds)
        if (ledger.unsettled.contains(id)) id,
    ],
  });

  ReminderLedger? _decode(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded case {
        _bookedField: final List<Object?> booked,
        _unsettledField: final List<Object?> unsettled,
      }) {
        final List<ReminderBooking> bookings = <ReminderBooking>[
          for (final Object? entry in booked) ?_booking(entry),
        ];
        final Set<int> ids = <int>{
          for (final Object? id in unsettled)
            if (id is int && ReminderService.bookingIds.contains(id)) id,
        };
        final bool whole =
            bookings.length == booked.length && ids.length == unsettled.length;
        return whole
            ? ReminderLedger(
                booked: List<ReminderBooking>.unmodifiable(bookings),
                unsettled: Set<int>.unmodifiable(ids),
              )
            : null;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  ReminderBooking? _booking(Object? entry) {
    if (entry
        case {
          _idField: final int id,
          _atField: final int at,
          _bodyField: final String body,
        }
        when ReminderService.bookingIds.contains(id)) {
      return ReminderBooking(
        id: id,
        at: DateTime.fromMicrosecondsSinceEpoch(at),
        body: body,
      );
    }
    return null;
  }
}
