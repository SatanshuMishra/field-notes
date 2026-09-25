import 'package:flutter_test/flutter_test.dart';

import 'states/capture_states.dart';
import 'states/settings_states.dart';
import 'states/shell_states.dart';
import 'states/viewer_states.dart';
import 'support/a11y_state.dart';

List<String> _ids(List<A11yState> states) => <String>[
  for (final A11yState state in states) state.id,
];

void main() {
  test('every area exposes its states for other tests', () {
    expect(_ids(shellStates), <String>[
      'a1-today-empty',
      'a2-today-feed',
      'a3-card-actions',
      'a4-calendar-month',
      'a5-calendar-picker',
      'a6-garden-empty',
      'a7-garden-blooms',
      'a8-garden-phone',
      'a9-search-results',
      'a10-search-no-match',
      'a11-calendar-next-month',
    ]);
    expect(_ids(settingsStates), <String>[
      'b1-settings',
      'b2-settings-spell-unavailable',
      'b3-settings-notice',
      'b4-select-open',
      'b5-delete-all-dialog',
    ]);
    expect(_ids(captureStates), <String>[
      'c1-chooser',
      'c2-composer-new',
      'c3-composer-keyboard',
      'c4-more-formats',
      'c5-edit-note',
      'c6-photo-selected',
      'c7-photo-caption',
      'c8-table-toolbar',
      'c9-selection-menu',
      'c10-discard-dialog',
      'c11-draft-chip',
      'c12-voice-idle',
      'c13-voice-recording',
      'c14-voice-paused',
      'c15-video-idle',
      'c16-video-recording',
      'c17-video-paused',
      'c18-discard-recording',
      'c19-photo-removed-toast',
    ]);
    expect(_ids(viewerStates), <String>[
      'd1-viewer-todos',
      'd2-viewer-photo',
      'd3-viewer-voice',
      'd4-viewer-video',
      'd5-reader-menu',
      'd6-task-toast',
      'd7-day-with-entries',
      'd8-day-empty',
      'd9-mood-prompt-today',
      'd10-mood-prompt-past',
      'd11-mood-picker',
      'd12-mood-set',
      'd13-change-mood-dialog',
      'd14-delete-entry-dialog',
      'd15-viewer-middle-entry',
    ]);
  });

  test('stateful checks are attached only where their controls are built', () {
    expect(
      <String>[
        for (final A11yState state in shellStates)
          if (state.stateful.isNotEmpty) state.id,
      ],
      <String>['a1-today-empty', 'a5-calendar-picker', 'a8-garden-phone'],
    );
    expect(
      captureStates
          .singleWhere((A11yState state) => state.id == 'c6-photo-selected')
          .stateful,
      isEmpty,
    );
  });
}
