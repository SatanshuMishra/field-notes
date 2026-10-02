import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'and you';
const String _title = 'When should we check in?';

class ReminderChapter extends ConsumerWidget {
  const ReminderChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topCenter,
        child: OnboardingHeading(
          layout: layout,
          kicker: _kicker,
          title: _title,
        ),
      ),
    );
  }
}
