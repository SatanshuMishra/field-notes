import 'package:field_notes/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

Widget gardenHarness(
  Widget child, {
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    retry: (int retryCount, Object error) => null,
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );
}

Day dayOf(String date, {Mood? mood, int? deletedAt}) => Day(
      id: 'id-$date',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
      deletedAt: deletedAt,
    );
