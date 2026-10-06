import 'dart:async';

import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/erase/device_unlink_service.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/sync/ui/add_device_sheet.dart';
import 'package:field_notes/features/sync/ui/device_list.dart';
import 'package:field_notes/features/sync/ui/join_journal_flow.dart';
import 'package:field_notes/features/sync/ui/restore_flow.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_feedback.dart';
import '../widgets/delete_all_dialog.dart';

const String syncSectionTitle = 'Sync & storage';

const String syncOffIntroMac =
    'Your journal is stored only on this Mac. Turn on sync to keep it on your '
    'other devices too. Everything is encrypted before it leaves this Mac.';
const String syncOffIntroPhone =
    'Your journal is only on this phone. Sync keeps it on your other devices, '
    'encrypted.';
const String startSyncCaptionMac =
    'First device. Needs your server address and an invite code.';
const String startSyncCaptionPhone =
    'First device. Server address and invite code.';
const String joinJournalCaptionMac =
    'You already sync on another device. Type the 8 words it shows.';
const String joinJournalCaptionPhone = 'Scan the code on your other device.';
const String restoreLabelTitle = 'Restore with recovery phrase';
const String restoreCaptionMac = 'You lost every device. Use your 12 words.';
const String restoreCaptionPhone = 'Use your 12 words.';
const double _actionRowMinHeight = 48;
const double _actionChevronSize = 20;

const String syncStatusTitle = 'Status';
const String syncNowLabel = 'Sync now';
const String pauseSyncLabel = 'Pause sync';
const String pauseSyncCaption =
    'Stops sending and receiving until you switch it back';
const String serverAddressCaption = 'Every device follows when you change it';
const String changeLabel = 'Change';
const String yourDevicesLabel = 'Your devices';
const String addDeviceCaption = 'Show a code to scan';
const String showCodeLabel = 'Show code';
const String keepMediaMacLabel = 'Keep all media on this device';
const String keepMediaMacCaption =
    'Download every photo, voice note and video in the background. On for '
    'Macs.';
const String keepMediaPhoneLabel = 'Keep all media on this phone';
const String keepMediaPhoneCaption = 'Off: videos download when you open them';
const String mobileDataLabel = 'Allow mobile data for media';
const String mobileDataCaption = 'Off: full videos move on Wi-Fi only';
const String devicesLabel = 'Devices';
const String devicesFallbackCaption = 'Add or remove';
const String manageLabel = 'Manage';
const String backgroundUploadsLabel = 'Background uploads';
const String batteryUnrestrictedLabel = 'Battery: Unrestricted';
const String batteryOptimisedLabel = 'Battery: Optimised';
const String changeAddressTitle = 'Change server address';
const String newServerAddressLabel = 'New server address';
const String mediaSettingFailedMessage = 'Could not save your media setting.';
const String syncActionFailedMessage = "That didn't work. Try again.";

String lastChangeSentLabel(DateTime at, DateTime now) =>
    'Last change sent ${relativeSyncTime(at, now)}';

Color syncStatusTone(SyncStatus status, FieldNotesColors colors) =>
    switch (status) {
      SyncedStatus() => colors.sage,
      WaitingStatus() || UploadingStatus() => colors.accentInk,
      AttentionStatus() => colors.dangerInk,
      OfflineStatus() || PausedStatus() => colors.muted,
    };

class SyncClockRefresh extends StatefulWidget {
  const SyncClockRefresh({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<SyncClockRefresh> createState() => _SyncClockRefreshState();
}

class _SyncClockRefreshState extends State<SyncClockRefresh> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (Timer _) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class SyncStorageSection extends ConsumerStatefulWidget {
  const SyncStorageSection({
    super.key,
    required this.settings,
    required this.onFeedback,
  });

  final AppSettings settings;
  final SettingsFeedbackSink onFeedback;

  @override
  ConsumerState<SyncStorageSection> createState() => _SyncStorageSectionState();
}

class _SyncStorageSectionState extends ConsumerState<SyncStorageSection> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _lastSent;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(batteryExemptProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _phone => syncFlowUsesSheet(context);

  @override
  Widget build(BuildContext context) {
    final bool? syncOn = ref.watch(syncEnabledProvider).value;
    if (syncOn == null) {
      return const SettingsSection(
        title: syncSectionTitle,
        children: <Widget>[],
      );
    }
    if (!syncOn) {
      return _syncOff();
    }
    ref.listen<AsyncValue<SyncStatus?>>(syncStatusProvider, (
      AsyncValue<SyncStatus?>? _,
      AsyncValue<SyncStatus?> next,
    ) {
      final SyncStatus? status = next.value;
      if (status is SyncedStatus) {
        setState(() => _lastSent = status.at);
      }
    });
    final SyncStatus? status = ref.watch(syncStatusProvider).value;
    final String? address = ref.watch(relayAddressProvider).value;
    return SyncClockRefresh(
      builder: (BuildContext context) =>
          _phone ? _phoneOn(status, address) : _macOn(status, address),
    );
  }

  Widget _syncOff() {
    final bool phone = _phone;
    return SettingsSection(
      title: syncSectionTitle,
      children: <Widget>[
        Text(
          phone ? syncOffIntroPhone : syncOffIntroMac,
          style: context.textStyles.captionSans,
        ),
        SyncActionRow(
          label: startSyncTitle,
          description: phone ? startSyncCaptionPhone : startSyncCaptionMac,
          onPressed: () => startSync(context, ref),
        ),
        SyncActionRow(
          label: joinTitle,
          description: phone ? joinJournalCaptionPhone : joinJournalCaptionMac,
          onPressed: () => joinJournal(context, ref),
        ),
        SyncActionRow(
          label: restoreLabelTitle,
          description: phone ? restoreCaptionPhone : restoreCaptionMac,
          onPressed: () => restoreJournal(context, ref),
        ),
      ],
    );
  }

  Widget _macOn(SyncStatus? status, String? address) {
    final DateTime now = DateTime.now().toUtc();
    final DateTime? sent = status is SyncedStatus ? status.at : _lastSent;
    return SettingsSection(
      title: syncSectionTitle,
      children: <Widget>[
        SettingsFieldRow(
          label: syncStatusTitle,
          description: sent == null ? null : lastChangeSentLabel(sent, now),
          control: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (status != null) _statusPill(status, now),
              _syncNowButton(),
            ],
          ),
        ),
        ..._fixRows(status),
        _pauseRow(status),
        SettingsFieldRow(
          label: serverAddressLabel,
          description: serverAddressCaption,
          control: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (address != null)
                Text(address, style: context.textStyles.bodySans),
              _changeButton(),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                yourDevicesLabel,
                style: context.textStyles.labelSans,
              ),
            ),
            const SizedBox(height: 8),
            DeviceList(onFeedback: widget.onFeedback),
          ],
        ),
        SettingsFieldRow(
          label: addDeviceTitle,
          description: addDeviceCaption,
          control: StickerButton(
            label: showCodeLabel,
            variant: StickerButtonVariant.secondary,
            padTapTarget: true,
            onPressed: () => showAddDeviceSheet(context),
          ),
        ),
        _keepMediaRow(label: keepMediaMacLabel, caption: keepMediaMacCaption),
      ],
    );
  }

  Widget _phoneOn(SyncStatus? status, String? address) {
    final DateTime now = DateTime.now().toUtc();
    final bool android = syncFlowOnAndroid(context);
    final List<JournalDevice>? devices = ref
        .watch(journalDevicesProvider)
        .value;
    return SettingsSection(
      title: syncSectionTitle,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (status != null) _statusPill(status, now),
                  if (address != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(address, style: syncFlowHintStyle(context)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _syncNowButton(),
          ],
        ),
        ..._fixRows(status),
        _pauseRow(status),
        _keepMediaRow(
          label: keepMediaPhoneLabel,
          caption: keepMediaPhoneCaption,
        ),
        if (android)
          SettingsFieldRow(
            label: mobileDataLabel,
            description: mobileDataCaption,
            control: SettingsToggle(
              semanticLabel: mobileDataLabel,
              value: widget.settings.allowMobileDataForMedia,
              onChanged: (bool value) => _saveMedia(
                () => ref
                    .read(settingsRepositoryProvider)
                    .setAllowMobileDataForMedia(value),
              ),
            ),
          ),
        SettingsFieldRow(
          label: devicesLabel,
          description: devices == null
              ? devicesFallbackCaption
              : deviceCountLabel(devices.length),
          control: StickerButton(
            label: manageLabel,
            variant: StickerButtonVariant.secondary,
            padTapTarget: true,
            onPressed: () =>
                showDeviceListSheet(context, onFeedback: widget.onFeedback),
          ),
        ),
        SettingsFieldRow(
          label: serverAddressLabel,
          description: address,
          control: _changeButton(),
        ),
        if (android) _backgroundUploadsRow(),
      ],
    );
  }

  Widget _statusPill(SyncStatus status, DateTime now) => SettingsStatusPill(
    label: status.label(now),
    dotColor: syncStatusTone(status, context.colors),
  );

  Widget _syncNowButton() => StickerButton(
    label: syncNowLabel,
    variant: StickerButtonVariant.secondary,
    padTapTarget: true,
    onPressed: () =>
        _engineAction(() => ref.read(syncEngineProvider).syncNow()),
  );

  Widget _changeButton() => StickerButton(
    label: changeLabel,
    variant: StickerButtonVariant.secondary,
    padTapTarget: true,
    onPressed: () => showSyncFlow<void>(
      context,
      builder: (BuildContext flowContext) => const ChangeServerAddressFlow(),
    ),
  );

  Widget _pauseRow(SyncStatus? status) => SettingsFieldRow(
    label: pauseSyncLabel,
    description: pauseSyncCaption,
    control: SettingsToggle(
      semanticLabel: pauseSyncLabel,
      value: status is PausedStatus,
      onChanged: (bool value) =>
          _engineAction(() => ref.read(syncEngineProvider).pause(value)),
    ),
  );

  Widget _keepMediaRow({required String label, required String caption}) =>
      SettingsFieldRow(
        label: label,
        description: caption,
        control: SettingsToggle(
          semanticLabel: label,
          value: widget.settings.keepAllMediaOnDevice,
          onChanged: (bool value) => _saveMedia(
            () => ref
                .read(settingsRepositoryProvider)
                .setKeepAllMediaOnDevice(value),
          ),
        ),
      );

  List<Widget> _fixRows(SyncStatus? status) {
    if (status is! AttentionStatus) {
      return const <Widget>[];
    }
    final String? fix = status.fix;
    if (fix == null) {
      return const <Widget>[];
    }
    if (status.reason == AttentionReason.removed) {
      return <Widget>[
        SettingsFieldRow(
          label: fix,
          control: StickerButton(
            label: removeFromThisDeviceLabel,
            variant: StickerButtonVariant.danger,
            padTapTarget: true,
            onPressed: _removeThisDevice,
          ),
          labelColor: context.colors.dangerInk,
        ),
      ];
    }
    return <Widget>[
      Text(
        fix,
        style: context.textStyles.bodySans.copyWith(
          color: context.colors.dangerInk,
        ),
      ),
    ];
  }

  Widget _backgroundUploadsRow() {
    final bool? exempt = ref.watch(batteryExemptProvider).value;
    return SettingsFieldRow(
      label: backgroundUploadsLabel,
      description: switch (exempt) {
        true => batteryUnrestrictedLabel,
        false => batteryOptimisedLabel,
        null => null,
      },
      control: exempt == false
          ? StickerButton(
              label: openBatterySettingsLabel,
              variant: StickerButtonVariant.secondary,
              padTapTarget: true,
              onPressed: () => showBackgroundUploadsSheet(context, ref),
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _engineAction(Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (error) {
      debugPrint('Sync action failed: $error');
      widget.onFeedback(syncActionFailedMessage);
    }
  }

  Future<void> _saveMedia(Future<void> Function() write) async {
    try {
      await write();
    } on Exception catch (error) {
      debugPrint('Media setting failed: $error');
      widget.onFeedback(mediaSettingFailedMessage);
    }
  }

  Future<void> _removeThisDevice() async {
    try {
      final DeviceUnlinkService unlink = await ref.read(
        deviceUnlinkServiceProvider.future,
      );
      await unlink.removeThisDevice();
    } on DeviceUnlinkException catch (error) {
      widget.onFeedback(error.message);
    }
  }
}

class SyncActionRow extends StatelessWidget {
  const SyncActionRow({
    super.key,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final String label;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      button: true,
      enabled: true,
      label: label,
      hint: description,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          includeFocusSemantics: false,
          borderRadius: Shapes.buttonBorderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _actionRowMinHeight),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label, style: context.textStyles.labelSans),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: context.textStyles.captionSans.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right,
                  size: _actionChevronSize,
                  color: colors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChangeServerAddressFlow extends ConsumerStatefulWidget {
  const ChangeServerAddressFlow({super.key});

  @override
  ConsumerState<ChangeServerAddressFlow> createState() =>
      _ChangeServerAddressFlowState();
}

class _ChangeServerAddressFlowState
    extends ConsumerState<ChangeServerAddressFlow> {
  final TextEditingController _address = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_busy) {
      return;
    }
    final Uri? address = parseServerAddress(_address.text);
    if (address == null) {
      setState(() => _error = unreachableMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? failure = await ref
        .read(serverAddressProvider)
        .changeServerAddress(address);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    return PopScope<void>(
      canPop: !_busy,
      child: SyncFlowFrame(
        title: changeAddressTitle,
        message: '$serverAddressCaption.',
        content: <Widget>[
          SyncFlowField(
            label: newServerAddressLabel,
            controller: _address,
            hintText: serverAddressHint,
            keyboardType: TextInputType.url,
            enabled: !_busy,
          ),
          if (error != null) SyncFlowError(message: error),
        ],
        actions: <SyncFlowAction>[
          SyncFlowAction(
            label: syncCancelLabel,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          SyncFlowAction(
            label: changeLabel,
            primary: true,
            onPressed: _busy ? null : _change,
          ),
        ],
      ),
    );
  }
}
