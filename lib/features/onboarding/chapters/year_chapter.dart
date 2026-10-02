import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'a year';
const String _title = 'This is roughly what a year of you looks like.';

class YearChapter extends ConsumerWidget {
  const YearChapter({super.key, required this.layout});

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
