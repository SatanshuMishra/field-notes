const String assembledUploadStatus = 'assembled';

const String unreachableFix =
    "Your changes are safe here and will go up when it's back.";
const String clockFix = 'Set the date and time automatically to keep syncing.';
const String updateAppFix = 'Please update Field Notes to keep syncing.';
const String removedFix = 'This device was removed from your journal.';
const String keysLockedFix =
    'Allow Field Notes to use its keys when asked, then tap Sync now. '
    'Your notes are safe on this device.';
const String problemFix =
    "Your notes are safe on this device. Field Notes keeps trying.";

enum AttentionReason {
  unreachable("can't reach your server", unreachableFix),
  newServerUnreachable("can't reach your new server", unreachableFix),
  keysLocked("can't open your sync keys", keysLockedFix),
  clock("this device's clock", clockFix),
  updateApp('update Field Notes', updateAppFix),
  removed('this device was removed', removedFix),
  storageFull('your server is full', null),
  problem('sync hit a problem', problemFix);

  const AttentionReason(this.label, this.fix);

  final String label;
  final String? fix;
}

String relativeSyncTime(DateTime at, DateTime now) {
  final Duration since = now.difference(at);
  if (since.inMinutes < 1) {
    return 'just now';
  }
  if (since.inHours < 1) {
    return _ago(since.inMinutes, 'minute');
  }
  if (since.inDays < 1) {
    return _ago(since.inHours, 'hour');
  }
  return _ago(since.inDays, 'day');
}

String _ago(int count, String unit) =>
    count == 1 ? '1 $unit ago' : '$count ${unit}s ago';

sealed class SyncStatus {
  const SyncStatus();

  String label(DateTime now);
}

final class SyncedStatus extends SyncStatus {
  const SyncedStatus(this.at);

  final DateTime at;

  @override
  String label(DateTime now) => 'Synced · ${relativeSyncTime(at, now)}';

  @override
  bool operator ==(Object other) => other is SyncedStatus && other.at == at;

  @override
  int get hashCode => at.hashCode;
}

final class WaitingStatus extends SyncStatus {
  const WaitingStatus(this.changes);

  final int changes;

  @override
  String label(DateTime now) =>
      changes == 1 ? '1 change waiting' : '$changes changes waiting';

  @override
  bool operator ==(Object other) =>
      other is WaitingStatus && other.changes == changes;

  @override
  int get hashCode => changes.hashCode;
}

final class OfflineStatus extends SyncStatus {
  const OfflineStatus();

  @override
  String label(DateTime now) => 'Offline · will sync when connected';

  @override
  bool operator ==(Object other) => other is OfflineStatus;

  @override
  int get hashCode => (OfflineStatus).hashCode;
}

final class UploadingStatus extends SyncStatus {
  const UploadingStatus(this.files);

  final int files;

  @override
  String label(DateTime now) =>
      files == 1 ? 'Uploading 1 file' : 'Uploading $files files';

  @override
  bool operator ==(Object other) =>
      other is UploadingStatus && other.files == files;

  @override
  int get hashCode => files.hashCode;
}

final class PausedStatus extends SyncStatus {
  const PausedStatus();

  @override
  String label(DateTime now) => 'Sync paused';

  @override
  bool operator ==(Object other) => other is PausedStatus;

  @override
  int get hashCode => (PausedStatus).hashCode;
}

final class AttentionStatus extends SyncStatus {
  const AttentionStatus(this.reason);

  final AttentionReason reason;

  String? get fix => reason.fix;

  @override
  String label(DateTime now) => 'Needs attention · ${reason.label}';

  @override
  bool operator ==(Object other) =>
      other is AttentionStatus && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

final class SyncStatusInputs {
  const SyncStatusInputs({
    required this.outboxCount,
    required this.online,
    required this.uploadCount,
    required this.paused,
    required this.attention,
    required this.lastSyncedAt,
  });

  final int outboxCount;
  final bool online;
  final int uploadCount;
  final bool paused;
  final AttentionReason? attention;
  final DateTime lastSyncedAt;
}

SyncStatus syncStatusFor(SyncStatusInputs inputs) {
  final AttentionReason? attention = inputs.attention;
  if (inputs.paused) {
    return const PausedStatus();
  }
  if (attention != null) {
    return AttentionStatus(attention);
  }
  if (!inputs.online) {
    return const OfflineStatus();
  }
  if (inputs.outboxCount > 0) {
    return WaitingStatus(inputs.outboxCount);
  }
  if (inputs.uploadCount > 0) {
    return UploadingStatus(inputs.uploadCount);
  }
  return SyncedStatus(inputs.lastSyncedAt);
}
