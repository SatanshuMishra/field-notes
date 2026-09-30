import 'package:flutter/painting.dart';
import 'package:field_notes/design/flowers/flower_palette.dart';
import 'package:field_notes/domain/mood/mood.dart';

enum MeadowSceneMode { page, study, full }

class MeadowRange {
  const MeadowRange({
    required this.first,
    required this.last,
    required this.key,
  });

  final int first;
  final int last;
  final String key;

  @override
  bool operator ==(Object other) =>
      other is MeadowRange &&
      other.first == first &&
      other.last == last &&
      other.key == key;

  @override
  int get hashCode => Object.hash(first, last, key);
}

const Color meadowSproutChipColour = Color(0xFF9FB07A);

Color meadowChipColour(Mood mood) {
  switch (mood) {
    case Mood.happy:
      return FlowerColors.peonyPetalMid;
    case Mood.love:
      return FlowerColors.roseDisc;
    case Mood.warm:
      return FlowerColors.sunflowerRay;
    case Mood.grateful:
      return FlowerColors.chrysanthemumOuter;
    case Mood.hopeful:
      return const Color(0xFFEFD46E);
    case Mood.calm:
      return FlowerColors.lavenderPetal;
    case Mood.anxious:
      return FlowerColors.asterRayPale;
    case Mood.tired:
      return FlowerColors.poppyLobe;
    case Mood.sad:
      return FlowerColors.bleedingHeartLobe;
    case Mood.angry:
      return const Color(0xFFC62F24);
  }
}
