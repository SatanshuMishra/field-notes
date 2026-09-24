import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> sendTextInputCall(
  WidgetTester tester,
  String method,
  List<Object?> arguments,
) async {
  final ByteData data = SystemChannels.textInput.codec.encodeMethodCall(
    MethodCall(method, arguments),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    data,
    (ByteData? _) {},
  );
}

Map<String, Object?> _delta({
  required String oldText,
  required String deltaText,
  required int deltaStart,
  required int deltaEnd,
  required TextSelection selection,
  required TextRange composing,
}) => <String, Object?>{
  'oldText': oldText,
  'deltaText': deltaText,
  'deltaStart': deltaStart,
  'deltaEnd': deltaEnd,
  'selectionBase': selection.baseOffset,
  'selectionExtent': selection.extentOffset,
  'selectionAffinity': selection.affinity.toString(),
  'selectionIsDirectional': selection.isDirectional,
  'composingBase': composing.start,
  'composingExtent': composing.end,
};

Map<String, Object?> insertionDelta({
  required String oldText,
  required int at,
  required String text,
  TextSelection? selection,
  TextRange composing = TextRange.empty,
}) => _delta(
  oldText: oldText,
  deltaText: text,
  deltaStart: at,
  deltaEnd: at,
  selection: selection ?? TextSelection.collapsed(offset: at + text.length),
  composing: composing,
);

Map<String, Object?> deletionDelta({
  required String oldText,
  required TextRange range,
  TextSelection? selection,
  TextRange composing = TextRange.empty,
}) => _delta(
  oldText: oldText,
  deltaText: '',
  deltaStart: range.start,
  deltaEnd: range.end,
  selection: selection ?? TextSelection.collapsed(offset: range.start),
  composing: composing,
);

Map<String, Object?> replacementDelta({
  required String oldText,
  required TextRange range,
  required String text,
  TextSelection? selection,
  TextRange composing = TextRange.empty,
}) => _delta(
  oldText: oldText,
  deltaText: text,
  deltaStart: range.start,
  deltaEnd: range.end,
  selection:
      selection ?? TextSelection.collapsed(offset: range.start + text.length),
  composing: composing,
);

Map<String, Object?> selectionDelta({
  required String oldText,
  required TextSelection selection,
  TextRange composing = TextRange.empty,
}) => _delta(
  oldText: oldText,
  deltaText: '',
  deltaStart: -1,
  deltaEnd: -1,
  selection: selection,
  composing: composing,
);

Future<void> sendDeltas(
  WidgetTester tester,
  List<Map<String, Object?>> deltas,
) => sendTextInputCall(
  tester,
  'TextInputClient.updateEditingStateWithDeltas',
  <Object?>[
    -1,
    <String, Object?>{'deltas': deltas},
  ],
);

Future<void> sendEditingState(WidgetTester tester, TextEditingValue value) =>
    sendTextInputCall(tester, 'TextInputClient.updateEditingState', <Object?>[
      -1,
      value.toJSON(),
    ]);

Future<void> sendInputAction(WidgetTester tester, TextInputAction action) =>
    sendTextInputCall(tester, 'TextInputClient.performAction', <Object?>[
      -1,
      action.toString(),
    ]);

Future<void> sendCommitContent(
  WidgetTester tester,
  KeyboardInsertedContent content,
) => sendTextInputCall(tester, 'TextInputClient.performAction', <Object?>[
  -1,
  'TextInputAction.commitContent',
  <String, Object?>{
    'mimeType': content.mimeType,
    'uri': content.uri,
    'data': content.data?.toList(),
  },
]);

Future<void> sendPrivateCommand(
  WidgetTester tester,
  String action, [
  Map<String, Object?> data = const <String, Object?>{},
]) => sendTextInputCall(
  tester,
  'TextInputClient.performPrivateCommand',
  <Object?>[
    -1,
    <String, Object?>{'action': action, 'data': data},
  ],
);

Future<void> sendSelectors(WidgetTester tester, List<String> selectors) =>
    sendTextInputCall(tester, 'TextInputClient.performSelectors', <Object?>[
      -1,
      selectors,
    ]);

Future<void> sendConnectionClosed(WidgetTester tester) => sendTextInputCall(
  tester,
  'TextInputClient.onConnectionClosed',
  <Object?>[-1],
);

Future<void> sendRequestExistingInputState(WidgetTester tester) =>
    sendTextInputCall(
      tester,
      'TextInputClient.requestExistingInputState',
      <Object?>[-1],
    );

Future<TextEditingValue> typeByDeltas(
  WidgetTester tester,
  TextEditingValue current,
  String text,
) async {
  TextEditingValue value = current;
  for (final String grapheme in text.characters) {
    final TextSelection selection = value.selection;
    final int start = selection.isValid ? selection.start : value.text.length;
    final int end = selection.isValid ? selection.end : value.text.length;
    final Map<String, Object?> delta = start == end
        ? insertionDelta(oldText: value.text, at: start, text: grapheme)
        : replacementDelta(
            oldText: value.text,
            range: TextRange(start: start, end: end),
            text: grapheme,
          );
    await sendDeltas(tester, <Map<String, Object?>>[delta]);
    await tester.pump();
    value = TextEditingValue(
      text: value.text.replaceRange(start, end, grapheme),
      selection: TextSelection.collapsed(offset: start + grapheme.length),
    );
  }
  return value;
}

List<MethodCall> textInputCalls(WidgetTester tester, String method) => tester
    .testTextInput
    .log
    .where((MethodCall call) => call.method == method)
    .toList();
