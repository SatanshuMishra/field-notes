import 'package:flutter/material.dart';

import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/search/search.dart';
import 'package:field_notes/features/settings/settings.dart';
import 'package:field_notes/features/streak/streak_card.dart';
import 'package:field_notes/features/today/today.dart';

import 'shell_destination.dart';
import 'shell_layout.dart';

class ShellContent extends StatelessWidget {
  const ShellContent({super.key, required this.destination});

  final ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<ShellDestination>(destination),
      child: _screenFor(context, destination),
    );
  }

  Widget _screenFor(BuildContext context, ShellDestination destination) {
    switch (destination) {
      case ShellDestination.today:
        return const TodayScreen();
      case ShellDestination.calendar:
        return const CalendarScreen();
      case ShellDestination.garden:
        return _garden(resolveShellLayout(Theme.of(context).platform));
      case ShellDestination.search:
        return const SearchScreen();
      case ShellDestination.settings:
        return const SettingsScreen();
    }
  }

  Widget _garden(ShellLayout layout) {
    switch (layout) {
      case ShellLayout.sidebar:
        return const GardenScreen();
      case ShellLayout.bottomBar:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: StreakCard(),
            ),
            Expanded(child: GardenScreen()),
          ],
        );
    }
  }
}
