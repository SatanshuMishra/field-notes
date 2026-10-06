import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

final List<RegExp> _sixStates = <RegExp>[
  RegExp(r'^Synced · .+$'),
  RegExp(r'^(1 change|\d+ changes) waiting$'),
  RegExp(r'^Offline · will sync when connected$'),
  RegExp(r'^Uploading (1 file|\d+ files)$'),
  RegExp(r'^Sync paused$'),
  RegExp(r'^Needs attention · .+$'),
];

SyncStatus _expected({
  required int outbox,
  required bool online,
  required int uploads,
  required bool paused,
  required AttentionReason? attention,
  required DateTime syncedAt,
}) {
  if (paused) {
    return const PausedStatus();
  }
  if (attention != null) {
    return AttentionStatus(attention);
  }
  if (!online) {
    return const OfflineStatus();
  }
  if (outbox > 0) {
    return WaitingStatus(outbox);
  }
  if (uploads > 0) {
    return UploadingStatus(uploads);
  }
  return SyncedStatus(syncedAt);
}

void main() {
  test('status reports exactly one state', () {
    final DateTime now = DateTime.utc(2026, 10, 5, 9);
    final DateTime syncedAt = now.subtract(const Duration(minutes: 3));
    final List<AttentionReason?> errors = <AttentionReason?>[
      null,
      ...AttentionReason.values,
    ];
    int combinations = 0;
    for (final int outbox in <int>[0, 1, 4]) {
      for (final bool online in <bool>[true, false]) {
        for (final int uploads in <int>[0, 1, 3]) {
          for (final bool paused in <bool>[false, true]) {
            for (final AttentionReason? attention in errors) {
              final SyncStatus status = syncStatusFor(
                SyncStatusInputs(
                  outboxCount: outbox,
                  online: online,
                  uploadCount: uploads,
                  paused: paused,
                  attention: attention,
                  lastSyncedAt: syncedAt,
                ),
              );
              final String label = status.label(now);
              expect(
                _sixStates.where((RegExp state) => state.hasMatch(label)),
                hasLength(1),
                reason: label,
              );
              expect(
                status,
                _expected(
                  outbox: outbox,
                  online: online,
                  uploads: uploads,
                  paused: paused,
                  attention: attention,
                  syncedAt: syncedAt,
                ),
              );
              combinations += 1;
            }
          }
        }
      }
    }
    expect(combinations, 3 * 2 * 3 * 2 * (AttentionReason.values.length + 1));

    expect(const WaitingStatus(1).label(now), '1 change waiting');
    expect(const WaitingStatus(4).label(now), '4 changes waiting');
    expect(const UploadingStatus(1).label(now), 'Uploading 1 file');
    expect(const UploadingStatus(3).label(now), 'Uploading 3 files');
    expect(SyncedStatus(syncedAt).label(now), 'Synced · 3 minutes ago');
    expect(SyncedStatus(now).label(now), 'Synced · just now');
    expect(const PausedStatus().label(now), 'Sync paused');
    expect(
      const OfflineStatus().label(now),
      'Offline · will sync when connected',
    );
    expect(
      <String>[
        for (final AttentionReason reason in AttentionReason.values)
          AttentionStatus(reason).label(now),
      ],
      <String>[
        "Needs attention · can't reach your server",
        "Needs attention · can't reach your new server",
        "Needs attention · can't open your sync keys",
        "Needs attention · this device's clock",
        'Needs attention · update Field Notes',
        'Needs attention · this device was removed',
        'Needs attention · your server is full',
        'Needs attention · sync hit a problem',
      ],
    );
    expect(
      const AttentionStatus(AttentionReason.unreachable).fix,
      "Your changes are safe here and will go up when it's back.",
    );
    expect(
      const AttentionStatus(AttentionReason.clock).fix,
      'Set the date and time automatically to keep syncing.',
    );
    expect(
      const AttentionStatus(AttentionReason.updateApp).fix,
      'Please update Field Notes to keep syncing.',
    );
    expect(
      const AttentionStatus(AttentionReason.removed).fix,
      'This device was removed from your journal.',
    );
  });
}
