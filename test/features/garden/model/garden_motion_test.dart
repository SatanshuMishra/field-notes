import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('animates a normal garden when reduce-motion is off', () {
    expect(
      resolveGardenMotion(reduceMotion: false, bloomCount: 30),
      GardenMotionProfile.full,
    );
  });

  test('reduce-motion always wins, even for a tiny garden', () {
    expect(
      resolveGardenMotion(reduceMotion: true, bloomCount: 1),
      GardenMotionProfile.reduced,
    );
  });

  test('degrades past the animated cap', () {
    expect(
      resolveGardenMotion(
        reduceMotion: false,
        bloomCount: defaultMaxAnimatedBlooms + 1,
      ),
      GardenMotionProfile.reduced,
    );
    expect(
      resolveGardenMotion(
        reduceMotion: false,
        bloomCount: defaultMaxAnimatedBlooms,
      ),
      GardenMotionProfile.full,
    );
  });

  test('honours a custom cap', () {
    expect(
      resolveGardenMotion(
        reduceMotion: false,
        bloomCount: 51,
        maxAnimatedBlooms: 50,
      ),
      GardenMotionProfile.reduced,
    );
  });

  test('animates an empty garden rather than degrading it', () {
    expect(
      resolveGardenMotion(reduceMotion: false, bloomCount: 0),
      GardenMotionProfile.full,
    );
  });
}
