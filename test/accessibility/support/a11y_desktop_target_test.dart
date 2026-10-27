import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_rules.dart';
import 'a11y_state.dart';

const Key _plantedKey = ValueKey<String>('planted');

void _noop() {}

A11yState _plantedOn(TargetPlatform platform, String label, Size size) =>
    A11yState(
      id: 'planted',
      platforms: <TargetPlatform>{platform},
      pump: (WidgetTester tester, A11yVariant variant) => tester.pumpWidget(
        MaterialApp(
          theme: variant.theme,
          builder: variant.scaleText,
          home: Material(
            child: Center(
              child: Semantics(
                key: _plantedKey,
                button: true,
                label: label,
                onTap: _noop,
                child: SizedBox(width: size.width, height: size.height),
              ),
            ),
          ),
        ),
      ),
      proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
    );

Future<List<String>> _ids(
  WidgetTester tester,
  TargetPlatform platform,
  String label,
  Size size,
) async {
  final A11yStateResult result = await runA11yState(
    tester,
    _plantedOn(platform, label, size),
  );
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => <String>[
      for (final A11yFinding finding in findings) finding.id,
    ],
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

void main() {
  final Matcher small = anyElement(startsWith('small-target | planted'));

  testWidgets('macOS targets are judged against 28 by 28', (
    WidgetTester tester,
  ) async {
    expect(
      await _ids(
        tester,
        TargetPlatform.macOS,
        'Read notes',
        const Size(92, 30),
      ),
      isNot(small),
    );
    expect(
      await _ids(tester, TargetPlatform.macOS, 'Square', const Size(28, 28)),
      isNot(small),
    );
    expect(
      await _ids(tester, TargetPlatform.macOS, 'Thin', const Size(92, 27)),
      contains('small-target | planted | Thin | <root>'),
    );
    expect(
      await _ids(tester, TargetPlatform.macOS, 'Narrow', const Size(27, 40)),
      contains('small-target | planted | Narrow | <root>'),
    );
  });

  testWidgets('Windows targets are judged against 40 by 40', (
    WidgetTester tester,
  ) async {
    expect(
      await _ids(
        tester,
        TargetPlatform.windows,
        'Read notes',
        const Size(92, 40),
      ),
      isNot(small),
    );
    expect(
      await _ids(
        tester,
        TargetPlatform.windows,
        'Check automatically',
        const Size(92, 30),
      ),
      contains('small-target | planted | Check automatically | <root>'),
    );
    expect(
      await _ids(tester, TargetPlatform.windows, 'Thin', const Size(92, 39)),
      contains('small-target | planted | Thin | <root>'),
    );
    expect(
      await _ids(tester, TargetPlatform.windows, 'Narrow', const Size(39, 40)),
      contains('small-target | planted | Narrow | <root>'),
    );
  });

  testWidgets('Android phone targets are judged against 48 by 48', (
    WidgetTester tester,
  ) async {
    expect(
      await _ids(
        tester,
        TargetPlatform.android,
        'Read notes',
        const Size(92, 30),
      ),
      contains('small-target | planted | Read notes | <root>'),
    );
    expect(
      await _ids(tester, TargetPlatform.android, 'Website', const Size(48, 48)),
      isNot(small),
    );
  });
}
