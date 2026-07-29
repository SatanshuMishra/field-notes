import 'package:flutter/material.dart';

import '../../design/icons/nav_icons.dart';

enum ShellDestination {
  today('Today', Icons.wb_sunny_outlined, NavGlyph.home),
  calendar('Calendar', Icons.calendar_today_outlined, NavGlyph.calendar),
  garden('Garden', Icons.local_florist_outlined, NavGlyph.garden),
  search('Search', Icons.search, NavGlyph.search),
  settings('Settings', Icons.settings_outlined, null);

  const ShellDestination(this.label, this.icon, this.glyph);

  final String label;
  final IconData icon;
  final NavGlyph? glyph;

  static const List<ShellDestination> primary = <ShellDestination>[
    today,
    calendar,
    garden,
    search,
  ];
}
