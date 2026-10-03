import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_providers.dart';

enum SearchFieldVariant { standard, phone }

const Key searchClearFaceKey = ValueKey<String>('search-clear-face');

class SearchField extends ConsumerStatefulWidget {
  const SearchField({super.key, this.variant = SearchFieldVariant.standard});

  final SearchFieldVariant variant;

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

  void _onChanged(String value) =>
      ref.read(searchQueryProvider.notifier).update(value);

  @override
  Widget build(BuildContext context) {
    final String query = ref.watch(searchQueryProvider);
    return switch (widget.variant) {
      SearchFieldVariant.standard => _standard(context, query),
      SearchFieldVariant.phone => _phone(context, query),
    };
  }

  Widget _hint(BuildContext context, TextStyle style) {
    return ExcludeSemantics(
      child: Text(
        _name,
        style: Theme.of(context).textTheme.bodyLarge!
            .merge(style)
            .merge(style.copyWith(color: context.colors.placeholder)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _standard(BuildContext context, String query) {
    final FieldNotesColors colors = context.colors;
    final TextStyle bodySans = context.textStyles.bodySans;
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Shapes.radiusSm),
      borderSide: BorderSide(color: colors.line, width: Shapes.outlineWidth),
    );
    final Widget field = Semantics(
      label: _name,
      child: TextField(
        controller: _controller,
        style: bodySans,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hint: _hint(context, bodySans),
          prefixIcon: Icon(Icons.search, color: colors.mutedDeep),
          suffixIcon: query.isEmpty
              ? null
              : const SizedBox.square(dimension: kMinInteractiveDimension),
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
    return Stack(
      alignment: Alignment.centerRight,
      children: <Widget>[
        field,
        if (query.isNotEmpty) _ClearButton(onPressed: _clear),
      ],
    );
  }

  Widget _phone(BuildContext context, String query) {
    final FieldNotesColors colors = context.colors;
    final TextStyle inputStyle = context.textStyles.bodySans.copyWith(
      fontSize: _phoneTextSize,
    );
    return Container(
      height: _phoneHeight,
      padding: _phonePadding,
      decoration: BoxDecoration(
        color: colors.cardLight,
        border: Border.all(color: colors.line, width: Shapes.outlineWidth),
        borderRadius: _phoneRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadowTintBase.withValues(alpha: _phoneShadowAlpha),
            offset: _phoneShadowOffset,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              Icons.search,
              size: _phoneIconSize,
              color: colors.mutedDeep,
            ),
          ),
          const SizedBox(width: _phoneIconGap),
          Expanded(
            child: Semantics(
              label: _name,
              child: TextField(
                controller: _controller,
                style: inputStyle,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hint: _hint(context, inputStyle),
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          if (query.isNotEmpty) ...<Widget>[
            const SizedBox(width: _phoneClearGap),
            _ClearButton(
              onPressed: _clear,
              faceExtent: _phoneClearExtent,
              faceRadius: _phoneClearRadius,
              iconSize: _phoneClearIconSize,
            ),
          ],
        ],
      ),
    );
  }

  static const String _name = 'Search your days';
}

const double _phoneHeight = 52;

const double _phoneClearExtent = 44;

const double _phoneTextSize = 15;

const double _phoneIconSize = 18;

const double _phoneIconGap = 10;

const double _phoneClearIconSize = 14;

const double _phoneShadowAlpha = 0.18;

const Offset _phoneShadowOffset = Offset(2, 2);

const BorderRadius _phoneRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

const BorderRadius _phoneClearRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusCell),
);

const double _phoneClearSlack =
    (kMinInteractiveDimension - _phoneClearExtent) / 2;

const double _phoneClearGap = 10 - _phoneClearSlack;

const EdgeInsets _phonePadding = EdgeInsets.fromLTRB(
  14,
  0,
  6 - _phoneClearSlack,
  0,
);

const String _clearName = 'Clear search';

const double _clearFaceExtent = 40;

const BorderRadius _clearRadius = BorderRadius.all(
  Radius.circular(_clearFaceExtent / 2),
);

class _ClearButton extends StatelessWidget {
  const _ClearButton({
    required this.onPressed,
    this.faceExtent = _clearFaceExtent,
    this.faceRadius = _clearRadius,
    this.iconSize,
  });

  final VoidCallback onPressed;
  final double faceExtent;
  final BorderRadius faceRadius;
  final double? iconSize;

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
                  borderRadius: faceRadius,
                  child: SizedBox.square(
                    key: searchClearFaceKey,
                    dimension: faceExtent,
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.close,
                        size: iconSize,
                        color: context.colors.mutedDeep,
                      ),
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
