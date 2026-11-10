import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

import 'capture_scraps.dart';

const String captureChooserSubtitle = 'how do you want to plant today?';

const Key captureChooserTapeKey = ValueKey<String>('capture-chooser-tape');

Key captureChooserRowKey(EntryType type) =>
    ValueKey<String>('capture-chooser-row-${type.id}');

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
const double _scrapsGap = 22;

const double _sheetPaddingTop = 10;
const double _sheetPaddingHorizontal = 16;
const double _sheetPaddingBottom = 22;
const double _sheetSubtitleSize = 12;
const double _sheetSubtitleGap = 1;
const double _sheetRowsGap = 15;

const double _rowGap = 9;
const double _rowBorderWidth = 1.5;
const double _rowIconGap = 12;
const double _rowPaddingVertical = 13;
const double _rowPaddingHorizontal = 15;
const double _rowIconSize = 20;
const double _rowCaptionLineHeight = 1.1;

const BorderRadius _rowRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

CaptureGlyph _glyphFor(EntryType type) {
  switch (type) {
    case EntryType.text:
      return CaptureGlyph.pencil;
    case EntryType.voice:
      return CaptureGlyph.mic;
    case EntryType.video:
      return CaptureGlyph.video;
  }
}

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
                    child: _buildPageBody(context),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingHorizontal,
          _sheetPaddingTop,
          _sheetPaddingHorizontal,
          _sheetPaddingBottom,
        ),
        child: _buildSheetBody(context),
      ),
    );
  }

  Widget _buildPageBody(BuildContext context) {
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
        const SizedBox(height: _scrapsGap),
        CaptureScraps(
          availableTypes: availableTypes,
          unavailableLabel: unavailableLabel,
          onSelected: onOptionSelected,
        ),
      ],
    );
  }

  Widget _buildSheetBody(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: textStyles.sectionSerif,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: _sheetSubtitleGap),
        Text(
          captureChooserSubtitle,
          style: textStyles.subtitleAccent.copyWith(
            fontSize: _sheetSubtitleSize,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: _sheetRowsGap),
        for (final (int index, CaptureOption option)
            in captureOptions.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: _rowGap),
          _CaptureOptionRow(
            option: option,
            isAvailable: availableTypes.contains(option.type),
            unavailableLabel: unavailableLabel,
            onSelected: onOptionSelected,
          ),
        ],
      ],
    );
  }
}

class _CaptureOptionRow extends StatelessWidget {
  const _CaptureOptionRow({
    required this.option,
    required this.isAvailable,
    required this.unavailableLabel,
    required this.onSelected,
  });

  final CaptureOption option;
  final bool isAvailable;
  final String unavailableLabel;
  final ValueChanged<EntryType> onSelected;

  bool get _isPrimary => option.type == EntryType.text;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    final FieldNotesShadows shadows = context.shadows;
    final Color foreground = _isPrimary ? Palette.onAccent : colors.ink;
    final VoidCallback? select = isAvailable
        ? () => onSelected(option.type)
        : null;
    final String caption = isAvailable ? option.description : unavailableLabel;
    final TextStyle captionStyle = textStyles.subtitleAccent.copyWith(
      height: _rowCaptionLineHeight,
    );
    return Pressable(
      key: captureChooserRowKey(option.type),
      label: '${option.label}\n$caption',
      onPressed: select,
      borderRadius: _rowRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => HoverFill(
        hovered: hovered,
        surface: _isPrimary ? FocusRingSurface.dark : FocusRingSurface.light,
        borderRadius: _rowRadius,
        child: Container(
          decoration: BoxDecoration(
            color: _isPrimary ? Palette.coral : colors.cardWarm,
            border: Border.all(color: colors.line, width: _rowBorderWidth),
            borderRadius: _rowRadius,
            boxShadow: _isPrimary ? shadows.emphasis : shadows.cardDefault,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: _rowPaddingVertical,
            horizontal: _rowPaddingHorizontal,
          ),
          child: Row(
            children: <Widget>[
              CaptureIcon(
                glyph: _glyphFor(option.type),
                color: foreground,
                size: _rowIconSize,
              ),
              const SizedBox(width: _rowIconGap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.label,
                      style: textStyles.labelSans.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                    Text(
                      caption,
                      style: _isPrimary
                          ? captionStyle.copyWith(color: Palette.onAccent)
                          : captionStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
