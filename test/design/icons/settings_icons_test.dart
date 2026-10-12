import 'dart:ui' as ui;

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Case {
  const _Case(this.size, this.color, this.strokeWidth);

  final double size;
  final Color color;
  final double? strokeWidth;
}

const double _sampleStep = 0.01;
const double _extentTolerance = 0.02;

final List<_Case> _cases = <_Case>[
  const _Case(18, Palette.coral, null),
  _Case(20, FieldNotesColors.light.ink, null),
  _Case(42, FieldNotesColors.dark.accentInk, 2.2),
];

const Map<SettingsGlyph, Rect> _extents = <SettingsGlyph, Rect>{
  SettingsGlyph.book: Rect.fromLTRB(5, 4.5, 18, 20),
  SettingsGlyph.flip: Rect.fromLTRB(3, 2.1513, 21, 21.8487),
  SettingsGlyph.bell: Rect.fromLTRB(4.5, 5, 19.5, 22.5),
  SettingsGlyph.archive: Rect.fromLTRB(3.5, 4.5, 20.5, 19.5),
  SettingsGlyph.info: Rect.fromLTRB(3.5, 3.5, 20.5, 20.5),
  SettingsGlyph.download: Rect.fromLTRB(5, 4, 19, 20),
};

Rect _traced(List<Path> paths) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Path path in paths) {
    for (final ui.PathMetric metric in path.computeMetrics()) {
      for (double at = 0; at < metric.length + _sampleStep; at += _sampleStep) {
        final Offset point = metric
            .getTangentForOffset(at > metric.length ? metric.length : at)!
            .position;
        left = point.dx < left ? point.dx : left;
        top = point.dy < top ? point.dy : top;
        right = point.dx > right ? point.dx : right;
        bottom = point.dy > bottom ? point.dy : bottom;
      }
    }
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

Future<void> _pumpIcon(
  WidgetTester tester,
  SettingsGlyph glyph,
  _Case sample,
) async {
  final SettingsIcon icon = sample.strokeWidth == null
      ? SettingsIcon(glyph, size: sample.size, color: sample.color)
      : SettingsIcon(
          glyph,
          size: sample.size,
          color: sample.color,
          strokeWidth: sample.strokeWidth!,
        );
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Center(
          child: Semantics(container: true, label: 'icon host', child: icon),
        ),
      ),
    ),
  );
}

List<RecordedInvocation> _record(WidgetTester tester, double size) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(SettingsIcon),
      matching: find.byType(CustomPaint),
    ),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  paint.painter!.paint(canvas, Size.square(size));
  return canvas.invocations;
}

void main() {
  testWidgets('every settings glyph paints a stroked line drawing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1140, 726);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final SemanticsHandle semantics = tester.ensureSemantics();

    expect(SettingsGlyph.values, <SettingsGlyph>[
      SettingsGlyph.book,
      SettingsGlyph.flip,
      SettingsGlyph.bell,
      SettingsGlyph.archive,
      SettingsGlyph.info,
      SettingsGlyph.download,
    ]);

    for (final SettingsGlyph glyph in SettingsGlyph.values) {
      for (final _Case sample in _cases) {
        final String label = '$glyph at ${sample.size}';
        await _pumpIcon(tester, glyph, sample);

        expect(
          tester.getSize(find.byType(SettingsIcon)),
          Size.square(sample.size),
          reason: label,
        );
        expect(
          tester.getSize(
            find.descendant(
              of: find.byType(SettingsIcon),
              matching: find.byType(CustomPaint),
            ),
          ),
          Size.square(sample.size),
          reason: label,
        );

        final List<RecordedInvocation> calls = _record(tester, sample.size);
        final List<RecordedInvocation> scales = calls
            .where(
              (RecordedInvocation call) => call.invocation.memberName == #scale,
            )
            .toList();
        expect(scales, hasLength(1), reason: label);
        expect(
          scales.single.invocation.positionalArguments.first as double,
          closeTo(sample.size / 24, 1e-9),
          reason: label,
        );

        final List<Paint> paints = <Paint>[
          for (final RecordedInvocation call in calls)
            ...call.invocation.positionalArguments.whereType<Paint>(),
        ];
        expect(paints, isNotEmpty, reason: label);
        for (final Paint used in paints) {
          expect(used.style, PaintingStyle.stroke, reason: label);
          expect(used.color.toARGB32(), sample.color.toARGB32(), reason: label);
          expect(
            used.strokeWidth,
            closeTo(sample.strokeWidth ?? 1.8, 1e-6),
            reason: label,
          );
          expect(used.strokeCap, StrokeCap.round, reason: label);
          expect(used.strokeJoin, StrokeJoin.round, reason: label);
        }

        final List<Path> paths = <Path>[
          for (final RecordedInvocation call in calls)
            if (call.invocation.memberName == #drawPath)
              call.invocation.positionalArguments.first as Path,
        ];
        expect(paths, isNotEmpty, reason: label);
        final Rect traced = _traced(paths);
        final Rect expected = _extents[glyph]!;
        expect(
          traced.left,
          closeTo(expected.left, _extentTolerance),
          reason: label,
        );
        expect(
          traced.top,
          closeTo(expected.top, _extentTolerance),
          reason: label,
        );
        expect(
          traced.right,
          closeTo(expected.right, _extentTolerance),
          reason: label,
        );
        expect(
          traced.bottom,
          closeTo(expected.bottom, _extentTolerance),
          reason: label,
        );

        expect(
          find.descendant(
            of: find.byType(SettingsIcon),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
          reason: label,
        );
        final SemanticsNode host = tester.getSemantics(
          find.bySemanticsLabel('icon host'),
        );
        expect(host.label, 'icon host', reason: label);
        expect(host.childrenCount, 0, reason: label);
      }
    }
    semantics.dispose();
  });
}
