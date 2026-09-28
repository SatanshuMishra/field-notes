import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily reminder';
  static const String _channelDescription =
      'Reminds you to write your field note for the day.';
  static const String _title = 'Field Notes';
  static const String _body = "You haven't written today's field note yet.";
  static const String _androidIcon = '@mipmap/ic_launcher';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    macOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  Future<void> _ensureInitialized() async {
    final Future<void> ready = _ready ??= _initialize();
    try {
      await ready;
    } catch (_) {
      if (identical(_ready, ready)) {
        _ready = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  @override
  Future<ReminderPermission> permissionStatus() async {
    await _ensureInitialized();
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return _permissionFrom(await android.areNotificationsEnabled());
    }
    final MacOSFlutterLocalNotificationsPlugin? macOS = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macOS != null) {
      return _permissionFrom((await macOS.checkPermissions())?.isEnabled);
    }
    return ReminderPermission.unknown;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final MacOSFlutterLocalNotificationsPlugin? macOS = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macOS != null) {
      return await macOS.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  ReminderPermission _permissionFrom(bool? enabled) => switch (enabled) {
        true => ReminderPermission.granted,
        false => ReminderPermission.denied,
        null => ReminderPermission.unknown,
      };

  @override
  Future<void> schedule(List<ReminderBooking> bookings) async {
    await _ensureInitialized();
    await _cancelAll();
    for (final ReminderBooking booking in bookings) {
      await _plugin.zonedSchedule(
        id: booking.id,
        title: _title,
        body: _body,
        scheduledDate: tz.TZDateTime.from(booking.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancel() async {
    await _ensureInitialized();
    await _cancelAll();
  }

  Future<void> _cancelAll() async {
    for (final int id in ReminderService.bookingIds) {
      await _plugin.cancel(id: id);
    }
  }
}
