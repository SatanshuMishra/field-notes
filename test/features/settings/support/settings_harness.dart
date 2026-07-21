import 'dart:async';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget settingsFeatureHarness(
  Widget child, {
  List<Override> overrides = const <Override>[],
  bool scrollable = true,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Palette.page,
        body: scrollable
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
      ),
    ),
  );
}

void useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class FakeSettingsDataController implements SettingsDataController {
  FakeSettingsDataController({
    this.exportResult = const DataActionDismissed(),
    this.deleteResult = const DataActionDismissed(),
    this.gate,
  });

  final DataActionResult exportResult;
  final DataActionResult deleteResult;
  final Completer<void>? gate;
  int exportCalls = 0;
  int deleteCalls = 0;

  @override
  Future<DataActionResult> export() async {
    exportCalls++;
    await gate?.future;
    return exportResult;
  }

  @override
  Future<DataActionResult> deleteAll() async {
    deleteCalls++;
    await gate?.future;
    return deleteResult;
  }
}
