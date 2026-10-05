class RecordState {
  RecordState({
    required this.table,
    required this.rowId,
    required Map<String, Object?> fields,
    required Map<String, String> clocks,
  }) : fields = Map<String, Object?>.unmodifiable(fields),
       clocks = Map<String, String>.unmodifiable(clocks);

  factory RecordState.fromJson(Map<String, Object?> json) {
    final Object? table = json['table'];
    final Object? rowId = json['rowId'];
    final Object? fields = json['fields'];
    final Object? clocks = json['clocks'];
    if (table is! String ||
        rowId is! String ||
        fields is! Map<String, Object?> ||
        clocks is! Map<String, Object?> ||
        clocks.values.any((Object? clock) => clock is! String)) {
      throw FormatException('Not a record state.', json);
    }
    return RecordState(
      table: table,
      rowId: rowId,
      fields: fields,
      clocks: clocks.cast<String, String>(),
    );
  }

  final String table;
  final String rowId;
  final Map<String, Object?> fields;
  final Map<String, String> clocks;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'table': table,
      'rowId': rowId,
      'fields': fields,
      'clocks': clocks,
    };
  }
}
