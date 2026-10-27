import 'dart:async';

import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/erase/device_unlink_service.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/interaction/pressable.dart';
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
import '../widgets/devices_dialog.dart';

const String turnOnSyncGroupLabel = 'turn on sync';
const String syncGroupLabel = 'sync';
const String serverAndDevicesGroupLabel = 'server & devices';
const String mediaGroupLabel = 'media';

const String syncOffIntroMac =
    'Your journal is stored only on this Mac. Turn on sync to keep it on your '
    'other devices too. Everything is encrypted before it leaves this Mac.';
const String syncOffIntroWindows =
    'Your journal is stored only on this PC. Turn on sync to keep it on your '
    'other devices too. Everything is encrypted before it leaves this PC.';
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
const double _statusDotSize = 8;
const double _androidMinTarget = 48;
const double _macosMinTarget = 28;
const double _windowsMinTarget = 40;

const String syncNowLabel = 'Sync now';
const String pauseSyncLabel = 'Pause sync';
const String pauseSyncCaption =
    'Stops sending and receiving until you switch it back';
const String serverAddressCaption = 'Every device follows when you change it';
const String changeLabel = 'Change';
const String addDeviceCaption = 'Show a code to scan';
const String showCodeLabel = 'Show code';
const String keepMediaMacLabel = 'Keep all media on this device';
const String keepMediaMacCaption =
    'Download every photo, voice note and video in the background. On for '
    'Macs.';
const String keepMediaWindowsCaption =
    'Download every photo, voice note and video in the background. On for '
    'PCs.';

String syncOffIntroDesktop(TargetPlatform platform) =>
    platform == TargetPlatform.windows ? syncOffIntroWindows : syncOffIntroMac;

String keepMediaCaptionDesktop(TargetPlatform platform) =>
    platform == TargetPlatform.windows
    ? keepMediaWindowsCaption
    : keepMediaMacCaption;

const String keepMediaPhoneLabel = 'Keep all media on this phone';
const String keepMediaPhoneCaption = 'Off: videos download when you open them';
const String mobileDataLabel = 'Allow mobile data for media';
const String mobileDataCaption = 'Off: full videos move on Wi-Fi only';
const String devicesLabel = 'Devices';
const String devicesFallbackCaption = 'Add or remove';
const String manageLabel = 'Manage';
const String manageDevicesLabel = 'Manage devices';
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
    this.onManageDevices,
  });

  final AppSettings settings;
  final SettingsFeedbackSink onFeedback;
  final VoidCallback? onManageDevices;

  @override
  ConsumerState<SyncStorageSection> createState() => _SyncStorageSectionState();
}

class _SyncStorageSectionState extends ConsumerState<SyncStorageSection> {
  late final AppLifecycleListener _lifecycle;
  final FocusNode _manageDevicesFocus = FocusNode(
    debugLabel: manageDevicesLabel,
  );
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
    _manageDevicesFocus.dispose();
    super.dispose();
  }

  bool get _phone => syncFlowUsesSheet(context);

  @override
  Widget build(BuildContext context) {
    final bool? syncOn = ref.watch(syncEnabledProvider).value;
    if (syncOn == null) {
      return const SettingsSection.grouped(groups: <SettingsGroup>[]);
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
          _phone ? _phoneOn(status, address) : _desktopOn(status, address),
    );
  }

  Widget _syncOff() {
    final bool phone = _phone;
    return SettingsSection.grouped(
      groups: <SettingsGroup>[
        SettingsGroup(
          label: turnOnSyncGroupLabel,
          rows: <Widget>[
            Text(
              phone
                  ? syncOffIntroPhone
                  : syncOffIntroDesktop(Theme.of(context).platform),
              style: context.textStyles.captionSans,
            ),
            SyncActionRow(
              label: startSyncTitle,
              description: phone ? startSyncCaptionPhone : startSyncCaptionMac,
              onPressed: () => startSync(context, ref),
            ),
            SyncActionRow(
              label: joinTitle,
              description: phone
                  ? joinJournalCaptionPhone
                  : joinJournalCaptionMac,
              onPressed: () => joinJournal(context, ref),
            ),
            SyncActionRow(
              label: restoreLabelTitle,
              description: phone ? restoreCaptionPhone : restoreCaptionMac,
              onPressed: () => restoreJournal(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Widget _desktopOn(SyncStatus? status, String? address) {
    final DateTime now = DateTime.now().toUtc();
    final DateTime? sent = status is SyncedStatus ? status.at : _lastSent;
    final List<JournalDevice>? devices = ref
        .watch(journalDevicesProvider)
        .value;
    return SettingsSection.grouped(
      groups: <SettingsGroup>[
        SettingsGroup(
          label: syncGroupLabel,
          rows: <Widget>[
            if (status != null)
              SettingsFieldRow(
                label: status.label(now),
                leading: _statusDot(status),
                description: sent == null
                    ? null
                    : lastChangeSentLabel(sent, now),
                control: status is PausedStatus
                    ? const SizedBox.shrink()
                    : _syncNowButton(),
              ),
            ..._fixRows(status),
            _pauseRow(status),
          ],
        ),
        SettingsGroup(
          label: serverAndDevicesGroupLabel,
          rows: <Widget>[
            SettingsFieldRow(
              label: serverAddressLabel,
              description: address ?? serverAddressCaption,
              control: _changeButton(),
            ),
            SettingsFieldRow(
              label: addDeviceTitle,
              description: addDeviceCaption,
              control: _MinimumTarget(
                child: SettingsActionButton(
                  label: showCodeLabel,
                  onPressed: () => showAddDeviceSheet(context),
                ),
              ),
            ),
            Focus(
              focusNode: _manageDevicesFocus,
              canRequestFocus: false,
              skipTraversal: true,
              child: _MinimumTarget(
                child: SettingsFieldRow(
                  label: manageDevicesLabel,
                  description: devices == null
                      ? devicesFallbackCaption
                      : deviceCountLabel(devices.length),
                  control: ChevronGlyph(
                    pointsBack: false,
                    color: context.colors.muted,
                  ),
                  onPressed: _openDevices,
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: mediaGroupLabel,
          rows: <Widget>[
            _keepMediaRow(
              label: keepMediaMacLabel,
              caption: keepMediaCaptionDesktop(Theme.of(context).platform),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openDevices() async {
    await showDevicesDialog(context, onFeedback: widget.onFeedback);
    if (!mounted) {
      return;
    }
    _manageDevicesFocus.descendants
        .where((FocusNode node) => node.canRequestFocus)
        .firstOrNull
        ?.requestFocus();
  }

  Widget _phoneOn(SyncStatus? status, String? address) {
    final DateTime now = DateTime.now().toUtc();
    final bool android = syncFlowOnAndroid(context);
    final List<JournalDevice>? devices = ref
        .watch(journalDevicesProvider)
        .value;
    final VoidCallback? onManageDevices = widget.onManageDevices;
    return SettingsSection.grouped(
      groups: <SettingsGroup>[
        SettingsGroup(
          label: syncGroupLabel,
          rows: <Widget>[
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
                if (status is! PausedStatus) ...<Widget>[
                  const SizedBox(width: 12),
                  _syncNowButton(),
                ],
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
            if (onManageDevices != null)
              SettingsFieldRow(
                label: devicesLabel,
                description: devices == null
                    ? devicesFallbackCaption
                    : deviceCountLabel(devices.length),
                control: StickerButton(
                  label: manageLabel,
                  variant: StickerButtonVariant.secondary,
                  padTapTarget: true,
                  onPressed: onManageDevices,
                ),
              ),
            SettingsFieldRow(
              label: serverAddressLabel,
              description: address,
              control: _changeButton(),
            ),
            if (android) _backgroundUploadsRow(),
          ],
        ),
      ],
    );
  }

  Widget _statusPill(SyncStatus status, DateTime now) => SettingsStatusPill(
    label: status.label(now),
    dotColor: syncStatusTone(status, context.colors),
  );

  Widget _statusDot(SyncStatus status) => DecoratedBox(
    decoration: BoxDecoration(
      color: syncStatusTone(status, context.colors),
      shape: BoxShape.circle,
    ),
    child: const SizedBox.square(dimension: _statusDotSize),
  );

  Widget _syncNowButton() => _MinimumTarget(
    child: SettingsActionButton(
      label: syncNowLabel,
      onPressed: () =>
          _engineAction(() => ref.read(syncEngineProvider).syncNow()),
    ),
  );

  Widget _changeButton() => _MinimumTarget(
    child: SettingsActionButton(
      label: changeLabel,
      onPressed: () => showSyncFlow<void>(
        context,
        builder: (BuildContext flowContext) => const ChangeServerAddressFlow(),
      ),
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
    return Pressable(
      includeFocusSemantics: false,
      label: label,
      hint: description,
      onPressed: onPressed,
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
      setState(() => _error = serverAddressRefusal(_address.text));
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

class _MinimumTarget extends StatelessWidget {
  const _MinimumTarget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double target = switch (Theme.of(context).platform) {
      TargetPlatform.macOS => _macosMinTarget,
      TargetPlatform.windows => _windowsMinTarget,
      _ => _androidMinTarget,
    };
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: target, minHeight: target),
      child: child,
    );
  }
}
