import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackLabel, logViewerCloseLabel;

const String _quietLineSeparator = ' · ';

typedef LogViewerRename = Future<bool> Function(String? title);

String entryClockOf(BuildContext context, Entry entry) {
  return formatClock(
    context,
    TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
    ),
  );
}

@immutable
final class LogViewerScene {
  const LogViewerScene({
    required this.entry,
    required this.date,
    required this.dayTitle,
    required this.mood,
    required this.index,
    required this.count,
    required this.earlier,
    required this.later,
    required this.exit,
    required this.onBack,
    required this.onEarlier,
    required this.onLater,
    required this.onDelete,
    required this.onEdit,
    this.onRename,
    this.fullScreen = false,
    this.onFullScreen,
  });

  final Entry entry;
  final String date;
  final String dayTitle;
  final Mood? mood;
  final int index;
  final int count;
  final Entry? earlier;
  final Entry? later;
  final LogViewerExit exit;
  final VoidCallback onBack;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final LogViewerRename? onRename;
  final bool fullScreen;
  final VoidCallback? onFullScreen;

  VoidCallback get onEscape {
    final VoidCallback? leaveFullScreen = onFullScreen;
    return fullScreen && leaveFullScreen != null ? leaveFullScreen : onBack;
  }

  String get exitLabel {
    return switch (exit) {
      LogViewerExit.back => logViewerBackLabel,
      LogViewerExit.close => logViewerCloseLabel,
    };
  }

  String? get position {
    if (count > 1) {
      return '${index + 1} of $count';
    }
    return null;
  }

  String clockOf(BuildContext context) {
    return entryClockOf(context, entry);
  }

  String stamp(BuildContext context) =>
      '$dayTitle$_quietLineSeparator${clockOf(context)}';

  String quietLine(BuildContext context) {
    final String? place = position;
    return <String>[
      dayTitle,
      clockOf(context),
      ?place,
    ].join(_quietLineSeparator);
  }
}
