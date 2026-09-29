import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TourTarget { nav, calendar, mood, capture, settings }

class TourAnchors {
  TourAnchors()
    : _keys = <TourTarget, GlobalKey>{
        for (final TourTarget target in TourTarget.values)
          target: GlobalKey(debugLabel: 'tourAnchor.${target.name}'),
      };

  final Map<TourTarget, GlobalKey> _keys;

  GlobalKey keyFor(TourTarget target) => _keys[target]!;

  Rect? rectOf(TourTarget target, RenderBox ancestor) {
    final BuildContext? context = _keys[target]!.currentContext;
    if (context == null) {
      return null;
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    final Offset origin = renderObject.localToGlobal(
      Offset.zero,
      ancestor: ancestor,
    );
    return origin & renderObject.size;
  }
}

final Provider<TourAnchors> tourAnchorsProvider = Provider<TourAnchors>(
  (Ref ref) => TourAnchors(),
);

class TourAnchor extends ConsumerWidget {
  const TourAnchor({super.key, required this.target, required this.child});

  final TourTarget target;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TourAnchors? anchors;
    try {
      anchors = ref.watch(tourAnchorsProvider);
    } on StateError {
      anchors = null;
    }
    if (anchors == null) {
      return child;
    }
    return KeyedSubtree(key: anchors.keyFor(target), child: child);
  }
}
