import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_settings_opener.dart';
import 'reminder_scheduler.dart';

const String reminderNotificationTitle = 'Field Notes';
const String reminderNotificationBody =
    "You haven't written today's field note yet.";
const String reminderNotificationIcon = '@drawable/ic_stat_peony';
const String windowsAppUserModelId = 'dev.satanshumishra.FieldNotes';
const String windowsNotificationGuid = 'D6A0FDC5-EAD0-45F8-9024-F50F093EE5B2';

class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this._notificationStatus = const ChannelNotificationStatus(),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily reminder';
  static const String _channelDescription =
      'Reminds you to write your field note for the day.';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    macOS: DarwinNotificationDetails(),
    windows: WindowsNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final ChannelNotificationStatus _notificationStatus;
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
    tz.setLocalLocation(_locationFor(info.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(reminderNotificationIcon),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'Field Notes',
          appUserModelId: windowsAppUserModelId,
          guid: windowsNotificationGuid,
        ),
      ),
    );
  }

  tz.Location _locationFor(String identifier) {
    try {
      return tz.getLocation(identifier);
    } on tz.LocationNotFoundException {
      return tz.UTC;
    }
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
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _windowsPermission();
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
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await _windowsPermission() == ReminderPermission.granted;
    }
    return false;
  }

  Future<ReminderPermission> _windowsPermission() async {
    try {
      final String? status = await _notificationStatus.read();
      return status == 'disabled'
          ? ReminderPermission.denied
          : ReminderPermission.granted;
    } on MissingPluginException {
      return ReminderPermission.granted;
    } on PlatformException {
      return ReminderPermission.granted;
    }
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
    final AndroidScheduleMode mode = await _androidScheduleMode();
    for (final ReminderBooking booking in bookings) {
      await _plugin.zonedSchedule(
        id: booking.id,
        title: reminderNotificationTitle,
        body: reminderNotificationBody,
        scheduledDate: tz.TZDateTime.from(booking.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: mode,
      );
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      return await android.canScheduleExactNotifications() == true
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } on PlatformException {
      return AndroidScheduleMode.inexactAllowWhileIdle;
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
