import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'a moment';
const String _title = 'Write a little about today.';
const String _placeholder = 'What happened today?';
const int _noteLimit = 280;
const double _fieldMaxWidth = 640;

const EdgeInsets _sidebarFieldPadding = EdgeInsets.fromLTRB(40, 24, 40, 0);
const EdgeInsets _bottomBarFieldPadding = EdgeInsets.fromLTRB(18, 16, 18, 0);

class MomentChapter extends ConsumerStatefulWidget {
  const MomentChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<MomentChapter> createState() => _MomentChapterState();
}

class _MomentChapterState extends ConsumerState<MomentChapter> {
  late final TextEditingController _note = TextEditingController(
    text: switch (ref.read(onboardingControllerProvider)) {
      OnboardingFlowRunning(:final OnboardingDraft draft) => draft.noteText,
      OnboardingFlowHidden() || OnboardingFlowMap() => '',
    },
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool sidebar = widget.layout == ShellLayout.sidebar;
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: sidebar
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.stretch,
          children: <Widget>[
            OnboardingHeading(
              layout: widget.layout,
              kicker: _kicker,
              title: _title,
            ),
            Padding(
              padding: sidebar ? _sidebarFieldPadding : _bottomBarFieldPadding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _fieldMaxWidth),
                child: TextField(
                  controller: _note,
                  onChanged: ref
                      .read(onboardingControllerProvider.notifier)
                      .setNote,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(_noteLimit),
                  ],
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: _placeholder),
                  style: TextStyle(
                    fontFamily: TypographyTokens.serif,
                    fontSize: 18,
                    color: context.colors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
