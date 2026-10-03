import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _timezoneChannel = MethodChannel('flutter_timezone');

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
      T extends FlutterLocalNotificationsPlatform>() {
    final _RecordingMacOSPlugin implementation = macOS;
    return implementation is T ? implementation as T : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    addTearDown(() => messenger.setMockMethodCallHandler(_timezoneChannel, null));
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
    addTearDown(() => messenger.setMockMethodCallHandler(_timezoneChannel, null));
    final _RecordingPlugin plugin = _RecordingPlugin(_RecordingMacOSPlugin());
    final LocalNotificationsReminderScheduler scheduler =
        LocalNotificationsReminderScheduler(plugin: plugin);

    await scheduler.permissionStatus();

    expect(
      plugin.initializations.single.android?.defaultIcon,
      '@drawable/ic_stat_peony',
    );
  });
}
