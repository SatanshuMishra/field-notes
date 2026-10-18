import 'package:field_notes/features/capture/voice/voice_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('microphone readings map to a level from 0 to 1', () {
    expect(voiceLevelFromDbfs(-160), 0);
    expect(voiceLevelFromDbfs(-50), 0);
    expect(voiceLevelFromDbfs(-30), 0.5);
    expect(voiceLevelFromDbfs(-10), 1);
    expect(voiceLevelFromDbfs(0), 1);
    expect(voiceLevelFromDbfs(double.negativeInfinity), 0);
    expect(voiceLevelFromDbfs(double.nan), 0);
  });
}
