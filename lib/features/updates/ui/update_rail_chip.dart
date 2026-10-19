import 'dart:ui' as ui;

import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/ui/update_notes_surface.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/features/updates/update_wording.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Key updateRailChipKey = ValueKey<String>('update-rail-chip');

const double updateRailChipCollapsedSize = 40;
const double updateRailChipIconSize = 16;
const double updateRailChipBorderOpacity = 0.6;
const double updateRailChipFillOpacity = 0.07;
const double updateRailChipHoverOpacity = 0.16;

const double _chipGap = 10;
const double _titleSize = 12.5;
const double _versionSize = 10.5;
const EdgeInsets _chipPadding = EdgeInsets.symmetric(
  vertical: 8,
  horizontal: 10,
);
const BorderRadius _chipRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

class UpdateRailChip extends ConsumerWidget {
  const UpdateRailChip({super.key, required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReleaseInfo? release = ref.watch(updateNoticeProvider);
    if (release == null) {
      return const SizedBox.shrink();
    }
    final FieldNotesColors colors = context.colors;
    final String version = release.version.toString();
    final Widget icon = SettingsIcon(
      SettingsGlyph.download,
      size: updateRailChipIconSize,
      color: colors.accentInk,
    );
    Widget face(bool hovered) => CustomPaint(
      key: updateRailChipKey,
      painter: _DashedChipBorder(
        color: Palette.coral.withValues(alpha: updateRailChipBorderOpacity),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.coral.withValues(
            alpha: hovered
                ? updateRailChipHoverOpacity
                : updateRailChipFillOpacity,
          ),
          borderRadius: _chipRadius,
        ),
        child: collapsed
            ? SizedBox.square(
                dimension: updateRailChipCollapsedSize,
                child: Center(child: icon),
              )
            : Padding(
                padding: _chipPadding,
                child: Row(
                  children: <Widget>[
                    icon,
                    const SizedBox(width: _chipGap),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            updateAvailableLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.labelSans.copyWith(
                              fontSize: _titleSize,
                              fontWeight: FontWeight.w600,
                              color: colors.accentInk,
                            ),
                          ),
                          Text(
                            versionLine(version),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.captionSans.copyWith(
                              fontSize: _versionSize,
                              fontWeight: FontWeight.w400,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
    final Widget chip = Pressable(
      label: railSemanticsLabel(version),
      tooltip: railTooltip(version),
      onPressed: () => showUpdateNotes(context, ref, newVersion: true),
      borderRadius: _chipRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => face(hovered),
    );
    return collapsed ? Center(child: chip) : chip;
  }
}

class _DashedChipBorder extends CustomPainter {
  const _DashedChipBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double inset = Shapes.outlineWidth / 2;
    final RRect outline = _chipRadius
        .toRRect(Offset.zero & size)
        .deflate(inset);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = Shapes.outlineWidth;
    final Path path = Path()..addRRect(outline);
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = distance + Shapes.dashLength;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          stroke,
        );
        distance = end + Shapes.dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedChipBorder oldDelegate) =>
      oldDelegate.color != color;
}
