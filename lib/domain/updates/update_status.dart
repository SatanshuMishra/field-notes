import 'package:field_notes/domain/updates/release_info.dart';
import 'package:field_notes/domain/updates/release_source.dart';
import 'package:field_notes/domain/updates/update_installer.dart';

sealed class UpdateStatus {
  const UpdateStatus();
}

final class UpdateIdle extends UpdateStatus {
  const UpdateIdle(this.lastChecked);

  final DateTime? lastChecked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateIdle && lastChecked == other.lastChecked;

  @override
  int get hashCode => Object.hash(UpdateIdle, lastChecked);

  @override
  String toString() => 'UpdateIdle($lastChecked)';
}

final class UpdateChecking extends UpdateStatus {
  const UpdateChecking(this.lastChecked);

  final DateTime? lastChecked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateChecking && lastChecked == other.lastChecked;

  @override
  int get hashCode => Object.hash(UpdateChecking, lastChecked);

  @override
  String toString() => 'UpdateChecking($lastChecked)';
}

final class UpdateCurrent extends UpdateStatus {
  const UpdateCurrent(this.checkedAt);

  final DateTime checkedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateCurrent && checkedAt == other.checkedAt;

  @override
  int get hashCode => Object.hash(UpdateCurrent, checkedAt);

  @override
  String toString() => 'UpdateCurrent($checkedAt)';
}

final class UpdateAvailable extends UpdateStatus {
  const UpdateAvailable(this.release, this.checkedAt, {this.lastFailure});

  final ReleaseInfo release;
  final DateTime checkedAt;
  final InstallFailure? lastFailure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateAvailable &&
          release == other.release &&
          checkedAt == other.checkedAt &&
          lastFailure == other.lastFailure;

  @override
  int get hashCode =>
      Object.hash(UpdateAvailable, release, checkedAt, lastFailure);

  @override
  String toString() =>
      'UpdateAvailable(${release.version}, $checkedAt, '
      'lastFailure: $lastFailure)';
}

final class UpdateDownloading extends UpdateStatus {
  const UpdateDownloading(this.release, this.fraction)
    : assert(
        fraction == null || (fraction >= 0 && fraction <= 1),
        'fraction must be in 0..1',
      );

  final ReleaseInfo release;
  final double? fraction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateDownloading &&
          release == other.release &&
          fraction == other.fraction;

  @override
  int get hashCode => Object.hash(UpdateDownloading, release, fraction);

  @override
  String toString() => 'UpdateDownloading(${release.version}, $fraction)';
}

final class UpdateRestarting extends UpdateStatus {
  const UpdateRestarting(this.release);

  final ReleaseInfo release;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateRestarting && release == other.release;

  @override
  int get hashCode => Object.hash(UpdateRestarting, release);

  @override
  String toString() => 'UpdateRestarting(${release.version})';
}

final class UpdateCheckFailed extends UpdateStatus {
  const UpdateCheckFailed(this.lastChecked, this.reason, this.retryAfter);

  final DateTime? lastChecked;
  final LookupFailure? reason;
  final DateTime? retryAfter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateCheckFailed &&
          lastChecked == other.lastChecked &&
          reason == other.reason &&
          retryAfter == other.retryAfter;

  @override
  int get hashCode =>
      Object.hash(UpdateCheckFailed, lastChecked, reason, retryAfter);

  @override
  String toString() =>
      'UpdateCheckFailed($lastChecked, $reason, retryAfter: $retryAfter)';
}
