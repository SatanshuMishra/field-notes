import 'package:field_notes/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_rules.dart';
import 'a11y_state.dart';

const Key _plantedKey = ValueKey<String>('planted');

void _noop() {}

A11yState _plantedOn(TargetPlatform platform, String label, Size size) =>
    A11yState(
      id: 'planted',
      pump: (WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          theme: fieldNotesTheme(platform: platform),
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
  testWidgets(
    'desktop targets are judged against 24 logical pixels and phone targets '
    'against 48',
    (WidgetTester tester) async {
      final Matcher small = anyElement(startsWith('small-target | planted'));
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(
          await _ids(tester, platform, 'Read notes', const Size(92, 30)),
          isNot(small),
          reason: '$platform: a 92x30 pill meets the desktop minimum',
        );
        expect(
          await _ids(
            tester,
            platform,
            'Check automatically',
            const Size(36, 24),
          ),
          isNot(small),
          reason: '$platform: a 36x24 toggle meets the desktop minimum',
        );
        expect(
          await _ids(tester, platform, 'Thin', const Size(92, 20)),
          contains('small-target | planted | Thin | <root>'),
          reason: '$platform: a 20 pixel tall target is under 24',
        );
        expect(
          await _ids(tester, platform, 'Narrow', const Size(20, 40)),
          contains('small-target | planted | Narrow | <root>'),
          reason: '$platform: a 20 pixel wide target is under 24',
        );
      }
      expect(
        await _ids(
          tester,
          TargetPlatform.android,
          'Read notes',
          const Size(92, 30),
        ),
        contains('small-target | planted | Read notes | <root>'),
        reason: 'the phone layout keeps the 48 pixel minimum',
      );
      expect(
        await _ids(
          tester,
          TargetPlatform.android,
          'Website',
          const Size(48, 48),
        ),
        isNot(small),
        reason: 'a 48x48 phone target meets the phone minimum',
      );
    },
  );
}
