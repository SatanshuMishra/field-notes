import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const MethodChannel _timezoneChannel = MethodChannel('flutter_timezone');
const MethodChannel _notificationSettingsChannel = MethodChannel(
  'field_notes/notification_settings',
);

class _RecordingMacOSPlugin implements MacOSFlutterLocalNotificationsPlugin {
  final List<Symbol> calls = <Symbol>[];

  @override
  Future<NotificationsEnabledOptions?> checkPermissions() async {
    calls.add(#checkPermissions);
    return const NotificationsEnabledOptions(
      isEnabled: false,
      isSoundEnabled: false,
      isAlertEnabled: false,
      isBadgeEnabled: false,
      isProvisionalEnabled: false,
      isCriticalEnabled: false,
      isProvidesAppNotificationSettingsEnabled: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    if (invocation.memberName == #requestPermissions) {
      return Future<bool?>.value(true);
    }
    return super.noSuchMethod(invocation);
  }
}

class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  _RecordingPlugin(this.macOS);

  final _RecordingMacOSPlugin macOS;
  final List<InitializationSettings> initializations =
      <InitializationSettings>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializations.add(settings);
    return true;
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    final _RecordingMacOSPlugin implementation = macOS;
    return implementation is T ? implementation as T : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScheduledToast {
  const _ScheduledToast({
    required this.id,
    required this.scheduledDate,
    required this.details,
  });

  final int id;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails details;
}

class _UnresolvedPlugin implements FlutterLocalNotificationsPlugin {
  final List<InitializationSettings> initializations =
      <InitializationSettings>[];
  final List<_ScheduledToast> scheduled = <_ScheduledToast>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializations.add(settings);
    return true;
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add(
      _ScheduledToast(
        id: id,
        scheduledDate: scheduledDate,
        details: notificationDetails,
      ),
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _answerTimezone(String identifier) {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    _timezoneChannel,
    (MethodCall call) async => identifier,
  );
  addTearDown(() => messenger.setMockMethodCallHandler(_timezoneChannel, null));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize requests no permission on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      _timezoneChannel,
      (MethodCall call) async => 'Europe/London',
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(_timezoneChannel, null),
    );
    final _RecordingMacOSPlugin macOS = _RecordingMacOSPlugin();
    final _RecordingPlugin plugin = _RecordingPlugin(macOS);
    final LocalNotificationsReminderScheduler scheduler =
        LocalNotificationsReminderScheduler(plugin: plugin);

    final ReminderPermission status = await scheduler.permissionStatus();

    expect(plugin.initializations, hasLength(1));
    final DarwinInitializationSettings? darwin =
        plugin.initializations.single.macOS;
    expect(darwin, isNotNull);
    expect(darwin!.requestAlertPermission, isFalse);
    expect(darwin.requestSoundPermission, isFalse);
    expect(darwin.requestBadgePermission, isFalse);
    expect(macOS.calls, <Symbol>[#checkPermissions]);
    expect(status, ReminderPermission.denied);
  });

  test('reminders use the white peony as their Android small icon', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      _timezoneChannel,
      (MethodCall call) async => 'Europe/London',
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(_timezoneChannel, null),
    );
    final _RecordingPlugin plugin = _RecordingPlugin(_RecordingMacOSPlugin());
    final LocalNotificationsReminderScheduler scheduler =
        LocalNotificationsReminderScheduler(plugin: plugin);

    await scheduler.permissionStatus();

    expect(
      plugin.initializations.single.android?.defaultIcon,
      '@drawable/ic_stat_peony',
    );
  });

  test("Windows initialises notifications with the app's identity", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _answerTimezone('Europe/London');
    final _UnresolvedPlugin plugin = _UnresolvedPlugin();
    final LocalNotificationsReminderScheduler scheduler =
        LocalNotificationsReminderScheduler(plugin: plugin);
    final ReminderBooking booking = ReminderBooking(
      id: ReminderService.bookingIds.first,
      at: DateTime(2026, 10, 9, 20),
    );

    await scheduler.schedule(<ReminderBooking>[booking]);

    expect(plugin.initializations, hasLength(1));
    final WindowsInitializationSettings? windows =
        plugin.initializations.single.windows;
    expect(windows, isNotNull);
    expect(windows!.appName, 'Field Notes');
    expect(windows.appUserModelId, 'dev.satanshumishra.FieldNotes');
    expect(windows.guid, 'D6A0FDC5-EAD0-45F8-9024-F50F093EE5B2');
    expect(windowsAppUserModelId, 'dev.satanshumishra.FieldNotes');
    expect(plugin.scheduled, hasLength(1));
    expect(plugin.scheduled.single.details.windows, isNotNull);
    expect(
      plugin.scheduled.single.scheduledDate.isAtSameMomentAs(booking.at),
      isTrue,
    );
  });

  test(
    'Windows reads the toast setting as the notification permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _answerTimezone('Europe/London');
      final TestDefaultBinaryMessenger messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final List<String> methods = <String>[];
      void answerStatus(Future<String?> Function() reply) {
        messenger.setMockMethodCallHandler(_notificationSettingsChannel, (
          MethodCall call,
        ) {
          methods.add(call.method);
          return reply();
        });
      }

      addTearDown(
        () => messenger.setMockMethodCallHandler(
          _notificationSettingsChannel,
          null,
        ),
      );
      final LocalNotificationsReminderScheduler scheduler =
          LocalNotificationsReminderScheduler(plugin: _UnresolvedPlugin());

      answerStatus(() async => 'disabled');
      expect(await scheduler.permissionStatus(), ReminderPermission.denied);
      expect(await scheduler.requestPermission(), isFalse);

      answerStatus(() async => 'enabled');
      expect(await scheduler.permissionStatus(), ReminderPermission.granted);
      expect(await scheduler.requestPermission(), isTrue);

      answerStatus(() async => throw MissingPluginException());
      expect(await scheduler.permissionStatus(), ReminderPermission.granted);
      expect(await scheduler.requestPermission(), isTrue);

      answerStatus(() async => throw PlatformException(code: 'unavailable'));
      expect(await scheduler.permissionStatus(), ReminderPermission.granted);
      expect(await scheduler.requestPermission(), isTrue);

      expect(methods, hasLength(8));
      expect(methods, everyElement('status'));
    },
  );

  test('an unknown time zone schedules against UTC', () async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Edmonton'));
    addTearDown(() => tz.setLocalLocation(tz.UTC));
    _answerTimezone('Etc/Unknown');
    final _UnresolvedPlugin plugin = _UnresolvedPlugin();
    final LocalNotificationsReminderScheduler scheduler =
        LocalNotificationsReminderScheduler(plugin: plugin);
    final List<ReminderBooking> bookings = <ReminderBooking>[
      ReminderBooking(
        id: ReminderService.bookingIds[0],
        at: DateTime(2026, 10, 9, 20),
      ),
      ReminderBooking(
        id: ReminderService.bookingIds[1],
        at: DateTime(2026, 10, 10, 20),
      ),
    ];

    await scheduler.schedule(bookings);

    expect(tz.local, same(tz.UTC));
    expect(
      plugin.scheduled.map((_ScheduledToast toast) => toast.id).toList(),
      bookings.map((ReminderBooking booking) => booking.id).toList(),
    );
    for (int index = 0; index < bookings.length; index++) {
      final tz.TZDateTime scheduledDate = plugin.scheduled[index].scheduledDate;
      expect(scheduledDate.location, same(tz.UTC));
      expect(scheduledDate.isAtSameMomentAs(bookings[index].at), isTrue);
    }
  });
}
