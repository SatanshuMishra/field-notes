import 'package:flutter_test/flutter_test.dart';

import '../states/capture_states.dart';
import '../support/a11y_rules.dart';
import '../support/a11y_state.dart';

Future<List<String>> _idsIn(
  WidgetTester tester,
  List<A11yState> states,
  String id,
) async {
  final A11yStateResult result = await runA11yState(
    tester,
    states.singleWhere((A11yState state) => state.id == id),
  );
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => <String>[
      for (final A11yFinding finding in findings) finding.id,
    ],
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

void _expectNone(
  List<String> ids,
  String rule,
  String state,
  List<String> labels,
) {
  for (final String label in labels) {
    final String prefix = '$rule | $state | $label';
    expect(
      ids.where((String id) => id.startsWith(prefix)),
      isEmpty,
      reason: prefix,
    );
  }
}

void main() {
  testWidgets('the capture chooser rows are buttons', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(tester, captureStates, 'c1-chooser');
    _expectNone(ids, 'missing-role', 'c1-chooser', <String>[
      'Write a note',
      'Record voice',
      'Record video',
    ]);
  });

  testWidgets('the voice recorder actions are 48 dp buttons', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c13-voice-recording',
    );
    _expectNone(ids, 'missing-role', 'c13-voice-recording', <String>[
      'Discard |',
      'Save memo |',
    ]);
    _expectNone(ids, 'small-target', 'c13-voice-recording', <String>[
      'Discard |',
      'Save memo |',
      'Close |',
    ]);
  });

  testWidgets('the video recorder actions are 48 dp buttons', (
    WidgetTester tester,
  ) async {
    final List<String> ids = await _idsIn(
      tester,
      captureStates,
      'c16-video-recording',
    );
    _expectNone(ids, 'missing-role', 'c16-video-recording', <String>[
      'Discard |',
      'Save |',
    ]);
    _expectNone(ids, 'small-target', 'c16-video-recording', <String>[
      'Discard |',
      'Save |',
      'Close |',
    ]);
  });
}
