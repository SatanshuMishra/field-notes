import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

const String captureChooserSubtitle = 'how do you want to plant today?';

const double _panelPadding = 20;
const double _subtitleSize = 12;
const double _subtitleGap = 1;
const double _rowsGap = 15;
const double _rowGap = 9;

const double _sheetPaddingTop = 10;
const double _sheetPaddingHorizontal = 16;
const double _sheetPaddingBottom = 22;

const double _rowBorderWidth = 1.5;
const double _rowIconGap = 12;
const double _rowPaddingVertical = 13;
const double _rowPaddingHorizontal = 15;
const double _rowIconSize = 20;
const double _rowPrimarySubtitleOpacity = 0.85;

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
    this.maxWidth = 360,
    this.layout = ShellLayout.sidebar,
  });

  final Set<EntryType> availableTypes;
  final ValueChanged<EntryType> onOptionSelected;
  final String title;
  final String unavailableLabel;
  final double maxWidth;
  final ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    return layout == ShellLayout.bottomBar
        ? _buildSheet(context)
        : _buildPanel(context);
  }

  Widget _buildPanel(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: StickerCard(
          surface: context.colors.cardBright,
          padding: const EdgeInsets.all(_panelPadding),
          child: _buildBody(context),
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
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
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
        const SizedBox(height: _subtitleGap),
        Text(
          captureChooserSubtitle,
          style: textStyles.subtitleAccent.copyWith(fontSize: _subtitleSize),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: _rowsGap),
        ..._buildRows(),
      ],
    );
  }

  List<Widget> _buildRows() {
    final List<Widget> rows = <Widget>[];
    for (final CaptureOption option in captureOptions) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: _rowGap));
      }
      rows.add(
        _CaptureOptionRow(
          option: option,
          isAvailable: availableTypes.contains(option.type),
          unavailableLabel: unavailableLabel,
          onSelected: onOptionSelected,
        ),
      );
    }
    return rows;
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
    final Color foreground = _isPrimary ? Palette.onAccent : colors.ink;
    final VoidCallback? select = isAvailable
        ? () => onSelected(option.type)
        : null;
    final Widget detector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: select,
      child: FocusRing(
        enabled: isAvailable,
        includeFocusSemantics: isAvailable,
        onPressed: select,
        borderRadius: _rowRadius,
        child: Container(
          decoration: BoxDecoration(
            color: _isPrimary ? Palette.coral : colors.cardWarm,
            border: Border.all(color: colors.line, width: _rowBorderWidth),
            borderRadius: _rowRadius,
            boxShadow: _isPrimary ? context.shadows.emphasis : null,
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
                      isAvailable ? option.description : unavailableLabel,
                      style: _isPrimary
                          ? textStyles.caption10Sans.copyWith(
                              color: Palette.onAccent.withValues(
                                alpha: _rowPrimarySubtitleOpacity,
                              ),
                            )
                          : textStyles.caption10Sans,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!isAvailable) {
      return detector;
    }
    return Semantics(container: true, button: true, child: detector);
  }
}
