import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'start_sync_flow.dart';

const String deviceRemoveLabel = 'Remove';
const String devicesUnavailableMessage = "Can't reach your server right now.";
const String devicesLockedMessage =
    'Your devices show here once Field Notes can open its keys.';
const String removeDeviceMessage =
    'It stops syncing at once. What it already holds stays on it.';
const String removeDeviceFailedMessage =
    "That device couldn't be removed. Try again.";

String thisDeviceLabel(BuildContext context) =>
    syncFlowUsesSheet(context) ? 'This phone' : 'This Mac';

String lastSeenLabel(DateTime lastSeen, DateTime now) =>
    'Last seen ${relativeSyncTime(lastSeen, now)}';

String removeDevicePrompt(String name) => 'Remove $name?';

String deviceCountLabel(int count) =>
    count == 1 ? '1 device · add or remove' : '$count devices · add or remove';

Key deviceRemoveKey(String deviceId) =>
    ValueKey<String>('device-remove-$deviceId');

typedef DeviceFeedback = void Function(String message);

const String devicesTitle = 'Devices';

const double _detailGap = 2;
const double _stackedActionGap = 8;

class DeviceList extends ConsumerStatefulWidget {
  const DeviceList({super.key, required this.onFeedback, this.now});

  final DeviceFeedback onFeedback;
  final DateTime Function()? now;

  @override
  ConsumerState<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends ConsumerState<DeviceList> {
  String? _removing;

  Future<void> _remove(JournalDevice device) async {
    if (_removing != null) {
      return;
    }
    if (device.isThisDevice) {
      await showSyncDeleteAll(context);
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: removeDevicePrompt(device.name),
      message: removeDeviceMessage,
      confirmLabel: deviceRemoveLabel,
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _removing = device.deviceId);
    try {
      final DeviceService? devices = await ref.read(
        deviceServiceProvider.future,
      );
      if (devices == null) {
        widget.onFeedback(removeDeviceFailedMessage);
        return;
      }
      await devices.remove(device.deviceId);
      ref.invalidate(journalDevicesProvider);
    } on RelayException catch (error) {
      widget.onFeedback(setupMessageFor(error));
    } on KeyAccessException {
      widget.onFeedback(keysLockedFix);
    } on LastDeviceException {
      widget.onFeedback(removeDeviceFailedMessage);
    } on ArgumentError {
      ref.invalidate(journalDevicesProvider);
    } on StateError {
      widget.onFeedback(removeDeviceFailedMessage);
    } finally {
      if (mounted) {
        setState(() => _removing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JournalDevice>> devices = ref.watch(
      journalDevicesProvider,
    );
    return devices.when(
      skipLoadingOnRefresh: true,
      loading: () => const Align(
        alignment: Alignment.centerLeft,
        child: CrossHatchPlaceholder(width: 24, height: 24),
      ),
      error: (Object error, StackTrace stackTrace) => Text(
        error is KeyAccessException
            ? devicesLockedMessage
            : devicesUnavailableMessage,
        style: syncFlowHintStyle(context),
      ),
      data: (List<JournalDevice> devices) {
        final DateTime now = (widget.now ?? DateTime.now)().toUtc();
        final bool last = devices.length == 1;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int index = 0; index < devices.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 12),
              _DeviceRow(
                device: devices[index],
                detail: devices[index].isThisDevice
                    ? thisDeviceLabel(context)
                    : lastSeenLabel(devices[index].lastSeenAt, now),
                lastDevice: last,
                busy: _removing != null,
                onRemove: () => _remove(devices[index]),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.detail,
    required this.lastDevice,
    required this.busy,
    required this.onRemove,
  });

  final JournalDevice device;
  final String detail;
  final bool lastDevice;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (lastDevice && syncFlowUsesSheet(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MergeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(device.name, style: context.textStyles.labelSans),
                const SizedBox(height: _detailGap),
                Text(
                  detail,
                  style: context.textStyles.captionSans.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _stackedActionGap),
          _deleteEverywhere(context),
        ],
      );
    }
    return SettingsFieldRow(
      label: device.name,
      description: detail,
      control: lastDevice
          ? _deleteEverywhere(context)
          : StickerButton(
              key: deviceRemoveKey(device.deviceId),
              label: deviceRemoveLabel,
              variant: StickerButtonVariant.secondary,
              padTapTarget: true,
              onPressed: busy ? null : onRemove,
            ),
    );
  }

  Widget _deleteEverywhere(BuildContext context) => StickerButton(
    label: deleteJournalEverywhereLabel,
    variant: StickerButtonVariant.danger,
    padTapTarget: true,
    onPressed: busy ? null : () => showSyncDeleteAll(context),
  );
}
