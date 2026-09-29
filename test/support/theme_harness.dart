import 'dart:io';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  TargetPlatform? platform,
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform, brightness: brightness),
      home: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

const List<String> _skippedFolders = <String>[
  'lib/design/tokens/',
  'lib/design/flowers/',
  'lib/design/art/',
];

const String _noteTypographyPath =
    'lib/features/note_engine/layout/note_typography.dart';

final RegExp _paletteToken = RegExp(
  r'\bPalette\.(?:page|pageGradientInner|pageGradientOuter|panelTop|'
  r'panelBottom|cardWarm|cardLight|cardBright|cardAlt|composerPaper|ink|'
  r'inkSoft|ink08|ink12|ink16|ink18|ink20|ink22|ink25|ink30|ink34|ink35|'
  r'ink40|coralHover|coralLink|waveMid|waveLight|sage|muted|mutedDeep|'
  r'placeholder|dashMuted|dangerSurface|focusRing|titleBar|windowTitle|'
  r'hatchLight|hatchMid|hatchDark)\b',
);

final RegExp _typographyToken = RegExp(
  r'\bTypographyTokens\.(?!(?:serif|sans|accent|mono)\b)[a-z]\w*',
);

final RegExp _shadowToken = RegExp(
  r'\bShadows\.(?:chip|cellFilled|control|cardDefault|emphasis|phoneAction|'
  r'hero|heroSoft|card|button)\b',
);

final RegExp _outlineToken = RegExp(r'\bShapes\.outline(?!Width)');

final RegExp _colorLiteral = RegExp(r'\bColor\(\s*0[xX]([0-9A-Fa-f]{8})\s*\)');

const Set<String> _lightOnlyHex = <String>{
  'D9CBB2',
  'E6D8BF',
  'CDBD9F',
  'EFE2CE',
  'E9DCC4',
  'F8EFE0',
  'FFF5EA',
  'FFFAF1',
  'F6EFE0',
  'FBF3E4',
  'F3E7D4',
  'E4D6BF',
  'ECDFC8',
  'E2D3BA',
  'D9C9AE',
  'FBECEA',
  '4A3B2E',
  '6A5C4A',
  'A08A70',
  '8A7358',
  '7D6A52',
  '6F6254',
  'B3A58C',
  'C3B39A',
  'A3866A',
  '7D8450',
  'B45C44',
  '9A4832',
  'DCAE9A',
  'E3C4B2',
};

List<String> lightOnlyTokenUses(List<String> paths) {
  final List<String> files = <String>[
    for (final String path in paths) ..._dartFilesUnder(path),
  ]..sort();
  return <String>[
    for (final String file in files.toSet()) ..._lightOnlyUsesIn(file),
  ];
}

Iterable<String> _dartFilesUnder(String path) {
  final Iterable<String> candidates = FileSystemEntity.isFileSync(path)
      ? <String>[path]
      : Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .map((File file) => file.path);
  return candidates
      .map(
        (String candidate) => p.posix.joinAll(p.split(p.relative(candidate))),
      )
      .where(
        (String candidate) =>
            candidate.endsWith('.dart') &&
            !candidate.endsWith('.g.dart') &&
            !_skippedFolders.any(candidate.startsWith),
      );
}

Iterable<String> _lightOnlyUsesIn(String file) sync* {
  final bool skipTypography = file == _noteTypographyPath;
  final List<String> lines = File(file).readAsLinesSync();
  for (int index = 0; index < lines.length; index++) {
    final String line = lines[index];
    final List<Match> matches = <Match>[
      ..._paletteToken.allMatches(line),
      if (!skipTypography) ..._typographyToken.allMatches(line),
      ..._shadowToken.allMatches(line),
      ..._outlineToken.allMatches(line),
      for (final Match match in _colorLiteral.allMatches(line))
        if (_lightOnlyHex.contains(match[1]!.substring(2).toUpperCase())) match,
    ]..sort((Match a, Match b) => a.start.compareTo(b.start));
    for (final Match match in matches) {
      yield '$file:${index + 1}: ${match[0]}';
    }
  }
}
