import 'flower_kind.dart';

export 'flower_kind.dart';

enum Mood {
  happy('happy', 'Happy', FlowerKind.peony),
  love('love', 'Loved', FlowerKind.rose),
  warm('warm', 'Warm', FlowerKind.sunflower),
  grateful('grateful', 'Grateful', FlowerKind.chrysanthemum),
  hopeful('hopeful', 'Hopeful', FlowerKind.daffodil),
  calm('calm', 'Calm', FlowerKind.lavender),
  anxious('anxious', 'Anxious', FlowerKind.aster),
  tired('tired', 'Tired', FlowerKind.poppy),
  sad('sad', 'Sad', FlowerKind.bleedingHeart),
  angry('angry', 'Angry', FlowerKind.redSpiderLily);

  const Mood(this.id, this.label, this.flower);

  final String id;
  final String label;
  final FlowerKind flower;

  static Mood? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final mood in Mood.values) {
      if (mood.id == id) {
        return mood;
      }
    }
    return null;
  }
}

const List<Mood> moodOrder = <Mood>[
  Mood.happy,
  Mood.love,
  Mood.warm,
  Mood.grateful,
  Mood.hopeful,
  Mood.calm,
  Mood.anxious,
  Mood.tired,
  Mood.sad,
  Mood.angry,
];
