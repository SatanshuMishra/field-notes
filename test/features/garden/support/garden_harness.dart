import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

Widget gardenHarness(
  Widget child, {
  List<Override> overrides = const <Override>[],
  TargetPlatform? platform,
  Stream<AppSettings>? settings,
}) {
  return ProviderScope(
    retry: (int retryCount, Object error) => null,
    overrides: <Override>[
      appSettingsProvider.overrideWith(
        (Ref ref) =>
            settings ?? Stream<AppSettings>.value(AppSettings.defaults),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: platform == null ? null : fieldNotesTheme(platform: platform),
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
