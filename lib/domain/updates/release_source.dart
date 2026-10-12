import 'package:field_notes/domain/updates/release_info.dart';

enum LookupFailure { offline, badResponse }

sealed class ReleaseLookup {
  const ReleaseLookup();
}

final class ReleaseFound extends ReleaseLookup {
  const ReleaseFound(this.release);

  final ReleaseInfo release;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseFound && release == other.release;

  @override
  int get hashCode => Object.hash(ReleaseFound, release);

  @override
  String toString() => 'ReleaseFound($release)';
}

final class NoRelease extends ReleaseLookup {
  const NoRelease();

  @override
  bool operator ==(Object other) => other is NoRelease;

  @override
  int get hashCode => (NoRelease).hashCode;

  @override
  String toString() => 'NoRelease()';
}

final class LookupRateLimited extends ReleaseLookup {
  const LookupRateLimited(this.retryAfter);

  final DateTime retryAfter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookupRateLimited && retryAfter == other.retryAfter;

  @override
  int get hashCode => Object.hash(LookupRateLimited, retryAfter);

  @override
  String toString() => 'LookupRateLimited($retryAfter)';
}

final class LookupFailed extends ReleaseLookup {
  const LookupFailed(this.reason);

  final LookupFailure reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LookupFailed && reason == other.reason;

  @override
  int get hashCode => Object.hash(LookupFailed, reason);

  @override
  String toString() => 'LookupFailed($reason)';
}

abstract interface class ReleaseSource {
  Future<ReleaseLookup> latest();
}
