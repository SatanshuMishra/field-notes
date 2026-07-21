import 'package:field_notes/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

Widget searchHarness(
  Widget child, {
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );
}

Day dayOf(String date, {String? id, Mood? mood}) {
  return Day(
    id: id ?? 'day-$date',
    date: date,
    mood: mood,
    createdAt: 0,
    updatedAt: 0,
  );
}

Entry entryOf({
  required String dayId,
  String id = 'entry-1',
  EntryType type = EntryType.text,
  String? textContent,
  int createdAt = 0,
}) {
  return Entry(
    id: id,
    dayId: dayId,
    type: type,
    textContent: textContent,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
