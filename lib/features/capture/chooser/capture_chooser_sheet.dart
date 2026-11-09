import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';

import 'capture_scraps.dart';

const String captureChooserSubtitle = 'how do you want to plant today?';

const Key captureChooserTapeKey = ValueKey<String>('capture-chooser-tape');

const double _pageMaxWidth = 572;
const double _pageMargin = 16;
const double _pagePaddingTop = 26;
const double _pagePaddingHorizontal = 32;
const double _pagePaddingBottom = 35;
const double _pageTiltDegrees = -0.6;
const double _pageFirstRule = 31;
const double _pageRulePeriod = 32;
const double _pageRuleAlpha = 0.15;

const double _tapeOverhang = 12;
const Size _tapeSize = Size(104, 24);
const double _tapeTiltDegrees = -2.5;
const double _tapeAlpha = 0.9;
const double _tapeNotch = 0.03;

const double _subtitleSize = 20;
const double _subtitleLineHeight = 1.2;
const double _subtitleGap = 2;
const double _roomyScrapsGap = 22;
const double _compactScrapsGap = 16;

const double _sheetPaddingTop = 10;
const double _sheetPaddingHorizontal = 7;
const double _sheetPaddingBottom = 48;

class CaptureChooserSheet extends StatelessWidget {
  const CaptureChooserSheet({
    super.key,
    required this.availableTypes,
    required this.onOptionSelected,
    this.title = 'Capture a moment',
    this.unavailableLabel = 'Coming soon',
    this.maxWidth = _pageMaxWidth,
    this.layout = ShellLayout.sidebar,
  });

  final Set<EntryType> availableTypes;
  final ValueChanged<EntryType> onOptionSelected;
  final String title;
  final String unavailableLabel;
  final double maxWidth;
  final ShellLayout layout;

  bool get _isSheet => layout == ShellLayout.bottomBar;

  @override
  Widget build(BuildContext context) {
    return _isSheet ? _buildSheet(context) : _buildPanel(context);
  }

  Color _ruleColor(BuildContext context) =>
      context.colors.ink.withValues(alpha: _pageRuleAlpha);

  Widget _buildPanel(BuildContext context) {
    final bool textEnlarged = captureTextEnlarged(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: _pageMargin,
          vertical: _pageMargin + _tapeOverhang,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: StickerCard(
            surface: context.colors.cardBright,
            padding: EdgeInsets.zero,
            rotationDegrees: textEnlarged ? 0 : _pageTiltDegrees,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                RuledPaper(
                  color: _ruleColor(context),
                  firstRule: _pageFirstRule,
                  period: _pageRulePeriod,
                  inset: Shapes.outlineWidth,
                  cornerRadius: Shapes.radiusLg,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _pagePaddingHorizontal,
                      _pagePaddingTop,
                      _pagePaddingHorizontal,
                      _pagePaddingBottom,
                    ),
                    child: _buildBody(context),
                  ),
                ),
                Positioned(
                  top: -_tapeOverhang,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _PageTape(tilted: !textEnlarged),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return PhoneSheet(
      color: context.colors.panelTop,
      child: RuledPaper(
        color: _ruleColor(context),
        firstRule: _pageFirstRule,
        period: _pageRulePeriod,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _sheetPaddingHorizontal,
            _sheetPaddingTop,
            _sheetPaddingHorizontal,
            _sheetPaddingBottom,
          ),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: textStyles.title, textAlign: TextAlign.center),
        const SizedBox(height: _subtitleGap),
        Text(
          captureChooserSubtitle,
          style: textStyles.accent.copyWith(
            fontSize: _subtitleSize,
            height: _subtitleLineHeight,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: _isSheet ? _compactScrapsGap : _roomyScrapsGap),
        CaptureScraps(
          availableTypes: availableTypes,
          unavailableLabel: unavailableLabel,
          onSelected: onOptionSelected,
          compact: _isSheet,
        ),
      ],
    );
  }
}

class _PageTape extends StatelessWidget {
  const _PageTape({required this.tilted});

  final bool tilted;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      key: captureChooserTapeKey,
      angle: tilted ? _tapeTiltDegrees * math.pi / 180 : 0,
      child: SizedBox.fromSize(
        size: _tapeSize,
        child: CustomPaint(
          painter: _TapePainter(
            context.colors.waveLight.withValues(alpha: _tapeAlpha),
          ),
        ),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  const _TapePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double notch = size.width * _tapeNotch;
    final double width = size.width;
    final double height = size.height;
    final Path strip = Path()
      ..addPolygon(<Offset>[
        Offset.zero,
        Offset(width, 0),
        Offset(width - notch, height * 0.25),
        Offset(width, height * 0.5),
        Offset(width - notch, height * 0.75),
        Offset(width, height),
        Offset(0, height),
        Offset(notch, height * 0.75),
        Offset(0, height * 0.5),
        Offset(notch, height * 0.25),
      ], true);
    canvas.drawPath(strip, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TapePainter oldDelegate) => oldDelegate.color != color;
}
