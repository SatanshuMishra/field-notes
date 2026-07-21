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
    return TextField(
      controller: _controller,
      style: TypographyTokens.bodySans,
      onChanged: (String value) =>
          ref.read(searchQueryProvider.notifier).update(value),
      decoration: InputDecoration(
        hintText: 'Search your days',
        hintStyle:
            TypographyTokens.bodySans.copyWith(color: Palette.placeholder),
        prefixIcon: const Icon(Icons.search, color: Palette.mutedDeep),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Palette.mutedDeep),
                tooltip: 'Clear search',
                onPressed: _clear,
              ),
        filled: true,
        fillColor: Palette.cardBright,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: _border,
        enabledBorder: _border,
        focusedBorder: _border,
      ),
    );
  }

  static final OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Shapes.radiusSm),
    borderSide: const BorderSide(
      color: Palette.ink,
      width: Shapes.outlineWidth,
    ),
  );
}
