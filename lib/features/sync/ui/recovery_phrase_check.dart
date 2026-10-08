import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:flutter/widgets.dart';

import 'start_sync_flow.dart';
import 'sync_flow_page.dart';

const String checkPhraseTitle = 'Check your phrase';
const String checkPhraseMessage =
    "Type two of your words so we know they're written down correctly.";
const String checkPhraseBackLabel = 'Back';
const String turnOnSyncLabel = 'Turn on sync';

const Key turnOnSyncKey = ValueKey<String>('recovery-check-turn-on');

String recoveryCheckLabel(int position) => 'Word $position';

class RecoveryPhraseCheck extends StatefulWidget {
  const RecoveryPhraseCheck({
    super.key,
    required this.enrolment,
    required this.onBack,
    required this.onConfirmed,
  });

  final PendingEnrolment enrolment;
  final VoidCallback onBack;
  final VoidCallback onConfirmed;

  @override
  State<RecoveryPhraseCheck> createState() => _RecoveryPhraseCheckState();
}

class _RecoveryPhraseCheckState extends State<RecoveryPhraseCheck> {
  late final List<TextEditingController> _typed = <TextEditingController>[
    for (final int _ in widget.enrolment.positions) TextEditingController(),
  ];
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final TextEditingController controller in _typed) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _complete => _typed.every(
    (TextEditingController controller) => controller.text.trim().isNotEmpty,
  );

  Future<void> _turnOn() async {
    if (_busy || !_complete) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.enrolment.confirm(<String>[
        for (final TextEditingController controller in _typed) controller.text,
      ]);
      if (mounted) {
        widget.onConfirmed();
      }
    } on WrongRecoveryWord catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    final List<int> positions = widget.enrolment.positions;
    return SyncTaskFrame(
      title: checkPhraseTitle,
      message: checkPhraseMessage,
      content: <Widget>[
        for (int index = 0; index < positions.length; index++)
          SyncFlowField(
            label: recoveryCheckLabel(positions[index]),
            controller: _typed[index],
            enabled: !_busy,
            onChanged: (String _) => setState(() => _error = null),
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
          ),
        if (error != null) SyncFlowError(message: error),
      ],
      actions: <SyncFlowAction>[
        SyncFlowAction(
          label: checkPhraseBackLabel,
          onPressed: _busy ? null : widget.onBack,
        ),
        SyncFlowAction(
          key: turnOnSyncKey,
          label: turnOnSyncLabel,
          primary: true,
          onPressed: _busy || !_complete ? null : _turnOn,
        ),
      ],
    );
  }
}
