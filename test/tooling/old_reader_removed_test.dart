import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:field_notes/domain/notes/markdown/markdown.dart';

import '../features/notes/support/notes_harness.dart';

const List<String> _roots = <String>['lib', 'test', 'integration_test', 'tool'];

const String _parityDirectory = 'test/features/note_engine/parity/';

const List<String> _deletedFiles = <String>[
  'lib/features/notes/render/photo_wrap_block.dart',
  'lib/features/notes/render/float_split_cache.dart',
  'lib/features/notes/render/note_photo_plan.dart',
  'lib/features/notes/render/note_render_budget.dart',
  'lib/features/entry_cards/notes/note_document.dart',
  'lib/features/entry_cards/notes/note_block_widgets.dart',
  'lib/features/entry_cards/notes/note_inline_span.dart',
  'lib/features/entry_cards/notes/inline_span_slice.dart',
  'lib/features/notes/model/photo_placement.dart',
  'lib/features/notes/photos/photo_line_edits.dart',
  'lib/features/notes/photos/photo_placement_diagram.dart',
  'test/features/notes/render/float_split_cache_test.dart',
  'test/features/notes/render/float_plan_table_test.dart',
  'test/features/entry_cards/notes/note_document_test.dart',
  'test/features/entry_cards/notes/inline_span_slice_test.dart',
  'test/features/notes/model/photo_placement_test.dart',
  'test/features/notes/photos/photo_line_edits_test.dart',
];

const Set<String> _removedSegments = <String>{
  'photo_wrap_block.dart',
  'float_split_cache.dart',
  'note_photo_plan.dart',
  'note_render_budget.dart',
  'note_document.dart',
  'note_block_widgets.dart',
  'note_inline_span.dart',
  'inline_span_slice.dart',
  'photo_placement.dart',
  'photo_line_edits.dart',
  'photo_placement_diagram.dart',
};

const List<String> _removedNames = <String>[
  'PhotoWrapBlock',
  'measureFloatSplit',
  'photoWrapFloatKey',
  'photoWrapFigureKey',
  'photoWrapHeadKey',
  'photoWrapTailKey',
  'FloatSplit',
  'FloatSplitCache',
  'floatBandBucket',
  'floatBandBucketEm',
  'floatBandWidth',
  'floatSplitHysteresisLines',
  'floatSplitCacheCapacity',
  'floatEdgeTolerance',
  'lineStartsBeside',
  'PhotoPlan',
  'PhotoSizeFloat',
  'planFloat',
  'canFloatAt',
  'noteMeasureFor',
  'photoFloatCap',
  'photoGutterEm',
  'photoBandResidualEm',
  'photoMinFloatEm',
  'photoFallbackAspect',
  'photoLineEm',
  'photoAspectOf',
  'photoHeightClamp',
  'NoteRenderBudget',
  'StackedPhoto',
  'NotePhotoFigure',
  'notePhotoTiltDegrees',
  'notePhotoTiltsDegrees',
  'notePhotoFitScale',
  'notePhotoUnavailableLabel',
  'notePhotoSemanticsLabel',
  'notePhotoFrameKey',
  'notePhotoUnavailableKey',
  'notePhotoCaptionGap',
  'notePhotoUnavailableHeight',
  'NoteDocument',
  'NoteBlockRun',
  'noteBlockRuns',
  'NoteSelectionScope',
  'NoteSelectionDelegate',
  'NoteBlockView',
  'NoteParagraphView',
  'NoteHeadingView',
  'NoteBulletView',
  'NoteNumberView',
  'NoteQuoteView',
  'NoteCodeView',
  'NoteDividerView',
  'NotePhotoStub',
  'NoteListItem',
  'noteBlockGapEm',
  'noteEmOf',
  'noteHeadingStyle',
  'noteQuoteStyle',
  'noteCodeBlockStyle',
  'noteParagraphGapEm',
  'noteListItemGapEm',
  'noteHeadingGapEm',
  'noteListMarkerEm',
  'noteQuoteRuleWidth',
  'noteQuoteInsetEm',
  'noteCodePaddingEm',
  'noteCodeScale',
  'notePhotoStubWidthFraction',
  'notePhotoStubAspectRatio',
  'noteInlineCodeScale',
  'noteBoldStyle',
  'noteItalicStyle',
  'noteStrikeStyle',
  'noteLinkStyle',
  'noteInlineCodeStyle',
  'noteStyleFor',
  'buildNoteInlineSpan',
  'sliceInlineSpan',
  'plainLengthOf',
  'PhotoSide',
  'PhotoSize',
  'PhotoPlacement',
  'PhotoBlockPlacement',
  'defaultPhotoSide',
  'defaultPhotoSize',
  'photoLineFor',
  'NotePhotoLine',
  'RemovedPhotoLine',
  'PhotoLineRemoval',
  'notePhotoLines',
  'photoLineIndexAtCaret',
  'photoLineIndexIn',
  'photoLineAtCaret',
  'insertPhotoLinesAtCaret',
  'selectPhotoLine',
  'removePhotoLine',
  'restorePhotoLine',
  'PhotoPlacementDiagram',
  'PhotoDiagramPainter',
  'photoPlacementSentence',
  'photoDiagramWidth',
  'photoDiagramHeight',
  'photoStackedDescription',
  'photoFloatedDescription',
];

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+(?:'([^']*)'|"([^"]*)")''',
);

final RegExp _removedName = RegExp('\\b(?:${_removedNames.join('|')})\\b');

final RegExp _notePhotoBlockImport = RegExp(
  r'''(?:^|\n)\s*import\s+['"][^'"]*note_photo_block\.dart['"][^;]*;''',
);

final RegExp _whitespace = RegExp(r'\s+');

final RegExp _topLevelClass = RegExp(
  r'^(?:abstract |base |final |sealed |interface |mixin )*(?:class|mixin|enum|extension|typedef)\s+(\w+)',
);

final RegExp _topLevelValue = RegExp(r'^[^\s(][^=(]*?\b(\w+)\s*(?:=|\()');

String _normalised(String path) => p.posix.joinAll(p.split(path));

List<String> _dartFilesUnder(String root) {
  final Directory directory = Directory(root);
  if (!directory.existsSync()) {
    return const <String>[];
  }
  return <String>[
    for (final FileSystemEntity entity in directory.listSync(
      recursive: true,
      followLinks: false,
    ))
      if (entity is File && entity.path.endsWith('.dart'))
        _normalised(entity.path),
  ]..sort();
}

bool _quotesOldNames(String path) =>
    path.startsWith(_parityDirectory) ||
    (path.startsWith('test/tooling/old_') && path.endsWith('.dart'));

List<String> _scannedFiles() => <String>[
  for (final String root in _roots)
    for (final String path in _dartFilesUnder(root))
      if (!_quotesOldNames(path)) path,
];

String? _directiveUri(String line) {
  final RegExpMatch? match = _directive.firstMatch(line);
  return match == null ? null : match.group(1) ?? match.group(2);
}

List<String> _nonBlankLines(String path) => <String>[
  for (final String line in File(path).readAsLinesSync())
    if (line.trim().isNotEmpty) line,
];

List<String> _topLevelDeclarations(String path) => <String>[
  for (final String line in File(path).readAsLinesSync())
    if (line.isNotEmpty &&
        !line.startsWith(' ') &&
        !line.startsWith('}') &&
        !line.startsWith('import ') &&
        !line.startsWith('export ') &&
        !line.startsWith('@'))
      _topLevelClass.firstMatch(line)?.group(1) ??
          _topLevelValue.firstMatch(line)?.group(1) ??
          line,
];

void main() {
  test('no source references the old reader or the old photo model', () {
    final List<String> scanned = _scannedFiles();
    expect(scanned, isNotEmpty);

    final List<String> present = <String>[
      for (final String path in _deletedFiles)
        if (File(path).existsSync()) path,
    ];

    final List<String> offences = <String>[
      for (final String path in scanned)
        for (final (int index, String line) in File(
          path,
        ).readAsLinesSync().indexed) ...<String>[
          if (_directiveUri(line) case final String uri
              when _removedSegments.contains(uri.split('/').last))
            '$path:${index + 1}: $uri',
          for (final RegExpMatch match in _removedName.allMatches(line))
            '$path:${index + 1}: ${match.group(0)}',
        ],
    ];

    expect(present, isEmpty, reason: present.join('\n'));
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('the notes barrels export only what survives', () {
    expect(_nonBlankLines('lib/features/notes/notes.dart'), <String>[
      "export 'notes_providers.dart';",
      "export 'render/note_photo_block.dart';",
    ]);

    final List<String> entryCardExports = <String>[
      for (final String line in File(
        'lib/features/entry_cards/entry_cards.dart',
      ).readAsLinesSync())
        if (_directiveUri(line) != null && line.trimLeft().startsWith('export'))
          _directiveUri(line)!,
    ];
    expect(entryCardExports, hasLength(17));
    expect(
      entryCardExports.where((String uri) => uri.startsWith('notes/')),
      isEmpty,
    );
  });

  test(
    'note_photo_block.dart keeps only the media scope and caption style',
    () {
      const String path = 'lib/features/notes/render/note_photo_block.dart';
      final List<String> imports = <String>[
        for (final String line in File(path).readAsLinesSync())
          if (line.trimLeft().startsWith('import')) ?_directiveUri(line),
      ];
      expect(imports, <String>[
        'package:flutter/widgets.dart',
        'package:field_notes/design/tokens/tokens.dart',
        'package:field_notes/features/entry_cards/media/media_resolver.dart',
      ]);
      expect(
        _topLevelDeclarations(path),
        unorderedEquals(<String>[
          'NoteMediaScope',
          'notePhotoCaptionStyle',
          'notePhotoCaptionAlign',
        ]),
      );
    },
  );

  test('the engine reaches the old notes code only for NoteMediaScope', () {
    final List<String> engineFiles = _dartFilesUnder(
      'lib/features/note_engine',
    );
    expect(engineFiles, isNotEmpty);
    final List<String> offences = <String>[
      for (final String path in engineFiles)
        for (final (int index, String line) in File(
          path,
        ).readAsLinesSync().indexed)
          if (_directiveUri(line) case final String uri
              when uri.endsWith('domain/notes/notes.dart') ||
                  uri.endsWith('features/notes/notes.dart') ||
                  uri.endsWith('capture/text/editor/editor.dart'))
            '$path:${index + 1}: $uri',
    ];
    expect(offences, isEmpty, reason: offences.join('\n'));

    final List<String> scopeImports = <String>[
      for (final String path in engineFiles)
        for (final RegExpMatch match in _notePhotoBlockImport.allMatches(
          File(path).readAsStringSync(),
        ))
          '$path: ${match.group(0)!.trim().replaceAll(_whitespace, ' ')}',
    ];
    expect(scopeImports, isNotEmpty);
    for (final String entry in scopeImports) {
      expect(
        entry.substring(entry.indexOf(': ') + 2),
        "import 'package:field_notes/features/notes/render/note_photo_block.dart' "
        'show NoteMediaScope;',
        reason: entry,
      );
    }
  });

  test('the harness writes photo lines through the grammar', () {
    expect(photoLine(photoIdA), '![](photo/a1b2c3d4e5f6 "right medium")');
    expect(
      photoLine(
        photoIdB,
        caption: 'Low tide',
        side: MdPhotoSide.left,
        size: MdPhotoSize.large,
      ),
      '![Low tide](photo/b2c3d4e5f6a1 "left large")',
    );
  });
}
