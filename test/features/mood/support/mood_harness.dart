import 'dart:async';

import 'package:flutter/material.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';

Widget moodHarness(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: child)),
  );
}

Day testDay({
  String id = 'day-1',
  String date = '2026-07-19',
  Mood? mood,
}) {
  return Day(
    id: id,
    date: date,
    mood: mood,
    createdAt: 0,
    updatedAt: 0,
  );
}

class FakeJournalRepository implements JournalRepository {
  FakeJournalRepository({this.initialDay});

  final Day? initialDay;
  final StreamController<Day?> _days = StreamController<Day?>.broadcast();
  final List<({String date, Mood? mood})> moodWrites =
      <({String date, Mood? mood})>[];
  Object? setMoodError;

  void emitDay(Day? day) => _days.add(day);

  @override
  Stream<Day?> watchDayForDate(String date) async* {
    yield initialDay;
    yield* _days.stream;
  }

  @override
  Future<Day> setMoodForDate({required String date, Mood? mood}) async {
    final Object? error = setMoodError;
    if (error != null) {
      throw error;
    }
    moodWrites.add((date: date, mood: mood));
    final Day updated = testDay(date: date, mood: mood);
    _days.add(updated);
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
