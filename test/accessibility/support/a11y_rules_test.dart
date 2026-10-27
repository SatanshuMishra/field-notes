import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_rules.dart';
import 'a11y_state.dart';

const Key _plantedKey = ValueKey<String>('planted');

void _noop() {}

class _Example {
  const _Example({
    required this.name,
    required this.planted,
    required this.prefix,
    required this.fixed,
    this.stateful = const <A11yStatefulControl>[],
  });

  final String name;
  final Widget planted;
  final String prefix;
  final Widget fixed;
  final List<A11yStatefulControl> stateful;
}

Widget _box(double width, double height, [Widget? child]) =>
    SizedBox(width: width, height: height, child: child);

final List<_Example> _examples = <_Example>[
  _Example(
    name: 'unlabelled card button',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      onTap: _noop,
      child: GestureDetector(onTap: _noop, child: _box(200, 80)),
    ),
    prefix: 'unlabelled-tap | planted | <unlabelled> | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Open entry',
      onTap: _noop,
      child: _box(200, 80),
    ),
  ),
  _Example(
    name: 'doubled pill button',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Edit note',
      onTap: _noop,
      child: GestureDetector(onTap: _noop, child: _box(64, 64)),
    ),
    prefix: 'doubled-target | planted | Edit note | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Edit note',
      onTap: _noop,
      child: _box(64, 64),
    ),
  ),
  _Example(
    name: 'repeated prompt label',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label:
          'How are you feeling today?\nPeony\nHow are you feeling today?\n'
          'tap to plant today\'s bloom',
      onTap: _noop,
      child: _box(300, 64),
    ),
    prefix:
        'repeated-text | planted | How are you feeling today? / Peony / '
        'How are you feeling today? / tap to plant today\'s bloom | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'How are you feeling today?\ntap to plant today\'s bloom',
      onTap: _noop,
      child: _box(300, 64),
    ),
  ),
  _Example(
    name: 'tappable text with no role',
    planted: GestureDetector(
      key: _plantedKey,
      onTap: _noop,
      child: _box(120, 48, const Text('Cancel')),
    ),
    prefix: 'missing-role | planted | Cancel | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      child: GestureDetector(
        onTap: _noop,
        child: _box(120, 48, const Text('Cancel')),
      ),
    ),
  ),
  _Example(
    name: 'toggle with no state',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    prefix: 'missing-state | planted | Daily reminder | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      toggled: false,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    stateful: <A11yStatefulControl>[
      A11yStatefulControl.finder(
        find.byKey(_plantedKey),
        A11yStateKind.toggled,
      ),
    ],
  ),
  _Example(
    name: 'toggle with no state, listed by label',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    prefix: 'missing-state | planted | Daily reminder | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      toggled: false,
      label: 'Daily reminder',
      onTap: _noop,
      child: _box(200, 48),
    ),
    stateful: const <A11yStatefulControl>[
      A11yStatefulControl.label('Daily reminder', A11yStateKind.toggled),
    ],
  ),
  _Example(
    name: 'tiny icon',
    planted: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Close',
      onTap: _noop,
      child: _box(24, 24),
    ),
    prefix: 'small-target | planted | Close | ',
    fixed: Semantics(
      key: _plantedKey,
      button: true,
      label: 'Close',
      onTap: _noop,
      child: _box(48, 48),
    ),
  ),
];

A11yState _planted(Widget widget, List<A11yStatefulControl> stateful) =>
    A11yState(
      id: 'planted',
      pump: (WidgetTester tester, A11yVariant variant) => tester.pumpWidget(
        MaterialApp(
          home: Material(child: Center(child: widget)),
        ),
      ),
      proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
      stateful: stateful,
    );

Future<List<A11yFinding>> _findingsOf(
  WidgetTester tester,
  Widget widget,
  List<A11yStatefulControl> stateful,
) async {
  final A11yStateResult result = await runA11yState(
    tester,
    _planted(widget, stateful),
  );
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => findings,
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

Future<List<String>> _idsOf(WidgetTester tester, Widget widget) async =>
    <String>[
      for (final A11yFinding finding in await _findingsOf(
        tester,
        KeyedSubtree(key: _plantedKey, child: widget),
        const <A11yStatefulControl>[],
      ))
        finding.id,
    ];

Widget _button(String? label, double side, {Widget? child}) => Semantics(
  container: true,
  button: true,
  label: label,
  onTap: _noop,
  child: _box(side, side, child),
);

class _InvisibleNode extends SingleChildRenderObjectWidget {
  const _InvisibleNode({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInvisibleNode();
}

class _RenderInvisibleNode extends RenderProxyBox {
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    node.updateWith(
      config: config,
      childrenInInversePaintOrder: <SemanticsNode>[
        ...children,
        SemanticsNode()
          ..rect = Rect.zero
          ..updateWith(
            config: SemanticsConfiguration()
              ..isButton = true
              ..label = 'Invisible'
              ..onTap = _noop,
          ),
      ],
    );
  }
}

List<SemanticsNode> _childrenOf(SemanticsNode node) {
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  return children;
}

const Color _ground = Color(0xFFFFFFFF);
const Color _focusRing = Color(0xFF949494);
const Color _mediaBlack = Color(0xFF0E0B09);

const A11yVariant _android = A11yVariant(platform: TargetPlatform.android);
const A11yVariant _androidAt2x = A11yVariant(
  platform: TargetPlatform.android,
  textScale: A11yTextScale.doubled,
);
const A11yVariant _macos = A11yVariant(platform: TargetPlatform.macOS);
const A11yVariant _windows = A11yVariant(platform: TargetPlatform.windows);

Widget _sized(String label, double width, double height) => Semantics(
  container: true,
  button: true,
  label: label,
  onTap: _noop,
  child: _box(width, height),
);

Widget _pair(Widget first, Widget second) => Row(
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[first, const SizedBox(width: 24), second],
);

Future<List<String>> _swept(
  WidgetTester tester,
  A11yVariant variant,
  Widget widget, {
  required Set<String> rules,
  Color ground = _ground,
  A11yPumpBody? setUp,
}) async {
  final A11yStateResult result = await runA11yState(
    tester,
    A11yState(
      id: 'planted',
      platforms: <TargetPlatform>{variant.platform},
      pump: (WidgetTester tester, A11yVariant variant) async {
        variant.useWindow(tester);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: variant.theme,
            builder: variant.scaleText,
            home: Material(
              color: ground,
              child: Center(
                child: KeyedSubtree(key: _plantedKey, child: widget),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await setUp?.call(tester, variant);
      },
      proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
    ),
    variant: variant,
    checks: A11yChecks.full,
  );
  return switch (result) {
    A11yLoaded(:final List<A11yFinding> findings) => <String>[
      for (final A11yFinding finding in findings)
        if (rules.contains(finding.rule)) finding.id,
    ],
    A11yNotLoaded(:final String message) => throw TestFailure(message),
  };
}

class _RingButton extends StatefulWidget {
  const _RingButton({required this.label, required this.ring});

  final String label;
  final Color ring;

  @override
  State<_RingButton> createState() => _RingButtonState();
}

class _RingButtonState extends State<_RingButton> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_repaint);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _repaint() => setState(() {});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: widget.label,
    onTap: _noop,
    child: Focus(
      focusNode: _focus,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ground,
          border: Border.all(
            color: _focus.hasFocus ? widget.ring : _ground,
            width: 2,
          ),
        ),
        child: _box(120, 48),
      ),
    ),
  );
}

class _TabbedHeading extends StatefulWidget {
  const _TabbedHeading();

  @override
  State<_TabbedHeading> createState() => _TabbedHeadingState();
}

class _TabbedHeadingState extends State<_TabbedHeading> {
  bool _about = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(_about ? 'About' : 'Data'),
      TextButton(
        onPressed: () => setState(() => _about = true),
        child: const Text('Show About'),
      ),
    ],
  );
}

class _StatusSwap extends StatefulWidget {
  const _StatusSwap({required this.live});

  final bool live;

  @override
  State<_StatusSwap> createState() => _StatusSwapState();
}

class _StatusSwapState extends State<_StatusSwap> {
  late final Timer _saving;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saving = Timer(
      const Duration(milliseconds: 100),
      () => setState(() => _saved = true),
    );
  }

  @override
  void dispose() {
    _saving.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: widget.live,
    child: Text(_saved ? 'Saved' : 'Saving'),
  );
}

void main() {
  testWidgets('each known problem is caught by its rule', (
    WidgetTester tester,
  ) async {
    for (final _Example example in _examples) {
      final List<String> ids = <String>[
        for (final A11yFinding finding in await _findingsOf(
          tester,
          example.planted,
          example.stateful,
        ))
          finding.id,
      ];
      expect(
        ids.any((String id) => id.startsWith(example.prefix)),
        isTrue,
        reason: '${example.name}: expected ${example.prefix} in $ids',
      );
    }
  });

  testWidgets('a widget without problems has no findings', (
    WidgetTester tester,
  ) async {
    for (final _Example example in _examples) {
      final List<String> ids = <String>[
        for (final A11yFinding finding in await _findingsOf(
          tester,
          example.fixed,
          example.stateful,
        ))
          finding.id,
      ];
      expect(ids, isEmpty, reason: example.name);
    }
  });

  testWidgets('a state whose key widget is absent fails as not loaded', (
    WidgetTester tester,
  ) async {
    final List<A11yState> states = <A11yState>[
      A11yState(
        id: 'absent-key',
        pump: (WidgetTester tester, A11yVariant variant) => tester.pumpWidget(
          const MaterialApp(
            home: Material(child: Center(child: Text('Loaded'))),
          ),
        ),
        proof: <A11yProof>[
          A11yProof(find.byKey(const ValueKey<String>('never-built'))),
        ],
      ),
      A11yState(
        id: 'too-few',
        pump: (WidgetTester tester, A11yVariant variant) => tester.pumpWidget(
          const MaterialApp(
            home: Material(child: Center(child: Text('Loaded'))),
          ),
        ),
        proof: <A11yProof>[A11yProof(find.text('Loaded'), count: 2)],
      ),
      A11yState(
        id: 'throwing-pump',
        pump: (WidgetTester tester, A11yVariant variant) async {
          throw StateError('the fixture failed');
        },
        proof: <A11yProof>[A11yProof(find.text('Loaded'))],
      ),
    ];
    for (final A11yState state in states) {
      final A11yStateResult result = await runA11yState(tester, state);
      expect(result, isA<A11yNotLoaded>(), reason: state.id);
      expect(
        (result as A11yNotLoaded).message,
        startsWith('${state.id} did not load: '),
      );
    }
  });

  testWidgets('a doubled target is reported on the later node unless only '
      'the earlier one is labelled', (WidgetTester tester) async {
    Widget doubled(String? outer, String? inner) =>
        _button(outer, 64, child: _button(inner, 64));

    expect(await _idsOf(tester, doubled('Outer', 'Inner')), <String>[
      'doubled-target | planted | Inner | Outer',
    ]);
    expect(await _idsOf(tester, doubled(null, null)), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'unlabelled-tap | planted | <unlabelled> | <root> #2',
      'doubled-target | planted | <unlabelled> | <root>',
    ]);
    expect(await _idsOf(tester, doubled('Outer', null)), <String>[
      'doubled-target | planted | Outer | <root>',
      'unlabelled-tap | planted | <unlabelled> | Outer',
    ]);
    expect(await _idsOf(tester, doubled(null, 'Inner')), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'doubled-target | planted | Inner | <root>',
    ]);
  });

  testWidgets('a repeated ID is numbered from its second occurrence', (
    WidgetTester tester,
  ) async {
    expect(
      await _idsOf(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _button(null, 48),
            _button('Close', 24),
            _button(null, 48),
            _button(null, 48),
          ],
        ),
      ),
      <String>[
        'unlabelled-tap | planted | <unlabelled> | <root>',
        'small-target | planted | Close | <root>',
        'unlabelled-tap | planted | <unlabelled> | <root> #2',
        'unlabelled-tap | planted | <unlabelled> | <root> #3',
      ],
    );
  });

  testWidgets('merged and hidden nodes are not judged', (
    WidgetTester tester,
  ) async {
    Widget unnamed({required bool hidden}) => Semantics(
      container: true,
      hidden: hidden,
      onTap: _noop,
      child: _box(48, 48),
    );

    expect(await _idsOf(tester, _button('Close', 24)), <String>[
      'small-target | planted | Close | <root>',
    ]);
    expect(
      await _idsOf(
        tester,
        MergeSemantics(
          child: _box(48, 48, Center(child: _button('Close', 24))),
        ),
      ),
      isEmpty,
    );
    expect(await _idsOf(tester, unnamed(hidden: false)), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'missing-role | planted | <unlabelled> | <root>',
    ]);
    expect(await _idsOf(tester, unnamed(hidden: true)), isEmpty);
  });

  testWidgets('an invisible node Flutter rejects is not judged', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(child: _InvisibleNode(child: _box(48, 48))),
        ),
      ),
    );
    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (FlutterError error) => error.toString(),
        'text',
        contains('Invisible SemanticsNodes should not be added to the tree.'),
      ),
    );
    expect(
      <String>[
        for (final SemanticsNode child in _childrenOf(
          tester.getSemantics(find.byType(_InvisibleNode)),
        ))
          if (child.isInvisible) child.label,
      ],
      <String>['Invisible'],
    );
    expect(a11yFindings(tester, state: 'planted'), isEmpty);
    handle.dispose();
  });

  testWidgets('an unlabelled text field is not reported as unlabelled', (
    WidgetTester tester,
  ) async {
    Widget field({required bool textField}) => Semantics(
      container: true,
      textField: textField,
      onTap: _noop,
      child: _box(200, 48),
    );

    expect(await _idsOf(tester, field(textField: true)), isEmpty);
    expect(await _idsOf(tester, field(textField: false)), <String>[
      'unlabelled-tap | planted | <unlabelled> | <root>',
      'missing-role | planted | <unlabelled> | <root>',
    ]);
  });

  testWidgets('repeated text ignores blank lines and keeps letter case', (
    WidgetTester tester,
  ) async {
    Widget labelled(String label) => Semantics(
      container: true,
      button: true,
      label: label,
      onTap: _noop,
      child: _box(200, 48),
    );

    expect(await _idsOf(tester, labelled('Walk\n\nRun\n  \nSit')), isEmpty);
    expect(await _idsOf(tester, labelled('Walk\nwalk')), isEmpty);
    expect(await _idsOf(tester, labelled(' Walk\n\nWalk ')), <String>[
      'repeated-text | planted | Walk / Walk | <root>',
    ]);
  });

  testWidgets('a small button flush against the view is judged', (
    WidgetTester tester,
  ) async {
    final A11yStateResult result = await runA11yState(
      tester,
      A11yState(
        id: 'flush',
        pump: (WidgetTester tester, A11yVariant variant) => tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: KeyedSubtree(
                  key: _plantedKey,
                  child: _button('Today', 40),
                ),
              ),
            ),
          ),
        ),
        proof: <A11yProof>[A11yProof(find.byKey(_plantedKey))],
      ),
    );
    expect(
      switch (result) {
        A11yLoaded(:final List<A11yFinding> findings) => <String>[
          for (final A11yFinding finding in findings) finding.id,
        ],
        A11yNotLoaded(:final String message) => throw TestFailure(message),
      },
      <String>['small-target | flush | Today | <root>'],
    );
  });

  testWidgets(
    'a node several render objects share is judged by their combined bounds',
    (WidgetTester tester) async {
      final List<String> ids = <String>[
        for (final A11yFinding finding in await _findingsOf(
          tester,
          KeyedSubtree(
            key: _plantedKey,
            child: SizedBox(
              width: 200,
              child: ClipRect(
                child: SizedBox(
                  height: 30,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: 80,
                    child: const TextField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const <A11yStatefulControl>[],
        ))
          finding.id,
      ];
      expect(ids, isEmpty);
    },
  );

  testWidgets('a node no render object owns is judged by its visible rect', (
    WidgetTester tester,
  ) async {
    final LongPressGestureRecognizer hold = LongPressGestureRecognizer()
      ..onLongPress = _noop;
    addTearDown(hold.dispose);
    final List<String> ids = <String>[
      for (final A11yFinding finding in await _findingsOf(
        tester,
        KeyedSubtree(
          key: _plantedKey,
          child: SizedBox(
            width: 200,
            height: 10,
            child: SingleChildScrollView(
              child: Text.rich(TextSpan(text: 'Hold me', recognizer: hold)),
            ),
          ),
        ),
        const <A11yStatefulControl>[],
      ))
        finding.id,
    ];
    expect(ids, contains('small-target | planted | Hold me | <root>'));
  });

  testWidgets('a node that reaches past its parent is judged by the part a '
      'tap can reach', (WidgetTester tester) async {
    final List<String> ids = <String>[
      for (final A11yFinding finding in await _findingsOf(
        tester,
        KeyedSubtree(
          key: _plantedKey,
          child: Semantics(
            container: true,
            child: _box(
              48,
              20,
              OverflowBox(maxHeight: 48, child: _button('Reach me', 48)),
            ),
          ),
        ),
        const <A11yStatefulControl>[],
      ))
        finding.id,
    ];
    expect(ids, contains('small-target | planted | Reach me | <root>'));
  });

  testWidgets('a node is judged by the part inside every ancestor, not only '
      'its parent', (WidgetTester tester) async {
    final List<String> ids = <String>[
      for (final A11yFinding finding in await _findingsOf(
        tester,
        KeyedSubtree(
          key: _plantedKey,
          child: Semantics(
            container: true,
            child: _box(
              48,
              20,
              OverflowBox(
                maxHeight: 48,
                child: Semantics(
                  container: true,
                  child: _box(48, 48, _button('Reach me too', 48)),
                ),
              ),
            ),
          ),
        ),
        const <A11yStatefulControl>[],
      ))
        finding.id,
    ];
    expect(ids, contains('small-target | planted | Reach me too | <root>'));
  });
  testWidgets('a windows control under 40 by 40 is a small target', (
    WidgetTester tester,
  ) async {
    expect(
      await _swept(
        tester,
        _windows,
        _pair(_sized('Square', 40, 40), _sized('Short', 40, 39)),
        rules: <String>{'small-target'},
      ),
      <String>['small-target | planted | Short | <root>'],
    );
  });

  testWidgets('a macos control under 28 by 28 is a small target', (
    WidgetTester tester,
  ) async {
    expect(
      await _swept(
        tester,
        _macos,
        _pair(_sized('Square', 28, 28), _sized('Narrow', 27, 28)),
        rules: <String>{'small-target'},
      ),
      <String>['small-target | planted | Narrow | <root>'],
    );
  });

  testWidgets('an android control under 48 dp is a small target', (
    WidgetTester tester,
  ) async {
    expect(
      await _swept(
        tester,
        _android,
        _pair(_sized('Square', 48, 48), _sized('Short', 48, 44)),
        rules: <String>{'small-target'},
      ),
      <String>['small-target | planted | Short | <root>'],
    );
  });

  testWidgets(
    'text below 4.5:1 is a contrast finding even under ExcludeSemantics',
    (WidgetTester tester) async {
      expect(
        await _swept(
          tester,
          _android,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: Text(
                  'Downloading the video',
                  style: TextStyle(fontSize: 12, color: Color(0xFF3A322B)),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Ready to play',
                style: TextStyle(fontSize: 12, color: Color(0xFFF3E6D1)),
              ),
            ],
          ),
          rules: <String>{'text-contrast', 'flutter-text-contrast'},
          ground: _mediaBlack,
        ),
        <String>['text-contrast | planted | Downloading the video | <root>'],
      );
    },
  );

  testWidgets('text of 23 px at 3.5:1 is a contrast finding', (
    WidgetTester tester,
  ) async {
    expect(
      await _swept(
        tester,
        _android,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Twenty three',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w400,
                color: Color(0xFF898989),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Twenty four',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Color(0xFF898989),
              ),
            ),
          ],
        ),
        rules: <String>{'text-contrast', 'flutter-text-contrast'},
      ),
      <String>['text-contrast | planted | Twenty three | <root>'],
    );
  });

  testWidgets('text covered by an opaque panel is not judged', (
    WidgetTester tester,
  ) async {
    expect(
      await _swept(
        tester,
        _androidAt2x,
        const SizedBox(
          width: 240,
          height: 160,
          child: Stack(
            children: <Widget>[
              Text(
                'Hidden behind the panel',
                style: TextStyle(fontSize: 14, color: Color(0xFFDDDDDD)),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: _ground,
                  child: Text(
                    'On the panel',
                    style: TextStyle(fontSize: 14, color: Color(0xFF000000)),
                  ),
                ),
              ),
            ],
          ),
        ),
        rules: <String>{'text-contrast', 'overlapping-text'},
      ),
      isEmpty,
    );
  });

  testWidgets('an overflow or ellipsis at 2x text is a finding', (
    WidgetTester tester,
  ) async {
    final Widget crowded = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 200,
          child: Row(
            children: <Widget>[
              Builder(
                builder: (BuildContext context) => SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(110),
                  child: const Text('Wide badge'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(
          width: 200,
          child: Text(
            'Saved to your meadow',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    const Set<String> rules = <String>{'overflow', 'truncated-text'};
    expect(
      await _swept(tester, _androidAt2x, crowded, rules: rules),
      unorderedEquals(<String>[
        'overflow | planted@2x | Wide badge | <root>',
        'truncated-text | planted@2x | Saved to your meadow | <root>',
      ]),
    );
    expect(await _swept(tester, _android, crowded, rules: rules), isEmpty);
  });

  testWidgets('overlapping text at 2x is a finding', (
    WidgetTester tester,
  ) async {
    const TextStyle tight = TextStyle(fontSize: 10, height: 1);
    expect(
      await _swept(
        tester,
        _androidAt2x,
        const SizedBox(
          width: 300,
          height: 200,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                child: Text('Morning walk', style: tight),
              ),
              Positioned(
                left: 0,
                top: 16,
                child: Text('Harbour fog', style: tight),
              ),
            ],
          ),
        ),
        rules: <String>{'overlapping-text'},
      ),
      <String>[
        'overlapping-text | planted@2x | Morning walk + Harbour fog | <root>',
      ],
    );
  });

  testWidgets(
    'a control whose focus paint differs below 3:1 is a focus finding',
    (WidgetTester tester) async {
      expect(
        await _swept(
          tester,
          _macos,
          _pair(
            const _RingButton(label: 'Plain', ring: _ground),
            const _RingButton(label: 'Ringed', ring: _focusRing),
          ),
          rules: <String>{'focus-visible'},
        ),
        <String>['focus-visible | planted | Plain | <root>'],
      );
    },
  );

  testWidgets('a status change with no live region is a finding', (
    WidgetTester tester,
  ) async {
    expect(
      await _swept(
        tester,
        _android,
        const _StatusSwap(live: false),
        rules: <String>{'live-region'},
      ),
      <String>['live-region | planted | Saved | <root>'],
    );
    expect(
      await _swept(
        tester,
        _android,
        const _StatusSwap(live: true),
        rules: <String>{'live-region'},
      ),
      isEmpty,
    );
  });

  testWidgets(
    "a text the state's own setup changes is not a live-region finding",
    (WidgetTester tester) async {
      expect(
        await _swept(
          tester,
          _android,
          const _TabbedHeading(),
          rules: <String>{'live-region'},
          setUp: (WidgetTester tester, A11yVariant variant) async {
            await tester.tap(find.text('Show About'));
            await tester.pump();
          },
        ),
        isEmpty,
      );
    },
  );

  testWidgets('a tappable control tab cannot reach is a keyboard finding', (
    WidgetTester tester,
  ) async {
    final Widget controls = _pair(
      Semantics(
        container: true,
        button: true,
        label: 'Hold to record',
        child: GestureDetector(onTap: _noop, child: _box(120, 48)),
      ),
      TextButton(onPressed: _noop, child: const Text('Keep this')),
    );
    expect(
      await _swept(tester, _macos, controls, rules: <String>{'keyboard'}),
      <String>['keyboard | planted | Hold to record | <root>'],
    );
    expect(
      await _swept(tester, _android, controls, rules: <String>{'keyboard'}),
      isEmpty,
    );
  });
}
