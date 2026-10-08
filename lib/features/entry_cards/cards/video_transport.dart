import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';

const String videoTransportBusyNotice = "Can't start this video right now";
const String videoTransportBusyHint = 'Tap to try again';

class VideoTransportBusyNotice extends StatelessWidget {
  const VideoTransportBusyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: videoTransportBusyNotice,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.cardWarm,
          border: context.shadows.outline,
          borderRadius: Shapes.buttonBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExcludeSemantics(
            child: Text(
              videoTransportBusyNotice,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: context.textStyles.captionSans,
            ),
          ),
        ),
      ),
    );
  }
}
