import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/features/garden/model/meadow_time_of_day.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/garden_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_details_sheet.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';

const double meadowPhoneTitleInset = 18;
const double meadowPhoneTitleDrop = 12;
const double meadowPhoneScrimDepth = 150;
const double meadowPhoneDockGap = 8;
const String meadowTimeHeading = 'time of day';

class MeadowPhonePage extends StatelessWidget {
  const MeadowPhonePage({super.key, required this.chrome, this.study});

  final MeadowChrome chrome;
  final MeadowStudyParts? study;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double header = media.padding.top;
    final double gesture = media.viewPadding.bottom;
    final double dockBottom = meadowPhoneDockBottom(media);
    final MeadowStudyParts? parts = study;
    final Widget? stepper = chrome.stepper;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: meadowLoadingBackdrop),
            Positioned.fill(child: chrome.scene),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: header + meadowPhoneScrimDepth,
              child: const IgnorePointer(child: MeadowScrim()),
            ),
            Positioned(
              key: meadowTitleBlockKey,
              left: meadowPhoneTitleInset,
              right: meadowPhoneTitleInset,
              top: header + meadowPhoneTitleDrop,
              child: IgnorePointer(child: chrome.header),
            ),
            if (parts != null && stepper == null)
              Positioned(
                left: meadowPopoverInset,
                right: meadowPopoverInset,
                bottom: dockBottom + meadowPhoneOverlayLift,
                child: parts.panel,
              ),
            Positioned(
              left: meadowPopoverInset,
              right: meadowPopoverInset,
              bottom: dockBottom,
              child: stepper ?? _dock(parts),
            ),
            if (chrome.popover != MeadowPopover.none)
              Positioned.fill(
                child: _popover(
                  context,
                  dockBottom: dockBottom,
                  height: height,
                ),
              ),
            if (chrome.detailsOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: gesture,
                child: MeadowDetailsSheet(
                  maxHeight: height * meadowDetailsSheetShare,
                  bottomPadding: phoneBottomBarZone,
                  child: chrome.details,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dock(MeadowStudyParts? parts) {
    final bool study = parts != null;
    void toggle(MeadowPopover popover) => chrome.onPopover(
      chrome.popover == popover ? MeadowPopover.none : popover,
    );
    final Color ink = meadowCream;
    final List<Widget> buttons = <Widget>[
      if (study)
        MeadowGlassButton(
          key: meadowThisYearButtonKey,
          grouped: true,
          label: meadowBackCompactLabel,
          onPressed: chrome.onBack,
          padding: const EdgeInsets.fromLTRB(10, 0, 13, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MeadowGlyph(path: meadowBackChevron, size: 14, stroke: 2.4),
              const SizedBox(width: 6),
              Text(
                meadowBackCompactLabel,
                maxLines: 1,
                softWrap: false,
                style: meadowSans(13),
              ),
            ],
          ),
        ),
      MeadowGlassButton(
        key: meadowYearPickerButtonKey,
        grouped: true,
        label: meadowYearPickerLabel,
        value: '${chrome.year.year}',
        selected: chrome.popover == MeadowPopover.year,
        onPressed: () => toggle(MeadowPopover.year),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${chrome.year.year}',
              maxLines: 1,
              softWrap: false,
              style: meadowSans(14),
            ),
            const SizedBox(width: 6),
            MeadowGlyph(
              path: meadowCaretDown,
              size: 12,
              color: ink,
              stroke: 2.4,
            ),
          ],
        ),
      ),
      Expanded(
        child: parts == null
            ? MeadowGlassButton(
                key: meadowTimeButtonKey,
                grouped: true,
                label: meadowTimeButtonLabel,
                value: chrome.timeLabel,
                selected: chrome.popover == MeadowPopover.time,
                onPressed: () => toggle(MeadowPopover.time),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        chrome.timeLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: meadowSans(13),
                      ),
                    ),
                    const SizedBox(width: 7),
                    MeadowGlyph(
                      path: meadowCaretDown,
                      size: 12,
                      color: ink,
                      stroke: 2.4,
                    ),
                  ],
                ),
              )
            : parts.replay,
      ),
      MeadowGlassButton(
        key: meadowDetailsButtonKey,
        grouped: true,
        label: meadowDetailsLabel,
        tooltip: meadowDetailsLabel,
        selected: chrome.detailsOpen,
        width: meadowPhoneControlHeight,
        onPressed: chrome.onDetails,
        child: MeadowGlyph(path: meadowFourSquares, size: 18, stroke: 1.8),
      ),
      MeadowGlassButton(
        key: meadowFullScreenButtonKey,
        grouped: true,
        label: meadowFullScreenLabel,
        tooltip: meadowFullScreenLabel,
        width: meadowPhoneControlHeight,
        onPressed: chrome.onFullScreen,
        child: MeadowGlyph(path: meadowExpandCorners, size: 16),
      ),
    ];
    return MeadowChromeBlock(
      child: _MeadowDockGroup(
        child: Row(
          key: meadowDockKey,
          children: <Widget>[
            for (int index = 0; index < buttons.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: meadowPhoneDockGap),
              buttons[index],
            ],
          ],
        ),
      ),
    );
  }

  Widget _popover(
    BuildContext context, {
    required double dockBottom,
    required double height,
  }) {
    void close() => chrome.onPopover(MeadowPopover.none);
    if (chrome.popover == MeadowPopover.year) {
      return MeadowGlassPopover(
        bottom: dockBottom + meadowPopoverLift,
        onDismiss: close,
        heading: meadowYearPickerHeading,
        maxHeight: height * meadowPopoverMaxShare,
        children: <Widget>[
          MeadowYearList(
            years: chrome.years,
            openYear: chrome.year.year,
            compact: true,
            onPick: (int year) {
              close();
              chrome.onPickYear(year);
            },
          ),
        ],
      );
    }
    final MeadowTimeOfDay? current = meadowTimeOfDayAt(chrome.shownMinutes);
    return MeadowGlassPopover(
      bottom: dockBottom + meadowPopoverLift,
      onDismiss: close,
      heading: meadowTimeHeading,
      gap: 2,
      children: <Widget>[
        for (final MeadowTimeOfDay time in meadowTimesOfDay)
          MeadowTimeRow(
            label: time.label,
            sub: time.sub,
            compact: true,
            selected: time == current,
            onPressed: () => chrome.onTime(time),
          ),
      ],
    );
  }
}

class _MeadowDockGroup extends StatefulWidget {
  const _MeadowDockGroup({required this.child});

  final Widget child;

  @override
  State<_MeadowDockGroup> createState() => _MeadowDockGroupState();
}

class _MeadowDockGroupState extends State<_MeadowDockGroup> {
  final BackdropKey _backdropKey = BackdropKey();

  @override
  Widget build(BuildContext context) {
    return BackdropGroup(
      backdropKey: _backdropKey,
      child: MeadowDockShadows(child: widget.child),
    );
  }
}
