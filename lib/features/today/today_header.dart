import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_capture_buttons.dart';

const String todayNewLogLabel = 'New log';
const Key todayNewLogButtonKey = ValueKey<String>('today-new-log');

const double _newLogIconSize = 17;

class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.greeting,
    required this.longDate,
    this.actions = const <Widget>[],
  });

  final String greeting;
  final String longDate;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return PageHeader(title: longDate, eyebrow: greeting, actions: actions);
  }
}

class TodayNewLogButton extends ConsumerWidget {
  const TodayNewLogButton({super.key, required this.date});

  final String date;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      await openCapture(context, ref, date: date);
    } catch (_) {
      if (context.mounted) {
        showTransientToast(
          context,
          captureOpenErrorMessage,
          glyph: IconStickerGlyph.close,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MinTarget.button(
      child: StickerButton(
        key: todayNewLogButtonKey,
        label: todayNewLogLabel,
        icon: const NavIcon(
          glyph: NavGlyph.plus,
          color: Palette.onAccent,
          size: _newLogIconSize,
        ),
        onPressed: () => _open(context, ref),
      ),
    );
  }
}
