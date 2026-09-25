import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';

import '../model/garden_data.dart';
import '../model/garden_motion.dart';
import 'meadow_scene.dart';
import 'mood_tally_chips.dart';

class GardenView extends StatelessWidget {
  const GardenView({
    super.key,
    required this.blooms,
    required this.tally,
    required this.year,
    this.motionOverride,
    this.sprouts = const <String>[],
  });

  final List<GardenBloomData> blooms;
  final List<MoodTallyEntry> tally;
  final int year;
  final GardenMotionProfile? motionOverride;
  final List<String> sprouts;

  @override
  Widget build(BuildContext context) {
    if (blooms.isEmpty && sprouts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyStatePlaceholder(
            icon: FlowerBloom(kind: FlowerKind.daffodil, size: 44),
            message: 'Your meadow is waiting. Every day you journal plants a '
                'bloom here.',
            messageStyle: TypographyTokens.bodySerif,
          ),
        ),
      );
    }

    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final GardenMotionProfile motion = motionOverride ??
        resolveGardenMotion(
          reduceMotion: reduceMotion,
          bloomCount: blooms.length + sprouts.length,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: MeadowScene(
            blooms: blooms,
            motion: motion,
            seed: year,
            sprouts: sprouts,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: MoodTallyChips(entries: tally, sproutCount: sprouts.length),
        ),
      ],
    );
  }
}
