import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';

void _noop() {}

Entry _entryAt(DateTime createdAt) {
  final int millis = createdAt.millisecondsSinceEpoch;
  return Entry(
    id: 'entry-2',
    dayId: 'day-1',
    type: EntryType.text,
    textContent: 'Morning walk',
    createdAt: millis,
    updatedAt: millis,
  );
}

LogViewerScene _sceneOf({
  required Entry entry,
  required int index,
  required int count,
  required LogViewerExit exit,
}) {
  return LogViewerScene(
    entry: entry,
    date: '2025-07-05',
    dayTitle: 'Saturday, July 5',
    mood: Mood.calm,
    index: index,
    count: count,
    earlier: null,
    later: null,
    exit: exit,
    onBack: _noop,
    onEarlier: null,
    onLater: null,
    onDelete: _noop,
    onEdit: null,
  );
}

void main() {
  testWidgets('the quiet line reads day, time and position', (
    WidgetTester tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext appContext, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(appContext)
                .copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
        home: Builder(
          builder: (BuildContext homeContext) {
            context = homeContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final Entry entry = _entryAt(DateTime(2025, 7, 5, 7, 40));

    final LogViewerScene secondOfFour = _sceneOf(
      entry: entry,
      index: 1,
      count: 4,
      exit: LogViewerExit.back,
    );
    expect(secondOfFour.position, '2 of 4');
    expect(entryClockOf(context, entry), '07:40');
    expect(secondOfFour.clockOf(context), '07:40');
    expect(
      secondOfFour.quietLine(context),
      'Saturday, July 5 · 07:40 · 2 of 4',
    );

    final LogViewerScene onlyLog = _sceneOf(
      entry: entry,
      index: 0,
      count: 1,
      exit: LogViewerExit.close,
    );
    expect(onlyLog.position, isNull);
    expect(onlyLog.quietLine(context), 'Saturday, July 5 · 07:40');

    expect(secondOfFour.exitLabel, 'Back');
    expect(onlyLog.exitLabel, 'Close');
  });
}
