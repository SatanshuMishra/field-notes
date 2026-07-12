import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_destination.dart';

void main() {
  group('ShellDestination', () {
    test('primary keeps the prototype order and excludes settings', () {
      expect(ShellDestination.primary, <ShellDestination>[
        ShellDestination.today,
        ShellDestination.calendar,
        ShellDestination.garden,
        ShellDestination.search,
      ]);
      expect(
        ShellDestination.primary.contains(ShellDestination.settings),
        isFalse,
      );
    });

    test('every destination carries a non-empty label', () {
      for (final ShellDestination d in ShellDestination.values) {
        expect(d.label, isNotEmpty);
      }
    });

    test('labels match the locked nav names', () {
      expect(ShellDestination.today.label, 'Today');
      expect(ShellDestination.calendar.label, 'Calendar');
      expect(ShellDestination.garden.label, 'Garden');
      expect(ShellDestination.search.label, 'Search');
      expect(ShellDestination.settings.label, 'Settings');
    });
  });
}
