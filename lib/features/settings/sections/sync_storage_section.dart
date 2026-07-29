import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/widgets.dart';

import '../sync/pairing_qr_placeholder.dart';
import '../sync/sync_shell_options.dart';

class SyncStorageSection extends StatefulWidget {
  const SyncStorageSection({super.key, required this.storageMode});

  final StorageMode storageMode;

  @override
  State<SyncStorageSection> createState() => _SyncStorageSectionState();
}

class _SyncStorageSectionState extends State<SyncStorageSection> {
  final TextEditingController _serverUrl = TextEditingController();
  final TextEditingController _accessToken = TextEditingController();
  final TextEditingController _recoveryPassphrase = TextEditingController();

  @override
  void dispose() {
    _serverUrl.dispose();
    _accessToken.dispose();
    _recoveryPassphrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SyncStorageChoice choice =
        SyncStorageChoice.fromStorageMode(widget.storageMode);
    return SettingsSection(
      title: 'Sync & storage',
      subtitle: 'Syncing arrives in a future update',
      children: <Widget>[
        SettingsFieldRow(
          label: 'Storage mode',
          description: 'Where your journal lives.',
          control: SettingsSegmented<SyncStorageChoice>(
            segments: <SettingsSegment<SyncStorageChoice>>[
              for (final SyncStorageChoice option in SyncStorageChoice.values)
                SettingsSegment<SyncStorageChoice>(
                  value: option,
                  label: option.label,
                ),
            ],
            value: choice,
            onChanged: null,
            enabled: false,
          ),
        ),
        SettingsConditional(
          visible: choice == SyncStorageChoice.onDevice,
          child: Text(
            'Entries are stored only on this device. Nothing is uploaded '
            'and there is no syncing across devices.',
            style: TypographyTokens.captionSans,
          ),
        ),
        SettingsFieldRow(
          label: 'Server URL',
          description: 'Where your entries would sync.',
          control: SettingsTextField(
            controller: _serverUrl,
            hintText: 'https://journal.example.com',
            enabled: false,
          ),
        ),
        SettingsFieldRow(
          label: 'Access token',
          description: 'Authorises this device with your server.',
          control: SettingsSecretField(
            controller: _accessToken,
            hintText: 'Paste your access token',
            enabled: false,
          ),
        ),
        SettingsFieldRow(
          label: 'Sync frequency',
          description: 'How often changes would travel.',
          control: SettingsSelect<SyncFrequency>(
            options: <SettingsSelectOption<SyncFrequency>>[
              for (final SyncFrequency option in SyncFrequency.values)
                SettingsSelectOption<SyncFrequency>(
                  value: option,
                  label: option.label,
                ),
            ],
            value: SyncFrequency.automatic,
            onChanged: null,
            enabled: false,
          ),
        ),
        SettingsFieldRow(
          label: 'Recovery passphrase',
          description: 'Would unlock your encrypted journal elsewhere.',
          control: SettingsSecretField(
            controller: _recoveryPassphrase,
            hintText: 'Enter a recovery passphrase',
            enabled: false,
          ),
        ),
        const SettingsFieldRow(
          label: 'Pair a device',
          description: 'Would be scanned by your second device.',
          control: PairingQrPlaceholder(),
        ),
        const SettingsFieldRow(
          label: 'Connection',
          description: 'Sync is not available yet.',
          control: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SettingsStatusPill(label: 'Not connected'),
              StickerButton(
                label: 'Test connection',
                onPressed: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
