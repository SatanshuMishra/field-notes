import 'package:field_notes/data/crypto/recovery_phrase.dart';
import 'package:field_notes/design/settings_fields/settings_text_field.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const double pairingWordFieldHeight = 48;
const double pairingWordGap = 10;
const double _numberWidth = 14;
const double _numberGap = 8;

final RegExp _whitespace = RegExp(r'\s');

String pairingWordLabel(int number) => 'Word $number';

List<String> spreadPairingWords(List<String> words, int index, String entered) {
  final List<String> parts = normalizeWords(entered);
  if (parts.length < 2) {
    final String word = entered.replaceAll(_whitespace, '');
    return <String>[
      for (int i = 0; i < words.length; i++) i == index ? word : words[i],
    ];
  }
  return <String>[
    for (int i = 0; i < words.length; i++)
      i >= index && i < index + parts.length ? parts[i - index] : words[i],
  ];
}

int filledPairingWords(List<TextEditingController> controllers) => controllers
    .where((TextEditingController controller) => controller.text.isNotEmpty)
    .length;

class PairingWordFields extends StatefulWidget {
  const PairingWordFields({
    super.key,
    required this.controllers,
    this.columns = 2,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
  }) : assert(columns > 0);

  final List<TextEditingController> controllers;
  final int columns;
  final bool enabled;
  final VoidCallback? onSubmitted;
  final VoidCallback? onChanged;

  @override
  State<PairingWordFields> createState() => _PairingWordFieldsState();
}

class _PairingWordFieldsState extends State<PairingWordFields> {
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = _createFocusNodes(widget.controllers.length);
  }

  @override
  void didUpdateWidget(covariant PairingWordFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controllers.length != widget.controllers.length) {
      final List<FocusNode> retired = _focusNodes;
      _focusNodes = _createFocusNodes(widget.controllers.length);
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        for (final FocusNode node in retired) {
          node.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  static List<FocusNode> _createFocusNodes(int count) =>
      List<FocusNode>.unmodifiable(<FocusNode>[
        for (int i = 0; i < count; i++)
          FocusNode(debugLabel: pairingWordLabel(i + 1)),
      ]);

  void _handleChanged(int index, String entered) {
    final List<TextEditingController> controllers = widget.controllers;
    final List<String> words = spreadPairingWords(
      <String>[
        for (final TextEditingController controller in controllers)
          controller.text,
      ],
      index,
      entered,
    );
    for (int i = 0; i < words.length; i++) {
      if (controllers[i].text != words[i]) {
        controllers[i].value = TextEditingValue(
          text: words[i],
          selection: TextSelection.collapsed(offset: words[i].length),
        );
      }
    }
    final int written = normalizeWords(entered).length;
    if (written > 0 && _whitespace.hasMatch(entered)) {
      final int last = words.length - 1;
      final int next = index + written;
      _focusNodes[next > last ? last : next].requestFocus();
    }
    widget.onChanged?.call();
  }

  void _focusField(int index) {
    if (widget.enabled) {
      _focusNodes[index].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.controllers.length;
    final int columns = widget.columns;
    final int rows = (count + columns - 1) ~/ columns;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int row = 0; row < rows; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: pairingWordGap),
          Row(
            children: <Widget>[
              for (int column = 0; column < columns; column++) ...<Widget>[
                if (column > 0) const SizedBox(width: pairingWordGap),
                Expanded(
                  child: row * columns + column < count
                      ? _buildField(context, row * columns + column)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildField(BuildContext context, int index) {
    final bool last = index == widget.controllers.length - 1;
    return Row(
      children: <Widget>[
        SizedBox(
          width: _numberWidth,
          child: ExcludeSemantics(
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.end,
              style: context.textStyles.captionSans,
            ),
          ),
        ),
        const SizedBox(width: _numberGap),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () => _focusField(index),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: pairingWordFieldHeight,
              ),
              child: SettingsTextField(
                controller: widget.controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                semanticLabel: pairingWordLabel(index + 1),
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: last
                    ? TextInputAction.done
                    : TextInputAction.next,
                onChanged: (String entered) => _handleChanged(index, entered),
                onSubmitted: (String _) => widget.onSubmitted?.call(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
