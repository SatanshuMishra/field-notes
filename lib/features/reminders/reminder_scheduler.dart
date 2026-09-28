import 'package:field_notes/domain/services/reminder_service.dart';

enum ReminderPermission { granted, denied, unknown }

abstract interface class ReminderScheduler {
  Future<ReminderPermission> permissionStatus();

  Future<bool> requestPermission();

  Future<void> schedule(List<ReminderBooking> bookings);

  Future<void> cancel();
}
