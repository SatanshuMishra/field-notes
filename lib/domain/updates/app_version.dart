final class AppVersion implements Comparable<AppVersion> {
  AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    List<String> prerelease = const <String>[],
  }) : assert(major >= 0, 'major must not be negative'),
       assert(minor >= 0, 'minor must not be negative'),
       assert(patch >= 0, 'patch must not be negative'),
       prerelease = List<String>.unmodifiable(prerelease);

  static final RegExp _pattern = RegExp(
    r'^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
    r'(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
    r'(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  static final RegExp _numeric = RegExp(r'^[0-9]+$');

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  static AppVersion? tryParse(String text) {
    final RegExpMatch? match = _pattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    final int? major = int.tryParse(match.group(1)!);
    final int? minor = int.tryParse(match.group(2)!);
    final int? patch = int.tryParse(match.group(3)!);
    if (major == null || minor == null || patch == null) {
      return null;
    }
    final String? prerelease = match.group(4);
    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      prerelease: prerelease == null ? const <String>[] : prerelease.split('.'),
    );
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    final int core = _compareCore(other);
    if (core != 0) {
      return core;
    }
    return _comparePrerelease(prerelease, other.prerelease);
  }

  int _compareCore(AppVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }

  static int _comparePrerelease(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) {
      if (a.isEmpty && b.isEmpty) {
        return 0;
      }
      return a.isEmpty ? 1 : -1;
    }
    final int shared = a.length < b.length ? a.length : b.length;
    for (int index = 0; index < shared; index++) {
      final int order = _compareIdentifier(a[index], b[index]);
      if (order != 0) {
        return order;
      }
    }
    return a.length.compareTo(b.length);
  }

  static int _compareIdentifier(String a, String b) {
    final bool aNumeric = _numeric.hasMatch(a);
    final bool bNumeric = _numeric.hasMatch(b);
    if (aNumeric && bNumeric) {
      if (a.length != b.length) {
        return a.length.compareTo(b.length);
      }
      return a.compareTo(b).sign;
    }
    if (aNumeric) {
      return -1;
    }
    if (bNumeric) {
      return 1;
    }
    return a.compareTo(b).sign;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! AppVersion ||
        major != other.major ||
        minor != other.minor ||
        patch != other.patch ||
        prerelease.length != other.prerelease.length) {
      return false;
    }
    for (int index = 0; index < prerelease.length; index++) {
      if (prerelease[index] != other.prerelease[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(prerelease));

  @override
  String toString() {
    final String core = '$major.$minor.$patch';
    return prerelease.isEmpty ? core : '$core-${prerelease.join('.')}';
  }
}
