import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'states/capture_states.dart';
import 'states/immersive_states.dart';
import 'states/media_states.dart';
import 'states/onboarding_states.dart';
import 'states/settings_states.dart';
import 'states/shell_states.dart';
import 'states/sync_states.dart';
import 'states/updates_states.dart';
import 'states/viewer_states.dart';
import 'support/a11y_rules.dart';
import 'support/a11y_state.dart';

List<String> _ids(List<A11yState> states) => <String>[
  for (final A11yState state in states) state.id,
];

const List<String> _mainPathSlugs = <String>[
  'video-download',
  'video-controls',
  'photo-viewer',
  'sync-start',
  'sync-join',
  'sync-restore',
  'add-device',
  'change-server',
  'devices-list',
  'update-notes',
  'update-greeting',
  'select-dropdown',
  'delete-all-dialog',
  'today-empty',
  'calendar-empty',
  'search-empty',
  'search-no-match',
  'meadow-empty',
  'day-empty',
  'photo-error',
  'video-error',
  'voice-save-error',
  'sync-error',
  'update-error',
];

const List<String> _sheetStateIds = <String>[
  'd1-viewer-todos',
  'd2-viewer-photo',
  'd5-reader-menu',
  'd6-task-toast',
  'd7-day-with-entries',
  'd8-day-empty',
  'd14-delete-entry-dialog',
  'd15-viewer-middle-entry',
  'd16-day-past-mood',
];

const A11yVariant _androidDark = A11yVariant(
  platform: TargetPlatform.android,
  brightness: Brightness.dark,
);

final Set<int> _lightSheetColours = <int>{
  FieldNotesColors.light.cardWarm.toARGB32(),
  FieldNotesColors.light.panelTop.toARGB32(),
  FieldNotesColors.light.composerPaper.toARGB32(),
};

final Set<int> _darkSheetColours = <int>{
  FieldNotesColors.dark.cardWarm.toARGB32(),
  FieldNotesColors.dark.panelTop.toARGB32(),
  FieldNotesColors.dark.composerPaper.toARGB32(),
};

Map<String, List<A11yState>> get _statesByArea => <String, List<A11yState>>{
  'shell': shellStates,
  'settings': settingsStates,
  'capture': captureStates,
  'viewer': viewerStates,
  'immersive': immersiveStates,
  'onboarding': onboardingStates,
  'media': mediaStates,
  'sync': syncStates,
  'updates': updatesStates,
};

List<String> _surfacesMissingDesktop() => <String>[
  for (final MapEntry<String, List<A11yState>> area in _statesByArea.entries)
    for (final String surface in a11ySurfacesOffDesktop(area.value))
      '${area.key} $surface',
];

List<A11yState> get _everyState => <A11yState>[
  for (final List<A11yState> states in _statesByArea.values) ...states,
];

List<int> _sheetColours(WidgetTester tester) => <int>[
  for (final Element sheet in find.byType(PhoneSheet).evaluate())
    if (tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byElementPredicate(
                  (Element element) => element == sheet,
                ),
                matching: find.byType(DecoratedBox),
              ),
            )
            .first
            .decoration
        case BoxDecoration(:final Color color))
      color.toARGB32(),
];

void main() {
  test('every area exposes its states for other tests', () {
    expect(_ids(shellStates), <String>[
      'a1-today-empty',
      'a2-today-feed',
      'a3-card-actions',
      'a4-calendar-month',
      'a4-calendar-month-sidebar',
      'a5-calendar-picker',
      'a5-calendar-picker-sidebar',
      'a6-garden-empty',
      'a7-garden-blooms',
      'a8-garden-phone',
      'a8-garden-sidebar',
      'a9-search-results',
      'a9-search-results-sidebar',
      'a10-search-no-match',
      'a10-search-no-match-sidebar',
      'a11-calendar-next-month',
      'a11-calendar-next-month-sidebar',
      'a12-calendar-empty',
      'a13-search-empty',
      'a14-meadow-empty',
      'a15-today-empty-sidebar',
      'a16-search-error',
    ]);
    expect(_ids(settingsStates), <String>[
      'b1-settings',
      'b2-settings-spell-unavailable',
      'b3-settings-notice',
      'b4-select-open',
      'b5-delete-all-dialog',
      'b6-settings-reminders',
      'b7-settings-journal',
      'b8-settings-data',
      'b9-settings-about',
      'b10-settings-about-phone',
      'b11-select-dropdown-input-profile',
      'b12-select-dropdown-microphone',
      'b13-select-dropdown-speaker',
      'b14-sync-delete-all-dialog',
      'b15-settings-data-error',
      'b16-settings-sync-paused',
    ]);
    expect(_ids(captureStates), <String>[
      'c1-chooser',
      'c1-chooser-sidebar',
      'c2-composer-new',
      'c2-composer-new-sidebar',
      'c3-composer-keyboard',
      'c4-more-formats',
      'c5-edit-note',
      'c5-edit-note-sidebar',
      'c6-photo-selected',
      'c7-photo-caption',
      'c8-table-toolbar',
      'c9-selection-menu',
      'c10-discard-dialog',
      'c10-discard-dialog-sidebar',
      'c11-draft-chip',
      'c12-voice-idle',
      'c13-voice-recording',
      'c14-voice-paused',
      'c15-video-idle',
      'c16-video-recording',
      'c17-video-paused',
      'c18-discard-recording',
      'c19-photo-removed-toast',
      'c20-video-no-camera',
      'c21-voice-cannot-hear',
    ]);
    expect(_ids(viewerStates), <String>[
      'd1-viewer-todos',
      'd1-viewer-todos-sidebar',
      'd2-viewer-photo',
      'd2-viewer-photo-sidebar',
      'd3-viewer-voice',
      'd4-viewer-video',
      'd5-reader-menu',
      'd5-reader-menu-sidebar',
      'd6-task-toast',
      'd6-task-toast-sidebar',
      'd7-day-with-entries',
      'd7-day-with-entries-sidebar',
      'd8-day-empty',
      'd8-day-empty-sidebar',
      'd9-mood-prompt-today',
      'd10-mood-prompt-past',
      'd11-mood-picker',
      'd11-mood-picker-sidebar',
      'd12-mood-set',
      'd13-change-mood-dialog',
      'd13-change-mood-dialog-sidebar',
      'd14-delete-entry-dialog',
      'd14-delete-entry-dialog-sidebar',
      'd15-viewer-middle-entry',
      'd15-viewer-middle-entry-sidebar',
      'd16-day-past-mood',
      'd16-day-past-mood-sidebar',
    ]);
    expect(_ids(mediaStates), <String>[
      'm1-video-download-black-poster',
      'm2-video-download-white-poster',
      'm3-video-controls',
      'm4-photo-viewer',
      'm5-photo-error',
      'm6-video-error',
      'm7-voice-unavailable',
    ]);
    expect(_ids(syncStates), <String>[
      's1-sync-start',
      's2-sync-join',
      's3-sync-restore',
      's4-add-device-unreachable',
      's5-change-server',
      's6-devices-list',
      's7-sync-error-unreachable',
      's8-devices-list-sync-error',
    ]);
    expect(_ids(updatesStates), <String>[
      'u1-update-notes-new',
      'u2-update-notes-installed',
      'u3-update-greeting',
      'u4-update-error-offline',
    ]);
  });

  test(
    "every state's surface runs on macos and windows with the sidebar layout",
    () {
      final List<String> missing = _surfacesMissingDesktop();
      expect(
        missing,
        isEmpty,
        reason:
            'these surfaces never run on macos and windows:\n'
            '${missing.join('\n')}',
      );
    },
  );

  test('a sweep area refuses a surface that never runs on desktop', () {
    expect(
      () => a11ySweepArea(
        area: 'probe',
        groupName: 'probe',
        states: <A11yState>[
          A11yState(
            id: 'z1-probe',
            pump: (WidgetTester tester, A11yVariant variant) async {},
            proof: const <A11yProof>[],
            platforms: a11yPhonePlatforms,
          ),
        ],
      ),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError error) => error.invalidValue,
          'invalidValue',
          <String>['probe (z1-probe)'],
        ),
      ),
    );
  });

  test('the state library holds every named main-path surface', () {
    final List<String> ids = _ids(_everyState);
    expect(<String>[
      for (final String slug in _mainPathSlugs)
        if (!ids.any((String id) => id.contains(slug))) slug,
    ], isEmpty);
  });

  testWidgets('every state renders in the app theme for its brightness', (
    WidgetTester tester,
  ) async {
    final Map<String, List<int>> painted = <String, List<int>>{};
    for (final String id in _sheetStateIds) {
      final A11yState state = viewerStates.singleWhere(
        (A11yState state) => state.id == id,
      );
      await state.pump(tester, _androidDark);
      painted[id] = _sheetColours(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    }
    for (final String id in _sheetStateIds) {
      final List<int> colours = painted[id]!;
      expect(colours, isNotEmpty, reason: '$id shows no sheet');
      for (final int colour in colours) {
        expect(_darkSheetColours, contains(colour), reason: id);
        expect(_lightSheetColours, isNot(contains(colour)), reason: id);
      }
    }
  });

  test('stateful checks are attached only where their controls are built', () {
    expect(
      <String>[
        for (final A11yState state in shellStates)
          if (state.stateful.isNotEmpty) state.id,
      ],
      <String>[
        'a1-today-empty',
        'a5-calendar-picker',
        'a5-calendar-picker-sidebar',
        'a8-garden-phone',
        'a8-garden-sidebar',
      ],
    );
    expect(
      captureStates
          .singleWhere((A11yState state) => state.id == 'c6-photo-selected')
          .stateful,
      isEmpty,
    );
  });

  for (final (List<A11yState> states, String id, TargetPlatform platform)
      in <(List<A11yState>, String, TargetPlatform)>[
        (shellStates, 'a15-today-empty-sidebar', TargetPlatform.macOS),
        (shellStates, 'a9-search-results', TargetPlatform.android),
        (shellStates, 'a10-search-no-match', TargetPlatform.android),
        (onboardingStates, 'o11-moment-saved-sidebar', TargetPlatform.macOS),
        (captureStates, 'c13-voice-recording', TargetPlatform.macOS),
      ]) {
    testWidgets(
      'the sweep leaves status announcements to the contact sheets on $id',
      (WidgetTester tester) async {
        final A11yStateResult result = await runA11yState(
          tester,
          states.singleWhere((A11yState state) => state.id == id),
          variant: A11yVariant(platform: platform),
          checks: A11yChecks.full,
        );
        expect(a11yRuleDescriptions.keys, isNot(contains('live-region')));
        expect(switch (result) {
          A11yLoaded(:final List<A11yFinding> findings) => <String>[
            for (final A11yFinding finding in findings)
              if (finding.rule == 'live-region') finding.label,
          ],
          A11yNotLoaded(:final String message) => throw TestFailure(message),
        }, isEmpty);
      },
    );
  }
}
