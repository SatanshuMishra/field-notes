import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../model/calendar_month.dart';
import 'calendar_month_picker.dart';

const String _dismissLabel = 'Dismiss month picker';

const double _compactPickerBelowWidth = 520;
const Offset _pickerOffset = Offset(0, 8);
const Color _clearBarrier = Color(0x00000000);

Future<MonthRef?> showCalendarMonthPicker(
  BuildContext context, {
  required LayerLink titleLink,
  required MonthRef displayedMonth,
  required MonthRef currentMonth,
  Key? pickerKey,
}) {
  return showGeneralDialog<MonthRef>(
    context: context,
    barrierColor: _clearBarrier,
    transitionDuration: Duration.zero,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return _MonthPickerLayer(
            titleLink: titleLink,
            displayedMonth: displayedMonth,
            currentMonth: currentMonth,
            pickerKey: pickerKey,
          );
        },
  );
}

class _MonthPickerLayer extends StatefulWidget {
  const _MonthPickerLayer({
    required this.titleLink,
    required this.displayedMonth,
    required this.currentMonth,
    this.pickerKey,
  });

  final LayerLink titleLink;
  final MonthRef displayedMonth;
  final MonthRef currentMonth;
  final Key? pickerKey;

  @override
  State<_MonthPickerLayer> createState() => _MonthPickerLayerState();
}

class _MonthPickerLayerState extends State<_MonthPickerLayer> {
  late int _year = widget.displayedMonth.year;

  void _close([MonthRef? month]) {
    if (ModalRoute.isCurrentOf(context) ?? false) {
      Navigator.of(context).pop(month);
    }
  }

  void _stepYear(int delta) => setState(() => _year += delta);

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final double width =
        MediaQuery.sizeOf(context).width < _compactPickerBelowWidth
        ? calendarMonthPickerCompactWidth
        : calendarMonthPickerWidth;
    return Focus(
      autofocus: true,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _handleKey,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Semantics(
              button: true,
              label: _dismissLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: widget.titleLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              offset: _pickerOffset,
              child: CalendarMonthPicker(
                key: widget.pickerKey,
                year: _year,
                displayedMonth: widget.displayedMonth,
                currentMonth: widget.currentMonth,
                width: width,
                onPreviousYear: () => _stepYear(-1),
                onNextYear: () => _stepYear(1),
                onPickMonth: _close,
                onBackToThisWeek: () => _close(widget.currentMonth),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
