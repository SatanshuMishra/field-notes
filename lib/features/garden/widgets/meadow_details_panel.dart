import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/dashed_divider.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';

const double meadowDetailsPanelWidth = 380;
const double meadowDetailsPanelInset = 12;
const double meadowDetailsPanelReserve = meadowDetailsPanelWidth + 16;
const Duration meadowDetailsPanelSlide = Duration(milliseconds: 320);
const Duration meadowDetailsPanelFade = Duration(milliseconds: 200);
const String meadowDetailsKeysHint =
    'D details · F full screen · ← → year · Esc close';
const ValueKey<String> meadowDetailsPanelKey = ValueKey<String>(
  'meadow-details-panel',
);

const BorderRadius _panelRadius = BorderRadius.all(Radius.circular(18));
const List<BoxShadow> _panelShadows = <BoxShadow>[
  BoxShadow(
    color: Color.fromRGBO(20, 12, 6, 0.6),
    offset: Offset(0, 20),
    blurRadius: 44,
    spreadRadius: -16,
  ),
];

class MeadowDetailsPanel extends StatefulWidget {
  const MeadowDetailsPanel({
    super.key,
    required this.open,
    required this.child,
  });

  final bool open;
  final Widget child;

  @override
  State<MeadowDetailsPanel> createState() => _MeadowDetailsPanelState();
}

class _MeadowDetailsPanelState extends State<MeadowDetailsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: meadowDetailsPanelSlide,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(MeadowDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open == widget.open) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _motion.forward();
    } else {
      _motion.reverse();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Widget panel = MeadowChromeBlock(
      child: DecoratedBox(
        key: meadowDetailsPanelKey,
        decoration: BoxDecoration(
          color: colors.cardWarm,
          border: Border.all(color: colors.line, width: Shapes.outlineWidth),
          borderRadius: _panelRadius,
          boxShadow: _panelShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Shapes.outlineWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: widget.child),
              DashedDivider(
                thickness: 1,
                color: colors.ink18,
                dashLength: 3,
                dashGap: 3,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Text(
                  meadowDetailsKeysHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.captionSans.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _motion,
      child: panel,
      builder: (BuildContext context, Widget? child) {
        final double value = _motion.value;
        if (value == 0) {
          return const SizedBox.shrink();
        }
        final double slide = meadowEase.transform(value);
        final double fade =
            (value *
                    meadowDetailsPanelSlide.inMilliseconds /
                    meadowDetailsPanelFade.inMilliseconds)
                .clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: !widget.open,
          child: ExcludeSemantics(
            excluding: !widget.open,
            child: ExcludeFocus(
              excluding: !widget.open,
              child: FractionalTranslation(
                translation: Offset(
                  (1 - slide) *
                      (meadowDetailsPanelWidth + 24) /
                      meadowDetailsPanelWidth,
                  0,
                ),
                child: Opacity(opacity: fade, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
