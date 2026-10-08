import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/data/media/device_storage.dart';
import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:field_notes/features/reminders/notification_settings_opener.dart';
import 'package:field_notes/features/sync/ui/camera_settings_opener.dart';

const String _runner = 'windows/runner';

String _source(String name) {
  final File file = File('$_runner/$name');
  expect(file.existsSync(), isTrue, reason: '$_runner/$name is missing');
  return file.readAsStringSync();
}

String _function(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature must exist');
  final int end = source.indexOf('\n}\n', start);
  expect(end, isNot(-1), reason: '$signature must end');
  return source.substring(start, end);
}

Future<MethodCall> _callMade(
  MethodChannel channel,
  Future<void> Function() call, {
  Object? reply,
}) async {
  final List<MethodCall> calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall made) async {
        calls.add(made);
        return reply;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  await call();
  expect(calls, hasLength(1));
  return calls.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Windows services', () {
    test('Windows opens its notification and camera settings pages', () async {
      final String source = _source('system_channels.cpp');

      const ChannelNotificationSettingsOpener opener =
          ChannelNotificationSettingsOpener();
      final MethodCall open = await _callMade(opener.channel, opener.open);
      expect(source, contains('"${opener.channel.name}"'));
      expect(source, contains('kOpenMethod[] = "${open.method}"'));
      expect(
        source,
        contains('kNotificationSettingsUri[] = L"ms-settings:notifications"'),
      );
      expect(
        source,
        contains(
          '::ShellExecuteW(nullptr, L"open", uri, nullptr, nullptr, '
          'SW_SHOWNORMAL)',
        ),
      );
      expect(source, contains('reinterpret_cast<INT_PTR>(opened) > 32'));
      expect(
        _function(source, 'void HandleNotificationSettings('),
        contains(
          'result->Error("unavailable", "Windows Settings did not open.");',
        ),
      );

      final MethodCall camera = await _callMade(
        cameraSettingsChannel,
        openCameraPrivacySettings,
      );
      expect(source, contains('"${cameraSettingsChannel.name}"'));
      expect(
        source,
        contains('kOpenCameraSettingsMethod[] = "${camera.method}"'),
      );
      expect(
        source,
        contains('kCameraPrivacySettingsUri[] = L"ms-settings:privacy-webcam"'),
      );
      expect(
        _function(source, 'void HandleCameraSettings('),
        contains('OpenSettingsPage(kCameraPrivacySettingsUri)'),
      );

      expect(
        _source('flutter_window.cpp'),
        contains('std::make_unique<SystemChannels>(messenger)'),
      );
    });

    test(
      'Windows reports free disk space to the device storage channel',
      () async {
        final String source = _source('system_channels.cpp');
        const MethodChannel channel = MethodChannel(deviceStorageChannelName);
        final MethodCall freeBytes = await _callMade(
          channel,
          () => PlatformDeviceStorage(channel).freeBytes(Directory('notes')),
          reply: 1,
        );
        expect(freeBytes.method, freeBytesMethod);
        final Map<Object?, Object?> arguments =
            freeBytes.arguments as Map<Object?, Object?>;

        expect(source, contains('"$deviceStorageChannelName"'));
        expect(source, contains('kFreeBytesMethod[] = "$freeBytesMethod"'));
        expect(
          source,
          contains('kPathArgument[] = "${arguments.keys.single}"'),
        );
        expect(
          _function(source, 'void HandleDeviceStorage('),
          contains('result->Error("bad_arguments", "A path is required");'),
        );

        final String nearest = _function(
          source,
          'std::wstring NearestExistingFolder(',
        );
        expect(nearest, contains('::GetFileAttributesW(candidate.c_str())'));
        expect(nearest, contains('FILE_ATTRIBUTE_DIRECTORY'));
        expect(nearest, contains('candidate = ParentFolder(candidate)'));

        final String free = _function(
          source,
          'std::optional<int64_t> FreeBytesNear(',
        );
        expect(free, contains('NearestExistingFolder(Utf16FromUtf8(path))'));
        expect(
          free,
          contains(
            '::GetDiskFreeSpaceExW(folder.c_str(), '
            '&free_bytes_available_to_caller,',
          ),
        );
        expect(
          free,
          contains(
            'static_cast<int64_t>(free_bytes_available_to_caller.QuadPart)',
          ),
        );
        expect(
          _source('utils.cpp'),
          contains('::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS'),
        );
      },
    );

    test(
      'Windows answers the notification permission from the toast setting',
      () async {
        final String source = _source('system_channels.cpp');

        const ChannelNotificationStatus status = ChannelNotificationStatus();
        final MethodCall read = await _callMade(
          status.channel,
          status.read,
          reply: 'enabled',
        );
        expect(source, contains('"${status.channel.name}"'));
        expect(source, contains('kStatusMethod[] = "${read.method}"'));
        expect(
          _source('system_channels.h'),
          contains('kAppUserModelId[] = L"$windowsAppUserModelId";'),
        );

        final String toasts = _function(source, 'bool ToastsEnabled()');
        expect(toasts, contains('::RoGetActivationFactory('));
        expect(
          toasts,
          contains(
            'RuntimeClass_Windows_UI_Notifications_ToastNotificationManager',
          ),
        );
        expect(toasts, contains('ComPtr<IToastNotificationManagerStatics>'));
        expect(
          toasts,
          matches(
            RegExp(
              r'manager->CreateToastNotifierWithId\(\s*'
              r'HStringReference\(kAppUserModelId\)\.Get\(\), &notifier\)',
            ),
          ),
        );
        expect(toasts, contains('notifier->get_Setting(&setting)'));
        expect(
          toasts,
          contains(
            'return setting == '
            'NotificationSetting::NotificationSetting_Enabled;',
          ),
        );
        expect(
          'return true;'.allMatches(toasts),
          hasLength(3),
          reason: 'every failed call answers enabled',
        );
        expect(
          _function(source, 'void HandleNotificationSettings('),
          contains('ToastsEnabled() ? "enabled" : "disabled"'),
        );

        expect(source, contains('#include <windows.ui.notifications.h>'));
        expect(source, contains('#include <wrl/client.h>'));
        expect(source, contains('#include <wrl/wrappers/corewrappers.h>'));
        expect(source, isNot(contains('winrt::')));
        expect(source, isNot(matches(RegExp(r'\b(try|catch|throw)\b'))));
        expect(_source('CMakeLists.txt'), contains('"runtimeobject.lib"'));
      },
    );
  });
}
