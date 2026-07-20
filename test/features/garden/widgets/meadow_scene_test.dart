import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/garden_data.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/paint/meadow_painter.dart';
import 'package:field_notes/features/garden/widgets/meadow_scene.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<GardenBloomData> _blooms(int n) => List<GardenBloomData>.generate(
      n,
      (int i) => GardenBloomData(
        date: '2026-02-${(i + 1).toString().padLeft(2, '0')}',
        mood: moodOrder[i % moodOrder.length],
      ),
    );

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: 400, height: 300, child: child)),
    );

MeadowPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byType(CustomPaint).first).painter!
        as MeadowPainter;

void main() {
  testWidgets('renders a static, insect-free frame when reduced',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        MeadowScene(
          blooms: _blooms(6),
          motion: GardenMotionProfile.reduced,
          seed: 2026,
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(_painter(tester).showInsects, isFalse);

    final double before = _painter(tester).t;
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).t, before);
  });

  testWidgets('animates and shows insects when full',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        MeadowScene(
          blooms: _blooms(6),
          motion: GardenMotionProfile.full,
          seed: 2026,
        ),
      ),
    );

    expect(_painter(tester).showInsects, isTrue);
    final double before = _painter(tester).t;
    await tester.pump(const Duration(milliseconds: 300));
    expect(_painter(tester).t, isNot(before));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('plants one bloom per data item at the rendered size',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        MeadowScene(
          blooms: _blooms(9),
          motion: GardenMotionProfile.reduced,
          seed: 3,
        ),
      ),
    );

    expect(_painter(tester).planted, hasLength(9));
  });

  testWidgets('wraps the scene in a RepaintBoundary',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        MeadowScene(
          blooms: _blooms(6),
          motion: GardenMotionProfile.reduced,
          seed: 1,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(MeadowScene),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('stops animating when the profile degrades at runtime',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        MeadowScene(
          blooms: _blooms(6),
          motion: GardenMotionProfile.full,
          seed: 1,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(
      _host(
        MeadowScene(
          blooms: _blooms(6),
          motion: GardenMotionProfile.reduced,
          seed: 1,
        ),
      ),
    );

    final double before = _painter(tester).t;
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).t, before);
    expect(_painter(tester).showInsects, isFalse);
  });
}
