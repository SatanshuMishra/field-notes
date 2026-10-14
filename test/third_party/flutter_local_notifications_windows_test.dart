import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart' show Utf8, calloc;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show
        ActiveNotification,
        FlutterLocalNotificationsWindows,
        NotificationsPluginBindings,
        PendingNotificationRequest,
        WindowsInitializationSettings;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

const WindowsInitializationSettings _settings = WindowsInitializationSettings(
  appName: 'Field Notes Test',
  appUserModelId: 'dev.satanshumishra.FieldNotesTest',
  guid: 'D6A0FDC5-EAD0-45F8-9024-F50F093EE5B3',
);

final List<String> _calls = <String>[];
bool _initResult = true;
bool _showResult = true;
bool _scheduleResult = true;
int _cancelResult = 0;
int _cancelAllResult = 0;
List<int>? _activeIds = <int>[];
List<int>? _pendingIds = <int>[];

final class _NativeStringMap extends Struct {
  external Pointer<Void> entries;

  @Int()
  external int size;
}

Pointer<Void> _createPlugin() {
  _calls.add('createPlugin');
  return Pointer<Void>.fromAddress(0x1000);
}

void _disposePlugin(Pointer<Void> plugin) {
  _calls.add('disposePlugin');
}

bool _init(
  Pointer<Void> plugin,
  Pointer<Utf8> appName,
  Pointer<Utf8> aumId,
  Pointer<Utf8> guid,
  Pointer<Utf8> iconPath,
  Pointer<Void> callback,
) {
  _calls.add('init');
  return _initResult;
}

bool _showNotification(
  Pointer<Void> plugin,
  int id,
  Pointer<Utf8> xml,
  _NativeStringMap bindings,
) {
  _calls.add('showNotification $id');
  return _showResult;
}

bool _scheduleNotification(
  Pointer<Void> plugin,
  int id,
  Pointer<Utf8> xml,
  int time,
) {
  _calls.add('scheduleNotification $id $time');
  return _scheduleResult;
}

int _cancelNotification(Pointer<Void> plugin, int id) {
  _calls.add('cancelNotification $id');
  return _cancelResult;
}

int _cancelAll(Pointer<Void> plugin) {
  _calls.add('cancelAll');
  return _cancelAllResult;
}

Pointer<Int> _details(List<int>? ids, Pointer<Int> size) {
  if (ids == null) {
    size.value = 0;
    return nullptr;
  }
  final Pointer<Int> array = calloc<Int>(ids.length);
  for (int index = 0; index < ids.length; index++) {
    array[index] = ids[index];
  }
  size.value = ids.length;
  return array;
}

Pointer<Int> _getActiveNotifications(Pointer<Void> plugin, Pointer<Int> size) {
  _calls.add('getActiveNotifications');
  return _details(_activeIds, size);
}

Pointer<Int> _getPendingNotifications(Pointer<Void> plugin, Pointer<Int> size) {
  _calls.add('getPendingNotifications');
  return _details(_pendingIds, size);
}

void _freeDetailsArray(Pointer<Int> array) {
  _calls.add('freeDetailsArray');
  calloc.free(array);
}

NotificationsPluginBindings _fakeBindings() {
  final Map<String, Pointer<NativeType>> natives =
      <String, Pointer<NativeType>>{
        'createPlugin': Pointer.fromFunction<Pointer<Void> Function()>(
          _createPlugin,
        ),
        'disposePlugin': Pointer.fromFunction<Void Function(Pointer<Void>)>(
          _disposePlugin,
        ),
        'init':
            Pointer.fromFunction<
              Bool Function(
                Pointer<Void>,
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Utf8>,
                Pointer<Void>,
              )
            >(_init, false),
        'showNotification':
            Pointer.fromFunction<
              Bool Function(Pointer<Void>, Int, Pointer<Utf8>, _NativeStringMap)
            >(_showNotification, false),
        'scheduleNotification':
            Pointer.fromFunction<
              Bool Function(Pointer<Void>, Int, Pointer<Utf8>, Int)
            >(_scheduleNotification, false),
        'cancelNotification':
            Pointer.fromFunction<UnsignedInt Function(Pointer<Void>, Int)>(
              _cancelNotification,
              2,
            ),
        'cancelAll': Pointer.fromFunction<UnsignedInt Function(Pointer<Void>)>(
          _cancelAll,
          2,
        ),
        'getActiveNotifications':
            Pointer.fromFunction<
              Pointer<Int> Function(Pointer<Void>, Pointer<Int>)
            >(_getActiveNotifications),
        'getPendingNotifications':
            Pointer.fromFunction<
              Pointer<Int> Function(Pointer<Void>, Pointer<Int>)
            >(_getPendingNotifications),
        'freeDetailsArray': Pointer.fromFunction<Void Function(Pointer<Int>)>(
          _freeDetailsArray,
        ),
      };
  Pointer<T> lookup<T extends NativeType>(String symbol) =>
      natives[symbol]!.cast<T>();
  return NotificationsPluginBindings.fromLookup(lookup);
}

Future<FlutterLocalNotificationsWindows> _initialisedPlugin() async {
  final FlutterLocalNotificationsWindows plugin =
      FlutterLocalNotificationsWindows.withBindings(_fakeBindings());
  expect(await plugin.initialize(settings: _settings), isTrue);
  addTearDown(plugin.dispose);
  return plugin;
}

Matcher _exceptionWith(String message) => isA<Exception>().having(
  (Exception exception) => exception.toString(),
  'message',
  message,
);

Matcher _notInitialised() => isA<StateError>().having(
  (StateError error) => error.message,
  'message',
  'Flutter Local Notifications must be initialized before use',
);

void main() {
  setUp(() {
    _calls.clear();
    _initResult = true;
    _showResult = true;
    _scheduleResult = true;
    _cancelResult = 0;
    _cancelAllResult = 0;
    _activeIds = <int>[];
    _pendingIds = <int>[];
  });

  test('the app uses the vendored Windows notifications plugin', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String lock = File('pubspec.lock').readAsStringSync();

    final RegExpMatch? overrides = RegExp(
      r'^dependency_overrides:\n((?:[ #].*\n|\n)*)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(overrides, isNotNull, reason: 'pubspec.yaml has no overrides');
    expect(
      overrides!.group(1),
      contains(
        '  flutter_local_notifications_windows:\n'
        '    path: third_party/flutter_local_notifications_windows\n',
      ),
    );
    expect(
      lock,
      contains(
        '  flutter_local_notifications_windows:\n'
        '    dependency: "direct overridden"\n'
        '    description:\n'
        '      path: "third_party/flutter_local_notifications_windows"\n'
        '      relative: true\n'
        '    source: path\n'
        '    version: "3.1.1"\n',
      ),
    );
  });

  test('native failures reach Dart as exceptions', () async {
    _showResult = false;
    _scheduleResult = false;
    _activeIds = null;
    _pendingIds = null;
    final FlutterLocalNotificationsWindows plugin = await _initialisedPlugin();

    await expectLater(
      plugin.zonedSchedule(
        id: 1001,
        title: 'Field Notes',
        body: "You haven't written today's field note yet.",
        scheduledDate: tz.TZDateTime(tz.UTC, 2035, 1, 1, 20),
      ),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not schedule'
          ' notification 1001',
        ),
      ),
    );
    await expectLater(
      plugin.zonedScheduleRawXml(
        id: 1002,
        xml: '<toast><visual><binding template="ToastGeneric"/></visual></toast>',
        scheduledDate: tz.TZDateTime(tz.UTC, 2035, 1, 1, 20),
      ),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not schedule'
          ' notification 1002',
        ),
      ),
    );
    await expectLater(
      plugin.show(
        id: 1003,
        title: 'Field Notes',
        body: "You haven't written today's field note yet.",
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      plugin.pendingNotificationRequests(),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not get pending'
          ' notifications',
        ),
      ),
    );
    await expectLater(
      plugin.getActiveNotifications(),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not get active'
          ' notifications',
        ),
      ),
    );
    expect(_calls, <String>[
      'createPlugin',
      'init',
      'scheduleNotification 1001 2051294400',
      'scheduleNotification 1002 2051294400',
      'showNotification 1003',
      'getPendingNotifications',
      'getActiveNotifications',
    ]);
  });

  test('a cancel fails only when a scheduled toast may remain', () async {
    final FlutterLocalNotificationsWindows plugin = await _initialisedPlugin();

    _cancelResult = 0;
    _cancelAllResult = 0;
    await expectLater(plugin.cancel(id: 1001), completes);
    await expectLater(plugin.cancelAll(), completes);

    _cancelResult = 1;
    _cancelAllResult = 1;
    await expectLater(plugin.cancel(id: 1002), completes);
    await expectLater(plugin.cancelAll(), completes);

    _cancelResult = 2;
    _cancelAllResult = 2;
    await expectLater(
      plugin.cancel(id: 1003),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not cancel'
          ' notification 1003: the scheduled notification lookup failed',
        ),
      ),
    );
    await expectLater(
      plugin.cancelAll(),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not cancel all'
          ' notifications: the scheduled notification lookup failed',
        ),
      ),
    );

    _cancelResult = 3;
    _cancelAllResult = 3;
    await expectLater(
      plugin.cancel(id: 1004),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not cancel'
          ' notification 1004: the scheduled notification removal failed',
        ),
      ),
    );
    await expectLater(
      plugin.cancelAll(),
      throwsA(
        _exceptionWith(
          'Exception: Flutter Local Notifications could not cancel all'
          ' notifications: the scheduled notification removal failed',
        ),
      ),
    );

    expect(_calls, <String>[
      'createPlugin',
      'init',
      'cancelNotification 1001',
      'cancelAll',
      'cancelNotification 1002',
      'cancelAll',
      'cancelNotification 1003',
      'cancelAll',
      'cancelNotification 1004',
      'cancelAll',
    ]);
  });

  test('native successes behave as before', () async {
    _activeIds = <int>[1001, 1002];
    _pendingIds = <int>[1003, 1004, 1005];
    final FlutterLocalNotificationsWindows plugin = await _initialisedPlugin();

    await expectLater(plugin.cancel(id: 1001), completes);
    await expectLater(plugin.cancelAll(), completes);
    await expectLater(
      plugin.zonedSchedule(
        id: 1001,
        title: 'Field Notes',
        body: "You haven't written today's field note yet.",
        scheduledDate: tz.TZDateTime(tz.UTC, 2035, 1, 1, 20),
      ),
      completes,
    );
    final List<PendingNotificationRequest> pending = await plugin
        .pendingNotificationRequests();
    final List<ActiveNotification> active = await plugin
        .getActiveNotifications();

    expect(
      pending.map((PendingNotificationRequest request) => request.id).toList(),
      <int>[1003, 1004, 1005],
    );
    expect(
      active.map((ActiveNotification notification) => notification.id).toList(),
      <int>[1001, 1002],
    );
    expect(_calls, <String>[
      'createPlugin',
      'init',
      'cancelNotification 1001',
      'cancelAll',
      'scheduleNotification 1001 2051294400',
      'getPendingNotifications',
      'freeDetailsArray',
      'getActiveNotifications',
      'freeDetailsArray',
    ]);
  });

  test('a failed initialise returns false', () async {
    _initResult = false;
    final FlutterLocalNotificationsWindows plugin =
        FlutterLocalNotificationsWindows.withBindings(_fakeBindings());

    expect(await plugin.initialize(settings: _settings), isFalse);

    await expectLater(plugin.cancel(id: 1001), throwsA(_notInitialised()));
    await expectLater(plugin.cancelAll(), throwsA(_notInitialised()));
    await expectLater(
      plugin.zonedSchedule(
        id: 1001,
        title: 'Field Notes',
        body: "You haven't written today's field note yet.",
        scheduledDate: tz.TZDateTime(tz.UTC, 2035, 1, 1, 20),
      ),
      throwsA(_notInitialised()),
    );
    await expectLater(
      plugin.show(
        id: 1001,
        title: 'Field Notes',
        body: "You haven't written today's field note yet.",
      ),
      throwsA(_notInitialised()),
    );
    await expectLater(
      plugin.pendingNotificationRequests(),
      throwsA(_notInitialised()),
    );
    await expectLater(
      plugin.getActiveNotifications(),
      throwsA(_notInitialised()),
    );
    expect(_calls, <String>['createPlugin', 'init']);
  });
}
