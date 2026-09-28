import 'package:flutter/services.dart';

abstract interface class NotificationSettingsOpener {
  Future<void> open();
}

class ChannelNotificationSettingsOpener implements NotificationSettingsOpener {
  const ChannelNotificationSettingsOpener({
    this.channel = const MethodChannel('field_notes/notification_settings'),
  });

  final MethodChannel channel;

  @override
  Future<void> open() => channel.invokeMethod<void>('open');
}
