import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const Size todayPhoneSurface = Size(420, 780);
const Size todayDesktopSurface = Size(1000, 780);

Widget todayHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

Future<void> pumpToday(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  Size surface = todayPhoneSurface,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: todayHarness(child)),
  );
  await tester.pumpAndSettle();
}

Day todayTestDay({
  String id = 'day-1',
  String date = '2026-07-19',
  Mood? mood,
}) {
  return Day(id: id, date: date, mood: mood, createdAt: 0, updatedAt: 0);
}

Entry todayTestEntry({
  String id = 'entry-1',
  String dayId = 'day-1',
  EntryType type = EntryType.text,
  String? textContent = 'a note',
  String? mediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: dayId,
    type: type,
    textContent: textContent,
    mediaId: mediaId,
    durationMs: durationMs,
    createdAt: 0,
    updatedAt: 0,
  );
}

EntryPhoto todayTestPhoto({
  String id = 'photo-1',
  String entryId = 'entry-1',
  String mediaId = 'media-1',
  int sortOrder = 0,
}) {
  return EntryPhoto(
    id: id,
    entryId: entryId,
    mediaId: mediaId,
    sortOrder: sortOrder,
    createdAt: 0,
    updatedAt: 0,
  );
}

class StubMediaResolver implements MediaResolver {
  const StubMediaResolver();

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async =>
      const ResolvedMedia.missing();
}
