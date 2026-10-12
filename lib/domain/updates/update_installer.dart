import 'package:field_notes/domain/updates/release_info.dart';

enum InstallRoute { restartInPlace, systemInstaller, googlePlay, downloadPage }

enum InstallFailure { network, verification, permission, notReady, installer }

sealed class InstallEvent {
  const InstallEvent();
}

final class InstallDownloading extends InstallEvent {
  const InstallDownloading(this.received, this.total);

  final int received;
  final int? total;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallDownloading &&
          received == other.received &&
          total == other.total;

  @override
  int get hashCode => Object.hash(InstallDownloading, received, total);

  @override
  String toString() => 'InstallDownloading($received, $total)';
}

final class InstallVerifying extends InstallEvent {
  const InstallVerifying();

  @override
  bool operator ==(Object other) => other is InstallVerifying;

  @override
  int get hashCode => (InstallVerifying).hashCode;

  @override
  String toString() => 'InstallVerifying()';
}

final class InstallRestarting extends InstallEvent {
  const InstallRestarting();

  @override
  bool operator ==(Object other) => other is InstallRestarting;

  @override
  int get hashCode => (InstallRestarting).hashCode;

  @override
  String toString() => 'InstallRestarting()';
}

final class InstallHandedOff extends InstallEvent {
  const InstallHandedOff();

  @override
  bool operator ==(Object other) => other is InstallHandedOff;

  @override
  int get hashCode => (InstallHandedOff).hashCode;

  @override
  String toString() => 'InstallHandedOff()';
}

final class InstallFailed extends InstallEvent {
  const InstallFailed(this.failure);

  final InstallFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallFailed && failure == other.failure;

  @override
  int get hashCode => Object.hash(InstallFailed, failure);

  @override
  String toString() => 'InstallFailed($failure)';
}

abstract interface class UpdateInstaller {
  InstallRoute get route;

  Stream<InstallEvent> install(ReleaseInfo release);
}
