import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsSectionRequest extends Notifier<SettingsTab?> {
  @override
  SettingsTab? build() => null;

  void request(SettingsTab tab) => state = tab;

  void clear() => state = null;
}

final NotifierProvider<SettingsSectionRequest, SettingsTab?>
settingsSectionRequestProvider =
    NotifierProvider<SettingsSectionRequest, SettingsTab?>(
      SettingsSectionRequest.new,
    );
