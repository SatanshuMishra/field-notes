import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _self = 'test/tooling/old_onboarding_removed_test.dart';

const List<String> _roots = <String>['lib', 'test', 'integration_test', 'tool'];

const Set<String> _binaryExtensions = <String>{
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.ttf',
  '.otf',
  '.mp4',
  '.m4a',
  '.wav',
  '.sqlite',
  '.db',
};

const List<String> _deletedFiles = <String>[
  'lib/features/onboarding/welcome/onboarding_welcome.dart',
  'lib/features/onboarding/appearance/onboarding_appearance.dart',
  'lib/features/onboarding/setup/onboarding_setup.dart',
  'lib/features/onboarding/setup/setup_reminder_step.dart',
  'lib/features/onboarding/setup/setup_storage_step.dart',
  'lib/features/onboarding/setup/setup_summary.dart',
  'lib/features/onboarding/setup/setup_week_step.dart',
  'lib/features/onboarding/tour/onboarding_tour.dart',
  'lib/features/onboarding/tour/tour_geometry.dart',
  'lib/features/onboarding/tour/tour_spotlight.dart',
  'lib/features/onboarding/tour/tour_tips.dart',
  'lib/features/onboarding/tour_anchor.dart',
  'test/features/onboarding/onboarding_appearance_test.dart',
  'test/features/onboarding/onboarding_dark_test.dart',
  'test/features/onboarding/onboarding_setup_test.dart',
  'test/features/onboarding/onboarding_tour_test.dart',
  'test/features/onboarding/onboarding_welcome_test.dart',
  'test/features/onboarding/tour_anchor_test.dart',
  'test/features/onboarding/tour_geometry_test.dart',
];

const List<String> _keptFiles = <String>[
  'lib/features/onboarding/onboarding_gate.dart',
  'lib/features/onboarding/setup/week_start_suggestion.dart',
  'test/features/onboarding/onboarding_gate_test.dart',
  'test/features/onboarding/week_start_suggestion_test.dart',
];

const List<String> _removedNames = <String>[
  'OnboardingWelcome',
  'OnboardingAppearance',
  'OnboardingTour',
  'OnboardingSetup',
  'TourAnchor',
  'TourTarget',
  'tourTips',
  'SetupOutcome',
];

final RegExp _removedName = RegExp('\\b(?:${_removedNames.join('|')})\\b');

String _normalised(String path) => p.posix.joinAll(p.split(path));

List<String> _textFilesUnder(String root) {
  final Directory directory = Directory(root);
  if (!directory.existsSync()) {
    return const <String>[];
  }
  return <String>[
    for (final FileSystemEntity entity in directory.listSync(
      recursive: true,
      followLinks: false,
    ))
      if (entity is File &&
          !_binaryExtensions.contains(p.extension(entity.path).toLowerCase()))
        _normalised(entity.path),
  ]..sort();
}

List<String> _scannedFiles() => <String>[
  for (final String root in _roots)
    for (final String path in _textFilesUnder(root))
      if (path != _self) path,
];

List<String> _linesOf(String path) => const LineSplitter().convert(
  utf8.decode(File(path).readAsBytesSync(), allowMalformed: true),
);

void main() {
  test('the old onboarding files and names are gone', () {
    final List<String> scanned = _scannedFiles();
    expect(scanned, contains('lib/features/onboarding/onboarding_host.dart'));
    expect(scanned, isNot(contains(_self)));
    for (final String kept in _keptFiles) {
      expect(File(kept).existsSync(), isTrue, reason: kept);
    }

    final List<String> present = <String>[
      for (final String path in _deletedFiles)
        if (File(path).existsSync()) path,
    ];

    final List<String> offences = <String>[
      for (final String path in scanned)
        for (final (int index, String line) in _linesOf(path).indexed)
          for (final RegExpMatch match in _removedName.allMatches(line))
            '$path:${index + 1}: ${match.group(0)}',
    ];

    expect(present, isEmpty, reason: present.join('\n'));
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('the onboarding barrel exports only the new flow', () {
    final List<String> exports = <String>[
      for (final String line in File(
        'lib/features/onboarding/onboarding.dart',
      ).readAsLinesSync())
        if (line.trim().isNotEmpty) line.trim(),
    ];
    expect(
      exports,
      unorderedEquals(<String>[
        "export 'onboarding_chapter.dart';",
        "export 'onboarding_controller.dart';",
        "export 'onboarding_frame.dart';",
        "export 'onboarding_gate.dart';",
        "export 'onboarding_host.dart';",
        "export 'onboarding_surface.dart';",
        "export 'reminder_choice.dart';",
      ]),
    );
  });
}
