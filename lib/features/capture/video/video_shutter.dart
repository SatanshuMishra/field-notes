import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/capture/immersive/capture_button.dart';

typedef VideoShutterForm = CaptureButtonForm;
typedef VideoCountdownRingPainter = CaptureCountdownRingPainter;

ValueKey<String> videoShutterFormKey(VideoShutterForm form) =>
    ValueKey<String>('video-shutter-form-${form.name}');

const Color _shutterRing = Color(0xEBF3E6D1);
const Color _shutterPauseInk = Color(0xFFFFFFFF);

const double _sidebarShutter = 80;
const double _bottomBarShutter = 72;
const double _sidebarShutterDot = 30;
const double _bottomBarShutterDot = 27;
const double _countdownDotShare = 2 / 3;
const double _sidebarStopSquare = 26;
const double _bottomBarStopSquare = 24;
const double _stopSquareRadius = 5;
const double _shutterPauseGlyph = 26;

double videoShutterDiameter({required bool sidebar}) =>
    sidebar ? _sidebarShutter : _bottomBarShutter;

class VideoShutterFace extends StatelessWidget {
  const VideoShutterFace({
    super.key,
    required this.form,
    required this.sidebar,
    required this.breath,
    required this.fade,
  });

  final VideoShutterForm form;
  final bool sidebar;
  final Animation<double> breath;
  final Duration fade;

  @override
  Widget build(BuildContext context) {
    return CaptureButtonFace(
      form: form,
      diameter: videoShutterDiameter(sidebar: sidebar),
      fade: fade,
      formKey: videoShutterFormKey,
      base: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: _shutterRing, width: captureRingWidth),
          ),
        ),
      ),
      core: _core,
    );
  }

  double get _dot => sidebar ? _sidebarShutterDot : _bottomBarShutterDot;

  Widget _core(BuildContext context, VideoShutterForm form) {
    final Color record = context.colors.accentRecord;
    return switch (form) {
      VideoShutterForm.ready ||
      VideoShutterForm.resume ||
      VideoShutterForm.saving => _recordDot(record, _dot),
      VideoShutterForm.countdown => SizedBox.square(
        dimension: videoShutterDiameter(sidebar: sidebar),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: CaptureCountdownSweep(progress: breath, color: record),
            ),
            _recordDot(record, _dot * _countdownDotShare),
          ],
        ),
      ),
      VideoShutterForm.pause => const IconStickerGlyphIcon(
        glyph: IconStickerGlyph.pause,
        color: _shutterPauseInk,
        size: _shutterPauseGlyph,
      ),
      VideoShutterForm.stop => SizedBox.square(
        dimension: sidebar ? _sidebarStopSquare : _bottomBarStopSquare,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: record,
            borderRadius: const BorderRadius.all(
              Radius.circular(_stopSquareRadius),
            ),
          ),
        ),
      ),
    };
  }

  Widget _recordDot(Color color, double dimension) {
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
