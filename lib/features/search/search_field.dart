import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_providers.dart';

class SearchField extends ConsumerStatefulWidget {
  const SearchField({super.key});

  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).update('');
  }

  @override
  Widget build(BuildContext context) {
    final String query = ref.watch(searchQueryProvider);
    final FieldNotesColors colors = context.colors;
    final TextStyle bodySans = context.textStyles.bodySans;
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Shapes.radiusSm),
      borderSide: BorderSide(color: colors.line, width: Shapes.outlineWidth),
    );
    return Semantics(
      label: _name,
      child: TextField(
        controller: _controller,
        style: bodySans,
        onChanged: (String value) =>
            ref.read(searchQueryProvider.notifier).update(value),
        decoration: InputDecoration(
          hint: ExcludeSemantics(
            child: Text(
              _name,
              style: Theme.of(context).textTheme.bodyLarge!
                  .merge(bodySans)
                  .merge(bodySans.copyWith(color: colors.placeholder)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          prefixIcon: Icon(Icons.search, color: colors.mutedDeep),
          suffixIcon: query.isEmpty ? null : _ClearButton(onPressed: _clear),
          filled: true,
          fillColor: colors.cardBright,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }

  static const String _name = 'Search your days';
}

const String _clearName = 'Clear search';

const double _clearFaceExtent = 40;

const BorderRadius _clearRadius = BorderRadius.all(
  Radius.circular(_clearFaceExtent / 2),
);

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _clearName,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        label: _clearName,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: kMinInteractiveDimension,
              child: Center(
                child: FocusRing(
                  onPressed: onPressed,
                  borderRadius: _clearRadius,
                  child: SizedBox.square(
                    dimension: _clearFaceExtent,
                    child: ExcludeSemantics(
                      child: Icon(Icons.close, color: context.colors.mutedDeep),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
