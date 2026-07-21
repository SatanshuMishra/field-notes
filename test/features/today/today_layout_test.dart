import 'package:field_notes/features/today/today_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop gets the right rail and phone does not', () {
    expect(resolveTodayLayout(TargetPlatform.macOS), TodayLayout.withRail);
    expect(resolveTodayLayout(TargetPlatform.android), TodayLayout.stacked);
    expect(resolveTodayLayout(TargetPlatform.iOS), TodayLayout.stacked);
  });
}
