String pluralize(int count, String singular, [String? plural]) {
  final String word = count == 1 ? singular : (plural ?? '${singular}s');
  return '$count $word';
}
