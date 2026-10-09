import 'package:flutter/services.dart';

const MethodChannel _notificationSettingsChannel = MethodChannel(
  'field_notes/notification_settings',
);

abstract interface class NotificationSettingsOpener {
  Future<void> open();
}

class ChannelNotificationSettingsOpener implements NotificationSettingsOpener {
  const ChannelNotificationSettingsOpener({
    this.channel = _notificationSettingsChannel,
  });

  final MethodChannel channel;

  @override
  Future<void> open() => channel.invokeMethod<void>('open');
}

class ChannelNotificationStatus {
  const ChannelNotificationStatus({
    this.channel = _notificationSettingsChannel,
  });

  final MethodChannel channel;

  Future<String?> read() => channel.invokeMethod<String>('status');
}
