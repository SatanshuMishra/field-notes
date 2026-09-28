import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';

class RecordingReminderScheduler implements ReminderScheduler {
  RecordingReminderScheduler({this.permission = ReminderPermission.granted});

  final ReminderPermission permission;
  final List<List<ReminderBooking>> bookings = <List<ReminderBooking>>[];
  Map<int, DateTime> booked = const <int, DateTime>{};
  int cancelCount = 0;
  int permissionRequests = 0;
  int statusChecks = 0;

  @override
  Future<ReminderPermission> permissionStatus() async {
    statusChecks++;
    return permission;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission == ReminderPermission.granted;
  }

  @override
  Future<void> schedule(List<ReminderBooking> bookings) async {
    this.bookings.add(List<ReminderBooking>.unmodifiable(bookings));
    booked = Map<int, DateTime>.unmodifiable(<int, DateTime>{
      for (final ReminderBooking booking in bookings) booking.id: booking.at,
    });
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    booked = const <int, DateTime>{};
  }
}
