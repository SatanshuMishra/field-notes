import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/settings_providers.dart';

import 'support/app_shell_harness.dart';

const Map<TextSize, double> _expectedFactor = <TextSize, double>{
  TextSize.small: 0.9,
  TextSize.medium: 1.0,
  TextSize.large: 1.15,
};

Future<void> _pumpApp(WidgetTester tester, TextSize textSize) async {
  tester.view.physicalSize = const Size(440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        ...shellOverrides(),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(
            AppSettings.defaults.copyWith(textSize: textSize),
          ),
        ),
      ],
      child: const FieldNotesApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

TextScaler _scalerBelowBuilder(WidgetTester tester) =>
    MediaQuery.textScalerOf(tester.element(find.byType(AppShell)));

void main() {
  group('FieldNotesApp text scale', () {
    for (final TextSize size in TextSize.values) {
      testWidgets('$size scales note text by the settings factor', (
        WidgetTester tester,
      ) async {
        await _pumpApp(tester, size);

        final TextScaler scaler = _scalerBelowBuilder(tester);
        expect(scaler.scale(16), closeTo(16 * _expectedFactor[size]!, 1e-9));
        expect(
          scaler.scale(13.5),
          closeTo(13.5 * _expectedFactor[size]!, 1e-9),
        );
      });
    }

    testWidgets('the settings factor composes with the ambient OS scaler', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpApp(tester, TextSize.large);

      final TextScaler scaler = _scalerBelowBuilder(tester);
      expect(scaler.scale(16), closeTo(16 * 1.15 * 1.5, 1e-9));
      expect(scaler, isA<ComposedTextScaler>());
    });

    testWidgets('the composed scaler applies the factor before the ambient', (
      WidgetTester tester,
    ) async {
      const TextScaler ambient = TextScaler.linear(2);
      const ComposedTextScaler composed = ComposedTextScaler(ambient, 1.15);

      expect(composed.scale(16), ambient.scale(16 * 1.15));
      expect(composed, const ComposedTextScaler(ambient, 1.15));
      expect(composed, isNot(const ComposedTextScaler(ambient, 1.0)));
      expect(
        composed.hashCode,
        const ComposedTextScaler(ambient, 1.15).hashCode,
      );
    });

    testWidgets('the medium size leaves the ambient scaler value untouched', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpApp(tester, TextSize.medium);

      expect(_scalerBelowBuilder(tester).scale(16), closeTo(16 * 1.3, 1e-9));
    });
  });
}
