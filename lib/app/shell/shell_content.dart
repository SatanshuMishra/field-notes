import 'package:flutter/widgets.dart';

import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/search/search.dart';
import 'package:field_notes/features/settings/settings.dart';
import 'package:field_notes/features/today/today.dart';

import 'shell_destination.dart';

class ShellContent extends StatelessWidget {
  const ShellContent({super.key, required this.destination});

  final ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<ShellDestination>(destination),
      child: _screenFor(destination),
    );
  }

  Widget _screenFor(ShellDestination destination) {
    switch (destination) {
      case ShellDestination.today:
        return const TodayScreen();
      case ShellDestination.calendar:
        return const CalendarScreen();
      case ShellDestination.garden:
        return const GardenScreen();
      case ShellDestination.search:
        return const SearchScreen();
      case ShellDestination.settings:
        return const SettingsScreen();
    }
  }
}
