import 'package:flutter/material.dart';

enum ShellDestination {
  today('Today', Icons.wb_sunny_outlined),
  calendar('Calendar', Icons.calendar_today_outlined),
  garden('Garden', Icons.local_florist_outlined),
  search('Search', Icons.search),
  settings('Settings', Icons.settings_outlined);

  const ShellDestination(this.label, this.icon);

  final String label;
  final IconData icon;

  static const List<ShellDestination> primary = <ShellDestination>[
    today,
    calendar,
    garden,
    search,
  ];
}
