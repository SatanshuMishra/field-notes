# Spec example fixtures

Both JSON files in this directory hold the examples of a published Markdown specification, extracted unchanged into JSON. They are test data for the grammar's example suites.

## commonmark-0.31.2.json

- Source: https://spec.commonmark.org/0.31.2/spec.json, copied byte for byte from the cached copy at `~/.pub-cache/hosted/pub.dev/markdown-7.3.1/tool/common_mark_tests.json` (the `markdown` package 7.3.1). All 652 examples were checked against spec.json on 2026-09-23 and agree in number, section, markdown and html.
- Specification: CommonMark Spec, version 0.31.2 (2024-01-28).
- Attribution: the CommonMark Spec by John MacFarlane.
- Licence: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0), https://creativecommons.org/licenses/by-sa/4.0/.

## gfm-0.29-gfm.json

- Source: https://github.github.com/gfm/, fetched on 2026-09-23. Each example's markdown and html were taken from the page's example blocks, with tags removed, HTML entities decoded and each U+2192 arrow replaced by a tab, as cmark's `test/spec_tests.py` does; its section is the nearest preceding heading without its section number.
- Specification: GitHub Flavored Markdown Spec, version 0.29-gfm (2019-04-06).
- Attribution: the GitHub Flavored Markdown Spec, which states that it is based on the CommonMark Spec by John MacFarlane.
- Licence: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0), https://creativecommons.org/licenses/by-sa/4.0/.
