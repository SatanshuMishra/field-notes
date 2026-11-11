import 'package:field_notes/domain/services/reminder_ledger.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
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
    required this.mode,
  });

  final int id;
  final tz.TZDateTime scheduledDate;
  final NotificationDetails details;
  final AndroidScheduleMode mode;
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
        mode: androidScheduleMode,
      ),
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingWindowsPlugin implements FlutterLocalNotificationsPlugin {
  _FailingWindowsPlugin({
    required this.failingCancels,
    required this.failingSchedules,
  });

  final Set<int> failingCancels;
  final Set<int> failingSchedules;
  final List<int> cancelled = <int>[];
  final List<int> scheduled = <int>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  Future<void> cancel({required int id, String? tag}) async {
    if (failingCancels.contains(id)) {
      throw Exception('RemoveFromSchedule failed for $id');
    }
    cancelled.add(id);
  }

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
    if (failingSchedules.contains(id)) {
      throw Exception('AddToSchedule failed for $id');
    }
    scheduled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

enum _CallKind { cancel, schedule }

class _Call {
  const _Call.cancel(this.id)
    : kind = _CallKind.cancel,
      title = null,
      body = null,
      scheduledDate = null,
      details = null,
      mode = null;

  const _Call.schedule({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.details,
    required this.mode,
  }) : kind = _CallKind.schedule;

  final _CallKind kind;
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime? scheduledDate;
  final NotificationDetails? details;
  final AndroidScheduleMode? mode;
}

class _CallRecordingPlugin implements FlutterLocalNotificationsPlugin {
  _CallRecordingPlugin({this.macOS, this.android});

  final _RecordingMacOSPlugin? macOS;
  final _ExactAlarmAndroid? android;
  final List<_Call> calls = <_Call>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    final Object? macOSImplementation = macOS;
    if (macOSImplementation is T) {
      return macOSImplementation;
    }
    final Object? androidImplementation = android;
    if (androidImplementation is T) {
      return androidImplementation;
    }
    return null;
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    calls.add(_Call.cancel(id));
  }

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
    calls.add(
      _Call.schedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        details: notificationDetails,
        mode: androidScheduleMode,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<ReminderBooking> _fourBookings() {
  final DateTime start = DateTime.now().add(const Duration(days: 1));
  return <ReminderBooking>[
    for (int offset = 0; offset < 4; offset++)
      ReminderBooking(
        id: ReminderService.bookingIds[offset],
        at: DateTime(start.year, start.month, start.day + offset, 20),
        body: 'nudge $offset',
      ),
  ];
}

List<String> _callNames(_CallRecordingPlugin plugin) => <String>[
  for (final _Call call in plugin.calls) '${call.kind.name} ${call.id}',
];

Future<(LocalNotificationsReminderScheduler, _CallRecordingPlugin)>
_bookedOnMacOS(List<ReminderBooking> bookings) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  _answerTimezone('Europe/London');
  final _CallRecordingPlugin plugin = _CallRecordingPlugin(
    macOS: _RecordingMacOSPlugin(),
  );
  final LocalNotificationsReminderScheduler scheduler =
      LocalNotificationsReminderScheduler(plugin: plugin);
  await scheduler.schedule(bookings);
  plugin.calls.clear();
  return (scheduler, plugin);
}

List<String> _captureLog() {
  final List<String> lines = <String>[];
  final DebugPrintCallback original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
  addTearDown(() => debugPrint = original);
  return lines;
}

class _ExactAlarmAndroid implements AndroidFlutterLocalNotificationsPlugin {
  _ExactAlarmAndroid(this._allowed);

  final Future<bool?> Function() _allowed;

  @override
  Future<bool?> canScheduleExactNotifications() => _allowed();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AndroidPlugin extends _UnresolvedPlugin {
  _AndroidPlugin(this.android);

  final _ExactAlarmAndroid android;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    final _ExactAlarmAndroid implementation = android;
    return implementation is T ? implementation as T : null;
  }
}

Future<AndroidScheduleMode> _androidModeWhen(
  Future<bool?> Function() allowed,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  _answerTimezone('Europe/London');
  final _AndroidPlugin plugin = _AndroidPlugin(_ExactAlarmAndroid(allowed));
  final LocalNotificationsReminderScheduler scheduler =
      LocalNotificationsReminderScheduler(plugin: plugin);

  await scheduler.schedule(<ReminderBooking>[
    ReminderBooking(
      id: ReminderService.bookingIds.first,
      at: DateTime(2026, 10, 9, 20),
      body: reminderEveningBody,
    ),
  ]);

  expect(plugin.scheduled, hasLength(1));
  return plugin.scheduled.single.mode;
}

class _MemoryLedger implements ReminderLedgerStore {
  _MemoryLedger({this.readError, this.writeError});

  final Object? readError;
  final Object? writeError;
  ReminderLedger? stored;

  @override
  Future<ReminderLedger?> read() async {
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return stored;
  }

  @override
  Future<void> write(ReminderLedger ledger) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
    stored = ledger;
  }
}

List<ReminderBooking> _eveningsWeek() =>
    const ReminderService().upcomingReminders(
      enabled: true,
      schedule: ReminderSchedule.evenings,
      customTime: ReminderTime.defaultTime,
      now: DateTime(2026, 11, 10, 9),
    )!;

void _onWindows() {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  _answerTimezone('Europe/London');
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
      body: reminderEveningBody,
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
        body: reminderEveningBody,
      ),
      ReminderBooking(
        id: ReminderService.bookingIds[1],
        at: DateTime(2026, 10, 10, 20),
        body: reminderLastCallBody,
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

  test(
    'an Android reminder rings exactly when exact alarms are allowed',
    () async {
      expect(
        await _androidModeWhen(() async => true),
        AndroidScheduleMode.exactAllowWhileIdle,
      );
    },
  );

  test(
    'without exact alarm access an Android reminder still schedules, inexactly',
    () async {
      expect(
        await _androidModeWhen(() async => false),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
      expect(
        await _androidModeWhen(() async => null),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
      expect(
        await _androidModeWhen(
          () async => throw PlatformException(code: 'unavailable'),
        ),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    },
  );

  test(
    'a failing cancel and a failing schedule still book every other reminder',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      _answerTimezone('Europe/London');
      final List<int> ids = ReminderService.bookingIds;
      final _FailingWindowsPlugin plugin = _FailingWindowsPlugin(
        failingCancels: <int>{ids[0]},
        failingSchedules: <int>{ids[2]},
      );
      final LocalNotificationsReminderScheduler scheduler =
          LocalNotificationsReminderScheduler(plugin: plugin);

      final bool settled = await scheduler.schedule(_fourBookings());

      expect(settled, isFalse);
      expect(plugin.cancelled, ids.sublist(1));
      expect(plugin.scheduled, <int>[ids[1], ids[3]]);
    },
  );

  test('turning reminders off tries every id even when one fails', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _answerTimezone('Europe/London');
    final List<int> ids = ReminderService.bookingIds;
    final _FailingWindowsPlugin plugin = _FailingWindowsPlugin(
      failingCancels: <int>{ids[3]},
      failingSchedules: <int>{},
    );
    final LocalNotificationsReminderScheduler scheduler =
        LocalNotificationsReminderScheduler(plugin: plugin);

    final bool settled = await scheduler.cancel();

    expect(settled, isFalse);
    expect(plugin.cancelled, <int>[...ids.sublist(0, 3), ...ids.sublist(4)]);
    plugin.failingCancels.clear();
    expect(await scheduler.cancel(), isTrue);
    expect(plugin.cancelled.last, ids[3]);
  });

  test('when every call fails the app keeps going with no reminders', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _answerTimezone('Europe/London');
    final List<String> log = _captureLog();
    final List<int> ids = ReminderService.bookingIds;
    final _FailingWindowsPlugin plugin = _FailingWindowsPlugin(
      failingCancels: ids.toSet(),
      failingSchedules: ids.toSet(),
    );
    final LocalNotificationsReminderScheduler scheduler =
        LocalNotificationsReminderScheduler(plugin: plugin);

    await scheduler.schedule(_fourBookings());

    expect(plugin.cancelled, isEmpty);
    expect(plugin.scheduled, isEmpty);
    expect(log, hasLength(ids.length));
  });

  group('after the first booking only changed reminders are touched', () {
    test('the same bookings again touch nothing', () async {
      final List<ReminderBooking> bookings = _fourBookings();
      final (scheduler, plugin) = await _bookedOnMacOS(bookings);

      final bool settled = await scheduler.schedule(
        List<ReminderBooking>.of(bookings),
      );

      expect(settled, isTrue);
      expect(plugin.calls, isEmpty);
    });

    test('a changed reminder is cancelled and booked again alone', () async {
      final List<ReminderBooking> bookings = _fourBookings();
      final (scheduler, plugin) = await _bookedOnMacOS(bookings);
      final ReminderBooking changed = ReminderBooking(
        id: bookings[1].id,
        at: bookings[1].at,
        body: reminderLastCallBloomBody,
      );

      await scheduler.schedule(<ReminderBooking>[
        bookings[0],
        changed,
        bookings[2],
        bookings[3],
      ]);

      expect(_callNames(plugin), <String>[
        'cancel ${changed.id}',
        'schedule ${changed.id}',
      ]);
      expect(plugin.calls.last.body, reminderLastCallBloomBody);
    });

    test(
      'a dropped reminder is only cancelled and a new one only booked',
      () async {
        final List<ReminderBooking> bookings = _fourBookings();
        final (scheduler, plugin) = await _bookedOnMacOS(bookings);
        final ReminderBooking added = ReminderBooking(
          id: ReminderService.bookingIds[4],
          at: bookings[3].at.add(const Duration(days: 1)),
          body: reminderEveningBody,
        );

        await scheduler.schedule(<ReminderBooking>[
          ...bookings.sublist(1),
          added,
        ]);

        expect(_callNames(plugin), <String>[
          'cancel ${bookings[0].id}',
          'schedule ${added.id}',
        ]);
      },
    );

    test('turning reminders off cancels only what was booked', () async {
      final List<ReminderBooking> bookings = _fourBookings();
      final (scheduler, plugin) = await _bookedOnMacOS(bookings);

      await scheduler.cancel();
      await scheduler.cancel();

      expect(_callNames(plugin), <String>[
        for (final ReminderBooking booking in bookings) 'cancel ${booking.id}',
      ]);
    });

    test(
      'an id whose cancel failed is cancelled again before it is rebooked',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        _answerTimezone('Europe/London');
        final List<int> ids = ReminderService.bookingIds;
        final _FailingWindowsPlugin plugin = _FailingWindowsPlugin(
          failingCancels: <int>{ids[0]},
          failingSchedules: <int>{},
        );
        final LocalNotificationsReminderScheduler scheduler =
            LocalNotificationsReminderScheduler(plugin: plugin);
        final List<ReminderBooking> bookings = _fourBookings();
        expect(await scheduler.schedule(bookings), isFalse);
        plugin.cancelled.clear();
        plugin.scheduled.clear();
        plugin.failingCancels.clear();

        expect(await scheduler.schedule(bookings), isTrue);

        expect(plugin.cancelled, <int>[ids[0]]);
        expect(plugin.scheduled, <int>[ids[0]]);
      },
    );
  });

  group('across launches the ledger keeps what is booked', () {
    test(
      'a cold start over the booked week makes no calls when nothing changed',
      () async {
        _onWindows();
        final _MemoryLedger ledger = _MemoryLedger();
        final List<ReminderBooking> week = _eveningsWeek();
        final _CallRecordingPlugin launch = _CallRecordingPlugin();
        await LocalNotificationsReminderScheduler(
          plugin: launch,
          ledger: ledger,
        ).schedule(week);
        final _CallRecordingPlugin coldStart = _CallRecordingPlugin();

        final bool settled = await LocalNotificationsReminderScheduler(
          plugin: coldStart,
          ledger: ledger,
        ).schedule(List<ReminderBooking>.of(week));

        expect(_callNames(launch), <String>[
          for (final int id in ReminderService.bookingIds) 'cancel $id',
          for (final ReminderBooking booking in week) 'schedule ${booking.id}',
        ]);
        expect(week, hasLength(14));
        expect(_callNames(coldStart), isEmpty);
        expect(settled, isTrue);
      },
    );

    test('a cold start touches only the reminder that changed', () async {
      _onWindows();
      final _MemoryLedger ledger = _MemoryLedger();
      final List<ReminderBooking> week = _eveningsWeek();
      await LocalNotificationsReminderScheduler(
        plugin: _CallRecordingPlugin(),
        ledger: ledger,
      ).schedule(week);
      final ReminderBooking changed = ReminderBooking(
        id: week[1].id,
        at: week[1].at,
        body: reminderLastCallBloomBody,
      );
      final _CallRecordingPlugin coldStart = _CallRecordingPlugin();

      await LocalNotificationsReminderScheduler(
        plugin: coldStart,
        ledger: ledger,
      ).schedule(<ReminderBooking>[week[0], changed, ...week.sublist(2)]);

      expect(_callNames(coldStart), <String>[
        'cancel ${changed.id}',
        'schedule ${changed.id}',
      ]);
    });

    test('turning reminders off after a cold start cancels only the booked '
        'week', () async {
      _onWindows();
      final _MemoryLedger ledger = _MemoryLedger();
      final List<ReminderBooking> week = _eveningsWeek();
      await LocalNotificationsReminderScheduler(
        plugin: _CallRecordingPlugin(),
        ledger: ledger,
      ).schedule(week);
      final _CallRecordingPlugin coldStart = _CallRecordingPlugin();

      final bool settled = await LocalNotificationsReminderScheduler(
        plugin: coldStart,
        ledger: ledger,
      ).cancel();

      expect(_callNames(coldStart), <String>[
        for (final int id in ReminderService.bookingIds)
          if (week.any((ReminderBooking booking) => booking.id == id))
            'cancel $id',
      ]);
      expect(settled, isTrue);
    });

    test('a reminder that did not settle is cancelled and booked again after a '
        'cold start', () async {
      _onWindows();
      final List<int> ids = ReminderService.bookingIds;
      final _MemoryLedger ledger = _MemoryLedger();
      final List<ReminderBooking> bookings = _fourBookings();
      await LocalNotificationsReminderScheduler(
        plugin: _FailingWindowsPlugin(
          failingCancels: <int>{},
          failingSchedules: <int>{ids[2]},
        ),
        ledger: ledger,
      ).schedule(bookings);
      final _FailingWindowsPlugin coldStart = _FailingWindowsPlugin(
        failingCancels: <int>{},
        failingSchedules: <int>{},
      );

      final bool settled = await LocalNotificationsReminderScheduler(
        plugin: coldStart,
        ledger: ledger,
      ).schedule(bookings);

      expect(coldStart.cancelled, <int>[ids[2]]);
      expect(coldStart.scheduled, <int>[ids[2]]);
      expect(settled, isTrue);
    });

    test('without a ledger to write to nothing is booked and the run reports '
        'unsettled', () async {
      _onWindows();
      final _CallRecordingPlugin plugin = _CallRecordingPlugin();
      final LocalNotificationsReminderScheduler scheduler =
          LocalNotificationsReminderScheduler(
            plugin: plugin,
            ledger: _MemoryLedger(writeError: StateError('disk full')),
          );

      final bool settled = await scheduler.schedule(_fourBookings());

      expect(plugin.calls, isEmpty);
      expect(settled, isFalse);
    });

    test('a ledger that cannot be read clears every reminder id', () async {
      _onWindows();
      final _CallRecordingPlugin plugin = _CallRecordingPlugin();
      final List<ReminderBooking> bookings = _fourBookings();

      await LocalNotificationsReminderScheduler(
        plugin: plugin,
        ledger: _MemoryLedger(readError: StateError('locked')),
      ).schedule(bookings);

      expect(_callNames(plugin), <String>[
        for (final int id in ReminderService.bookingIds) 'cancel $id',
        for (final ReminderBooking booking in bookings)
          'schedule ${booking.id}',
      ]);
    });
  });

  group(
    'on macOS and Android the scheduler cancels then schedules as before',
    () {
      Future<void> expectUnchanged({
        required TargetPlatform platform,
        required _CallRecordingPlugin plugin,
        required AndroidScheduleMode mode,
      }) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        _answerTimezone('Europe/London');
        final List<int> ids = ReminderService.bookingIds;
        final LocalNotificationsReminderScheduler scheduler =
            LocalNotificationsReminderScheduler(plugin: plugin);
        final List<ReminderBooking> bookings = _fourBookings();

        await scheduler.schedule(bookings);

        expect(
          plugin.calls
              .map((_Call call) => '${call.kind.name} ${call.id}')
              .toList(),
          <String>[
            for (final int id in ids) 'cancel $id',
            for (final int id in ids.sublist(0, 4)) 'schedule $id',
          ],
        );
        final List<_Call> scheduled = plugin.calls
            .where((_Call call) => call.kind == _CallKind.schedule)
            .toList();
        expect(scheduled, hasLength(4));
        for (int index = 0; index < 4; index++) {
          final _Call call = scheduled[index];
          expect(call.id, ids[index]);
          expect(call.title, 'Field Notes');
          expect(call.body, bookings[index].body);
          expect(
            call.scheduledDate!.isAtSameMomentAs(bookings[index].at),
            isTrue,
          );
          final AndroidNotificationDetails? android = call.details!.android;
          expect(android, isNotNull);
          expect(android!.channelId, 'daily_reminder');
          expect(android.channelName, 'Daily reminder');
          expect(
            android.channelDescription,
            'Reminds you to write your field note for the day.',
          );
          expect(android.importance, Importance.high);
          expect(android.priority, Priority.high);
          final DarwinNotificationDetails? darwin = call.details!.macOS;
          expect(darwin, isNotNull);
          expect(darwin!.presentAlert, isNull);
          expect(darwin.presentBadge, isNull);
          expect(darwin.presentSound, isNull);
          expect(darwin.presentBanner, isNull);
          expect(darwin.presentList, isNull);
          expect(darwin.sound, isNull);
          expect(darwin.badgeNumber, isNull);
          expect(darwin.attachments, isNull);
          expect(darwin.subtitle, isNull);
          expect(darwin.threadIdentifier, isNull);
          expect(darwin.categoryIdentifier, isNull);
          expect(darwin.interruptionLevel, isNull);
          expect(darwin.criticalSoundVolume, isNull);
          expect(darwin.dismissIsolate, isNull);
          expect(call.mode, mode);
        }
      }

      test('on macOS the scheduler cancels then schedules as before', () async {
        await expectUnchanged(
          platform: TargetPlatform.macOS,
          plugin: _CallRecordingPlugin(macOS: _RecordingMacOSPlugin()),
          mode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      });

      test('on Android with exact alarms allowed the scheduler cancels then schedules as before', () async {
        await expectUnchanged(
          platform: TargetPlatform.android,
          plugin: _CallRecordingPlugin(
            android: _ExactAlarmAndroid(() async => true),
          ),
          mode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      });

      test('on Android without exact alarms the scheduler cancels then schedules as before', () async {
        await expectUnchanged(
          platform: TargetPlatform.android,
          plugin: _CallRecordingPlugin(
            android: _ExactAlarmAndroid(() async => false),
          ),
          mode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      });
    },
  );
}
