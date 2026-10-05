// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MediaBlobsTable extends MediaBlobs
    with TableInfo<$MediaBlobsTable, MediaBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posterIdMeta = const VerificationMeta(
    'posterId',
  );
  @override
  late final GeneratedColumn<String> posterId = GeneratedColumn<String>(
    'poster_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldClocksMeta = const VerificationMeta(
    'fieldClocks',
  );
  @override
  late final GeneratedColumn<String> fieldClocks = GeneratedColumn<String>(
    'field_clocks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    relPath,
    mime,
    kind,
    bytes,
    width,
    height,
    durationMs,
    createdAt,
    posterId,
    fieldClocks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('poster_id')) {
      context.handle(
        _posterIdMeta,
        posterId.isAcceptableOrUnknown(data['poster_id']!, _posterIdMeta),
      );
    }
    if (data.containsKey('field_clocks')) {
      context.handle(
        _fieldClocksMeta,
        fieldClocks.isAcceptableOrUnknown(
          data['field_clocks']!,
          _fieldClocksMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaBlob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      posterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_id'],
      ),
      fieldClocks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clocks'],
      )!,
    );
  }

  @override
  $MediaBlobsTable createAlias(String alias) {
    return $MediaBlobsTable(attachedDatabase, alias);
  }
}

class MediaBlob extends DataClass implements Insertable<MediaBlob> {
  final String id;
  final String relPath;
  final String mime;
  final String kind;
  final int bytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final int createdAt;
  final String? posterId;
  final String fieldClocks;
  const MediaBlob({
    required this.id,
    required this.relPath,
    required this.mime,
    required this.kind,
    required this.bytes,
    this.width,
    this.height,
    this.durationMs,
    required this.createdAt,
    this.posterId,
    required this.fieldClocks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['rel_path'] = Variable<String>(relPath);
    map['mime'] = Variable<String>(mime);
    map['kind'] = Variable<String>(kind);
    map['bytes'] = Variable<int>(bytes);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || posterId != null) {
      map['poster_id'] = Variable<String>(posterId);
    }
    map['field_clocks'] = Variable<String>(fieldClocks);
    return map;
  }

  MediaBlobsCompanion toCompanion(bool nullToAbsent) {
    return MediaBlobsCompanion(
      id: Value(id),
      relPath: Value(relPath),
      mime: Value(mime),
      kind: Value(kind),
      bytes: Value(bytes),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      createdAt: Value(createdAt),
      posterId: posterId == null && nullToAbsent
          ? const Value.absent()
          : Value(posterId),
      fieldClocks: Value(fieldClocks),
    );
  }

  factory MediaBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaBlob(
      id: serializer.fromJson<String>(json['id']),
      relPath: serializer.fromJson<String>(json['relPath']),
      mime: serializer.fromJson<String>(json['mime']),
      kind: serializer.fromJson<String>(json['kind']),
      bytes: serializer.fromJson<int>(json['bytes']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      posterId: serializer.fromJson<String?>(json['posterId']),
      fieldClocks: serializer.fromJson<String>(json['fieldClocks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'relPath': serializer.toJson<String>(relPath),
      'mime': serializer.toJson<String>(mime),
      'kind': serializer.toJson<String>(kind),
      'bytes': serializer.toJson<int>(bytes),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'durationMs': serializer.toJson<int?>(durationMs),
      'createdAt': serializer.toJson<int>(createdAt),
      'posterId': serializer.toJson<String?>(posterId),
      'fieldClocks': serializer.toJson<String>(fieldClocks),
    };
  }

  MediaBlob copyWith({
    String? id,
    String? relPath,
    String? mime,
    String? kind,
    int? bytes,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? createdAt,
    Value<String?> posterId = const Value.absent(),
    String? fieldClocks,
  }) => MediaBlob(
    id: id ?? this.id,
    relPath: relPath ?? this.relPath,
    mime: mime ?? this.mime,
    kind: kind ?? this.kind,
    bytes: bytes ?? this.bytes,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    createdAt: createdAt ?? this.createdAt,
    posterId: posterId.present ? posterId.value : this.posterId,
    fieldClocks: fieldClocks ?? this.fieldClocks,
  );
  MediaBlob copyWithCompanion(MediaBlobsCompanion data) {
    return MediaBlob(
      id: data.id.present ? data.id.value : this.id,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      mime: data.mime.present ? data.mime.value : this.mime,
      kind: data.kind.present ? data.kind.value : this.kind,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      posterId: data.posterId.present ? data.posterId.value : this.posterId,
      fieldClocks: data.fieldClocks.present
          ? data.fieldClocks.value
          : this.fieldClocks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaBlob(')
          ..write('id: $id, ')
          ..write('relPath: $relPath, ')
          ..write('mime: $mime, ')
          ..write('kind: $kind, ')
          ..write('bytes: $bytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('posterId: $posterId, ')
          ..write('fieldClocks: $fieldClocks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    relPath,
    mime,
    kind,
    bytes,
    width,
    height,
    durationMs,
    createdAt,
    posterId,
    fieldClocks,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaBlob &&
          other.id == this.id &&
          other.relPath == this.relPath &&
          other.mime == this.mime &&
          other.kind == this.kind &&
          other.bytes == this.bytes &&
          other.width == this.width &&
          other.height == this.height &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt &&
          other.posterId == this.posterId &&
          other.fieldClocks == this.fieldClocks);
}

class MediaBlobsCompanion extends UpdateCompanion<MediaBlob> {
  final Value<String> id;
  final Value<String> relPath;
  final Value<String> mime;
  final Value<String> kind;
  final Value<int> bytes;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> durationMs;
  final Value<int> createdAt;
  final Value<String?> posterId;
  final Value<String> fieldClocks;
  final Value<int> rowid;
  const MediaBlobsCompanion({
    this.id = const Value.absent(),
    this.relPath = const Value.absent(),
    this.mime = const Value.absent(),
    this.kind = const Value.absent(),
    this.bytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.posterId = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaBlobsCompanion.insert({
    required String id,
    required String relPath,
    required String mime,
    required String kind,
    required int bytes,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int createdAt,
    this.posterId = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       relPath = Value(relPath),
       mime = Value(mime),
       kind = Value(kind),
       bytes = Value(bytes),
       createdAt = Value(createdAt);
  static Insertable<MediaBlob> custom({
    Expression<String>? id,
    Expression<String>? relPath,
    Expression<String>? mime,
    Expression<String>? kind,
    Expression<int>? bytes,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? durationMs,
    Expression<int>? createdAt,
    Expression<String>? posterId,
    Expression<String>? fieldClocks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (relPath != null) 'rel_path': relPath,
      if (mime != null) 'mime': mime,
      if (kind != null) 'kind': kind,
      if (bytes != null) 'bytes': bytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (posterId != null) 'poster_id': posterId,
      if (fieldClocks != null) 'field_clocks': fieldClocks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaBlobsCompanion copyWith({
    Value<String>? id,
    Value<String>? relPath,
    Value<String>? mime,
    Value<String>? kind,
    Value<int>? bytes,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? durationMs,
    Value<int>? createdAt,
    Value<String?>? posterId,
    Value<String>? fieldClocks,
    Value<int>? rowid,
  }) {
    return MediaBlobsCompanion(
      id: id ?? this.id,
      relPath: relPath ?? this.relPath,
      mime: mime ?? this.mime,
      kind: kind ?? this.kind,
      bytes: bytes ?? this.bytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      posterId: posterId ?? this.posterId,
      fieldClocks: fieldClocks ?? this.fieldClocks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (posterId.present) {
      map['poster_id'] = Variable<String>(posterId.value);
    }
    if (fieldClocks.present) {
      map['field_clocks'] = Variable<String>(fieldClocks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaBlobsCompanion(')
          ..write('id: $id, ')
          ..write('relPath: $relPath, ')
          ..write('mime: $mime, ')
          ..write('kind: $kind, ')
          ..write('bytes: $bytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('posterId: $posterId, ')
          ..write('fieldClocks: $fieldClocks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DaysTable extends Days with TableInfo<$DaysTable, Day> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodIdMeta = const VerificationMeta('moodId');
  @override
  late final GeneratedColumn<String> moodId = GeneratedColumn<String>(
    'mood_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldClocksMeta = const VerificationMeta(
    'fieldClocks',
  );
  @override
  late final GeneratedColumn<String> fieldClocks = GeneratedColumn<String>(
    'field_clocks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    moodId,
    createdAt,
    updatedAt,
    deletedAt,
    fieldClocks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'days';
  @override
  VerificationContext validateIntegrity(
    Insertable<Day> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('mood_id')) {
      context.handle(
        _moodIdMeta,
        moodId.isAcceptableOrUnknown(data['mood_id']!, _moodIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('field_clocks')) {
      context.handle(
        _fieldClocksMeta,
        fieldClocks.isAcceptableOrUnknown(
          data['field_clocks']!,
          _fieldClocksMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Day map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Day(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      moodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      fieldClocks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clocks'],
      )!,
    );
  }

  @override
  $DaysTable createAlias(String alias) {
    return $DaysTable(attachedDatabase, alias);
  }
}

class Day extends DataClass implements Insertable<Day> {
  final String id;
  final String date;
  final String? moodId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String fieldClocks;
  const Day({
    required this.id,
    required this.date,
    this.moodId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.fieldClocks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || moodId != null) {
      map['mood_id'] = Variable<String>(moodId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['field_clocks'] = Variable<String>(fieldClocks);
    return map;
  }

  DaysCompanion toCompanion(bool nullToAbsent) {
    return DaysCompanion(
      id: Value(id),
      date: Value(date),
      moodId: moodId == null && nullToAbsent
          ? const Value.absent()
          : Value(moodId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      fieldClocks: Value(fieldClocks),
    );
  }

  factory Day.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Day(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      moodId: serializer.fromJson<String?>(json['moodId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      fieldClocks: serializer.fromJson<String>(json['fieldClocks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'moodId': serializer.toJson<String?>(moodId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'fieldClocks': serializer.toJson<String>(fieldClocks),
    };
  }

  Day copyWith({
    String? id,
    String? date,
    Value<String?> moodId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? fieldClocks,
  }) => Day(
    id: id ?? this.id,
    date: date ?? this.date,
    moodId: moodId.present ? moodId.value : this.moodId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    fieldClocks: fieldClocks ?? this.fieldClocks,
  );
  Day copyWithCompanion(DaysCompanion data) {
    return Day(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      moodId: data.moodId.present ? data.moodId.value : this.moodId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      fieldClocks: data.fieldClocks.present
          ? data.fieldClocks.value
          : this.fieldClocks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Day(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('moodId: $moodId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldClocks: $fieldClocks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    moodId,
    createdAt,
    updatedAt,
    deletedAt,
    fieldClocks,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Day &&
          other.id == this.id &&
          other.date == this.date &&
          other.moodId == this.moodId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.fieldClocks == this.fieldClocks);
}

class DaysCompanion extends UpdateCompanion<Day> {
  final Value<String> id;
  final Value<String> date;
  final Value<String?> moodId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> fieldClocks;
  final Value<int> rowid;
  const DaysCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.moodId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DaysCompanion.insert({
    required String id,
    required String date,
    this.moodId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Day> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? moodId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? fieldClocks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (moodId != null) 'mood_id': moodId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (fieldClocks != null) 'field_clocks': fieldClocks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DaysCompanion copyWith({
    Value<String>? id,
    Value<String>? date,
    Value<String?>? moodId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? fieldClocks,
    Value<int>? rowid,
  }) {
    return DaysCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      moodId: moodId ?? this.moodId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      fieldClocks: fieldClocks ?? this.fieldClocks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (moodId.present) {
      map['mood_id'] = Variable<String>(moodId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (fieldClocks.present) {
      map['field_clocks'] = Variable<String>(fieldClocks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DaysCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('moodId: $moodId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldClocks: $fieldClocks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<String> dayId = GeneratedColumn<String>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailMediaIdMeta = const VerificationMeta(
    'thumbnailMediaId',
  );
  @override
  late final GeneratedColumn<String> thumbnailMediaId = GeneratedColumn<String>(
    'thumbnail_media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictSourceDeviceMeta =
      const VerificationMeta('conflictSourceDevice');
  @override
  late final GeneratedColumn<String> conflictSourceDevice =
      GeneratedColumn<String>(
        'conflict_source_device',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _textVersionMeta = const VerificationMeta(
    'textVersion',
  );
  @override
  late final GeneratedColumn<String> textVersion = GeneratedColumn<String>(
    'text_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _fieldClocksMeta = const VerificationMeta(
    'fieldClocks',
  );
  @override
  late final GeneratedColumn<String> fieldClocks = GeneratedColumn<String>(
    'field_clocks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayId,
    type,
    textContent,
    mediaId,
    thumbnailMediaId,
    durationMs,
    createdAt,
    updatedAt,
    deletedAt,
    conflictSourceDevice,
    textVersion,
    fieldClocks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('day_id')) {
      context.handle(
        _dayIdMeta,
        dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    }
    if (data.containsKey('thumbnail_media_id')) {
      context.handle(
        _thumbnailMediaIdMeta,
        thumbnailMediaId.isAcceptableOrUnknown(
          data['thumbnail_media_id']!,
          _thumbnailMediaIdMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('conflict_source_device')) {
      context.handle(
        _conflictSourceDeviceMeta,
        conflictSourceDevice.isAcceptableOrUnknown(
          data['conflict_source_device']!,
          _conflictSourceDeviceMeta,
        ),
      );
    }
    if (data.containsKey('text_version')) {
      context.handle(
        _textVersionMeta,
        textVersion.isAcceptableOrUnknown(
          data['text_version']!,
          _textVersionMeta,
        ),
      );
    }
    if (data.containsKey('field_clocks')) {
      context.handle(
        _fieldClocksMeta,
        fieldClocks.isAcceptableOrUnknown(
          data['field_clocks']!,
          _fieldClocksMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      ),
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      ),
      thumbnailMediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_media_id'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      conflictSourceDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_source_device'],
      ),
      textVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_version'],
      )!,
      fieldClocks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clocks'],
      )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final String id;
  final String dayId;
  final String type;
  final String? textContent;
  final String? mediaId;
  final String? thumbnailMediaId;
  final int? durationMs;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String? conflictSourceDevice;
  final String textVersion;
  final String fieldClocks;
  const Entry({
    required this.id,
    required this.dayId,
    required this.type,
    this.textContent,
    this.mediaId,
    this.thumbnailMediaId,
    this.durationMs,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.conflictSourceDevice,
    required this.textVersion,
    required this.fieldClocks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['day_id'] = Variable<String>(dayId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || textContent != null) {
      map['text_content'] = Variable<String>(textContent);
    }
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<String>(mediaId);
    }
    if (!nullToAbsent || thumbnailMediaId != null) {
      map['thumbnail_media_id'] = Variable<String>(thumbnailMediaId);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || conflictSourceDevice != null) {
      map['conflict_source_device'] = Variable<String>(conflictSourceDevice);
    }
    map['text_version'] = Variable<String>(textVersion);
    map['field_clocks'] = Variable<String>(fieldClocks);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      dayId: Value(dayId),
      type: Value(type),
      textContent: textContent == null && nullToAbsent
          ? const Value.absent()
          : Value(textContent),
      mediaId: mediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaId),
      thumbnailMediaId: thumbnailMediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailMediaId),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      conflictSourceDevice: conflictSourceDevice == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictSourceDevice),
      textVersion: Value(textVersion),
      fieldClocks: Value(fieldClocks),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      dayId: serializer.fromJson<String>(json['dayId']),
      type: serializer.fromJson<String>(json['type']),
      textContent: serializer.fromJson<String?>(json['textContent']),
      mediaId: serializer.fromJson<String?>(json['mediaId']),
      thumbnailMediaId: serializer.fromJson<String?>(json['thumbnailMediaId']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      conflictSourceDevice: serializer.fromJson<String?>(
        json['conflictSourceDevice'],
      ),
      textVersion: serializer.fromJson<String>(json['textVersion']),
      fieldClocks: serializer.fromJson<String>(json['fieldClocks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dayId': serializer.toJson<String>(dayId),
      'type': serializer.toJson<String>(type),
      'textContent': serializer.toJson<String?>(textContent),
      'mediaId': serializer.toJson<String?>(mediaId),
      'thumbnailMediaId': serializer.toJson<String?>(thumbnailMediaId),
      'durationMs': serializer.toJson<int?>(durationMs),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'conflictSourceDevice': serializer.toJson<String?>(conflictSourceDevice),
      'textVersion': serializer.toJson<String>(textVersion),
      'fieldClocks': serializer.toJson<String>(fieldClocks),
    };
  }

  Entry copyWith({
    String? id,
    String? dayId,
    String? type,
    Value<String?> textContent = const Value.absent(),
    Value<String?> mediaId = const Value.absent(),
    Value<String?> thumbnailMediaId = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    Value<String?> conflictSourceDevice = const Value.absent(),
    String? textVersion,
    String? fieldClocks,
  }) => Entry(
    id: id ?? this.id,
    dayId: dayId ?? this.dayId,
    type: type ?? this.type,
    textContent: textContent.present ? textContent.value : this.textContent,
    mediaId: mediaId.present ? mediaId.value : this.mediaId,
    thumbnailMediaId: thumbnailMediaId.present
        ? thumbnailMediaId.value
        : this.thumbnailMediaId,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    conflictSourceDevice: conflictSourceDevice.present
        ? conflictSourceDevice.value
        : this.conflictSourceDevice,
    textVersion: textVersion ?? this.textVersion,
    fieldClocks: fieldClocks ?? this.fieldClocks,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      type: data.type.present ? data.type.value : this.type,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      thumbnailMediaId: data.thumbnailMediaId.present
          ? data.thumbnailMediaId.value
          : this.thumbnailMediaId,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      conflictSourceDevice: data.conflictSourceDevice.present
          ? data.conflictSourceDevice.value
          : this.conflictSourceDevice,
      textVersion: data.textVersion.present
          ? data.textVersion.value
          : this.textVersion,
      fieldClocks: data.fieldClocks.present
          ? data.fieldClocks.value
          : this.fieldClocks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('type: $type, ')
          ..write('textContent: $textContent, ')
          ..write('mediaId: $mediaId, ')
          ..write('thumbnailMediaId: $thumbnailMediaId, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('conflictSourceDevice: $conflictSourceDevice, ')
          ..write('textVersion: $textVersion, ')
          ..write('fieldClocks: $fieldClocks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dayId,
    type,
    textContent,
    mediaId,
    thumbnailMediaId,
    durationMs,
    createdAt,
    updatedAt,
    deletedAt,
    conflictSourceDevice,
    textVersion,
    fieldClocks,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.dayId == this.dayId &&
          other.type == this.type &&
          other.textContent == this.textContent &&
          other.mediaId == this.mediaId &&
          other.thumbnailMediaId == this.thumbnailMediaId &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.conflictSourceDevice == this.conflictSourceDevice &&
          other.textVersion == this.textVersion &&
          other.fieldClocks == this.fieldClocks);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<String> dayId;
  final Value<String> type;
  final Value<String?> textContent;
  final Value<String?> mediaId;
  final Value<String?> thumbnailMediaId;
  final Value<int?> durationMs;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String?> conflictSourceDevice;
  final Value<String> textVersion;
  final Value<String> fieldClocks;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.dayId = const Value.absent(),
    this.type = const Value.absent(),
    this.textContent = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.thumbnailMediaId = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.conflictSourceDevice = const Value.absent(),
    this.textVersion = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String dayId,
    required String type,
    this.textContent = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.thumbnailMediaId = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.conflictSourceDevice = const Value.absent(),
    this.textVersion = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dayId = Value(dayId),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Entry> custom({
    Expression<String>? id,
    Expression<String>? dayId,
    Expression<String>? type,
    Expression<String>? textContent,
    Expression<String>? mediaId,
    Expression<String>? thumbnailMediaId,
    Expression<int>? durationMs,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? conflictSourceDevice,
    Expression<String>? textVersion,
    Expression<String>? fieldClocks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayId != null) 'day_id': dayId,
      if (type != null) 'type': type,
      if (textContent != null) 'text_content': textContent,
      if (mediaId != null) 'media_id': mediaId,
      if (thumbnailMediaId != null) 'thumbnail_media_id': thumbnailMediaId,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (conflictSourceDevice != null)
        'conflict_source_device': conflictSourceDevice,
      if (textVersion != null) 'text_version': textVersion,
      if (fieldClocks != null) 'field_clocks': fieldClocks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? dayId,
    Value<String>? type,
    Value<String?>? textContent,
    Value<String?>? mediaId,
    Value<String?>? thumbnailMediaId,
    Value<int?>? durationMs,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String?>? conflictSourceDevice,
    Value<String>? textVersion,
    Value<String>? fieldClocks,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      type: type ?? this.type,
      textContent: textContent ?? this.textContent,
      mediaId: mediaId ?? this.mediaId,
      thumbnailMediaId: thumbnailMediaId ?? this.thumbnailMediaId,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      conflictSourceDevice: conflictSourceDevice ?? this.conflictSourceDevice,
      textVersion: textVersion ?? this.textVersion,
      fieldClocks: fieldClocks ?? this.fieldClocks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<String>(dayId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (thumbnailMediaId.present) {
      map['thumbnail_media_id'] = Variable<String>(thumbnailMediaId.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (conflictSourceDevice.present) {
      map['conflict_source_device'] = Variable<String>(
        conflictSourceDevice.value,
      );
    }
    if (textVersion.present) {
      map['text_version'] = Variable<String>(textVersion.value);
    }
    if (fieldClocks.present) {
      map['field_clocks'] = Variable<String>(fieldClocks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('type: $type, ')
          ..write('textContent: $textContent, ')
          ..write('mediaId: $mediaId, ')
          ..write('thumbnailMediaId: $thumbnailMediaId, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('conflictSourceDevice: $conflictSourceDevice, ')
          ..write('textVersion: $textVersion, ')
          ..write('fieldClocks: $fieldClocks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryPhotosTable extends EntryPhotos
    with TableInfo<$EntryPhotosTable, EntryPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldClocksMeta = const VerificationMeta(
    'fieldClocks',
  );
  @override
  late final GeneratedColumn<String> fieldClocks = GeneratedColumn<String>(
    'field_clocks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryId,
    mediaId,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
    fieldClocks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryPhoto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('field_clocks')) {
      context.handle(
        _fieldClocksMeta,
        fieldClocks.isAcceptableOrUnknown(
          data['field_clocks']!,
          _fieldClocksMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryPhoto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      fieldClocks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clocks'],
      )!,
    );
  }

  @override
  $EntryPhotosTable createAlias(String alias) {
    return $EntryPhotosTable(attachedDatabase, alias);
  }
}

class EntryPhoto extends DataClass implements Insertable<EntryPhoto> {
  final String id;
  final String entryId;
  final String mediaId;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String fieldClocks;
  const EntryPhoto({
    required this.id,
    required this.entryId,
    required this.mediaId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.fieldClocks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['media_id'] = Variable<String>(mediaId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['field_clocks'] = Variable<String>(fieldClocks);
    return map;
  }

  EntryPhotosCompanion toCompanion(bool nullToAbsent) {
    return EntryPhotosCompanion(
      id: Value(id),
      entryId: Value(entryId),
      mediaId: Value(mediaId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      fieldClocks: Value(fieldClocks),
    );
  }

  factory EntryPhoto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryPhoto(
      id: serializer.fromJson<String>(json['id']),
      entryId: serializer.fromJson<String>(json['entryId']),
      mediaId: serializer.fromJson<String>(json['mediaId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      fieldClocks: serializer.fromJson<String>(json['fieldClocks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entryId': serializer.toJson<String>(entryId),
      'mediaId': serializer.toJson<String>(mediaId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'fieldClocks': serializer.toJson<String>(fieldClocks),
    };
  }

  EntryPhoto copyWith({
    String? id,
    String? entryId,
    String? mediaId,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? fieldClocks,
  }) => EntryPhoto(
    id: id ?? this.id,
    entryId: entryId ?? this.entryId,
    mediaId: mediaId ?? this.mediaId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    fieldClocks: fieldClocks ?? this.fieldClocks,
  );
  EntryPhoto copyWithCompanion(EntryPhotosCompanion data) {
    return EntryPhoto(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      fieldClocks: data.fieldClocks.present
          ? data.fieldClocks.value
          : this.fieldClocks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryPhoto(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('mediaId: $mediaId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldClocks: $fieldClocks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entryId,
    mediaId,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
    fieldClocks,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryPhoto &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.mediaId == this.mediaId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.fieldClocks == this.fieldClocks);
}

class EntryPhotosCompanion extends UpdateCompanion<EntryPhoto> {
  final Value<String> id;
  final Value<String> entryId;
  final Value<String> mediaId;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> fieldClocks;
  final Value<int> rowid;
  const EntryPhotosCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryPhotosCompanion.insert({
    required String id,
    required String entryId,
    required String mediaId,
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entryId = Value(entryId),
       mediaId = Value(mediaId),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<EntryPhoto> custom({
    Expression<String>? id,
    Expression<String>? entryId,
    Expression<String>? mediaId,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? fieldClocks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (mediaId != null) 'media_id': mediaId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (fieldClocks != null) 'field_clocks': fieldClocks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? entryId,
    Value<String>? mediaId,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? fieldClocks,
    Value<int>? rowid,
  }) {
    return EntryPhotosCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      mediaId: mediaId ?? this.mediaId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      fieldClocks: fieldClocks ?? this.fieldClocks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (fieldClocks.present) {
      map['field_clocks'] = Variable<String>(fieldClocks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryPhotosCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('mediaId: $mediaId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('fieldClocks: $fieldClocks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalSettingsTable extends JournalSettings
    with TableInfo<$JournalSettingsTable, JournalSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldClocksMeta = const VerificationMeta(
    'fieldClocks',
  );
  @override
  late final GeneratedColumn<String> fieldClocks = GeneratedColumn<String>(
    'field_clocks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, fieldClocks];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('field_clocks')) {
      context.handle(
        _fieldClocksMeta,
        fieldClocks.isAcceptableOrUnknown(
          data['field_clocks']!,
          _fieldClocksMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  JournalSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      fieldClocks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_clocks'],
      )!,
    );
  }

  @override
  $JournalSettingsTable createAlias(String alias) {
    return $JournalSettingsTable(attachedDatabase, alias);
  }
}

class JournalSetting extends DataClass implements Insertable<JournalSetting> {
  final String key;
  final String value;
  final String fieldClocks;
  const JournalSetting({
    required this.key,
    required this.value,
    required this.fieldClocks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['field_clocks'] = Variable<String>(fieldClocks);
    return map;
  }

  JournalSettingsCompanion toCompanion(bool nullToAbsent) {
    return JournalSettingsCompanion(
      key: Value(key),
      value: Value(value),
      fieldClocks: Value(fieldClocks),
    );
  }

  factory JournalSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      fieldClocks: serializer.fromJson<String>(json['fieldClocks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'fieldClocks': serializer.toJson<String>(fieldClocks),
    };
  }

  JournalSetting copyWith({String? key, String? value, String? fieldClocks}) =>
      JournalSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        fieldClocks: fieldClocks ?? this.fieldClocks,
      );
  JournalSetting copyWithCompanion(JournalSettingsCompanion data) {
    return JournalSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      fieldClocks: data.fieldClocks.present
          ? data.fieldClocks.value
          : this.fieldClocks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('fieldClocks: $fieldClocks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, fieldClocks);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.fieldClocks == this.fieldClocks);
}

class JournalSettingsCompanion extends UpdateCompanion<JournalSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<String> fieldClocks;
  final Value<int> rowid;
  const JournalSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalSettingsCompanion.insert({
    required String key,
    required String value,
    this.fieldClocks = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<JournalSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? fieldClocks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (fieldClocks != null) 'field_clocks': fieldClocks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<String>? fieldClocks,
    Value<int>? rowid,
  }) {
    return JournalSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      fieldClocks: fieldClocks ?? this.fieldClocks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (fieldClocks.present) {
      map['field_clocks'] = Variable<String>(fieldClocks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('fieldClocks: $fieldClocks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordTableMeta = const VerificationMeta(
    'recordTable',
  );
  @override
  late final GeneratedColumn<String> recordTable = GeneratedColumn<String>(
    'record_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changeIdMeta = const VerificationMeta(
    'changeId',
  );
  @override
  late final GeneratedColumn<String> changeId = GeneratedColumn<String>(
    'change_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<int> enqueuedAt = GeneratedColumn<int>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordTable,
    rowId,
    changeId,
    enqueuedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_table')) {
      context.handle(
        _recordTableMeta,
        recordTable.isAcceptableOrUnknown(
          data['record_table']!,
          _recordTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('change_id')) {
      context.handle(
        _changeIdMeta,
        changeId.isAcceptableOrUnknown(data['change_id']!, _changeIdMeta),
      );
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      changeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_id'],
      ),
      enqueuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enqueued_at'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final int id;
  final String recordTable;
  final String rowId;
  final String? changeId;
  final int enqueuedAt;
  const SyncOutboxData({
    required this.id,
    required this.recordTable,
    required this.rowId,
    this.changeId,
    required this.enqueuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record_table'] = Variable<String>(recordTable);
    map['row_id'] = Variable<String>(rowId);
    if (!nullToAbsent || changeId != null) {
      map['change_id'] = Variable<String>(changeId);
    }
    map['enqueued_at'] = Variable<int>(enqueuedAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      recordTable: Value(recordTable),
      rowId: Value(rowId),
      changeId: changeId == null && nullToAbsent
          ? const Value.absent()
          : Value(changeId),
      enqueuedAt: Value(enqueuedAt),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      id: serializer.fromJson<int>(json['id']),
      recordTable: serializer.fromJson<String>(json['recordTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      changeId: serializer.fromJson<String?>(json['changeId']),
      enqueuedAt: serializer.fromJson<int>(json['enqueuedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordTable': serializer.toJson<String>(recordTable),
      'rowId': serializer.toJson<String>(rowId),
      'changeId': serializer.toJson<String?>(changeId),
      'enqueuedAt': serializer.toJson<int>(enqueuedAt),
    };
  }

  SyncOutboxData copyWith({
    int? id,
    String? recordTable,
    String? rowId,
    Value<String?> changeId = const Value.absent(),
    int? enqueuedAt,
  }) => SyncOutboxData(
    id: id ?? this.id,
    recordTable: recordTable ?? this.recordTable,
    rowId: rowId ?? this.rowId,
    changeId: changeId.present ? changeId.value : this.changeId,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      id: data.id.present ? data.id.value : this.id,
      recordTable: data.recordTable.present
          ? data.recordTable.value
          : this.recordTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      changeId: data.changeId.present ? data.changeId.value : this.changeId,
      enqueuedAt: data.enqueuedAt.present
          ? data.enqueuedAt.value
          : this.enqueuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('id: $id, ')
          ..write('recordTable: $recordTable, ')
          ..write('rowId: $rowId, ')
          ..write('changeId: $changeId, ')
          ..write('enqueuedAt: $enqueuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recordTable, rowId, changeId, enqueuedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.id == this.id &&
          other.recordTable == this.recordTable &&
          other.rowId == this.rowId &&
          other.changeId == this.changeId &&
          other.enqueuedAt == this.enqueuedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<int> id;
  final Value<String> recordTable;
  final Value<String> rowId;
  final Value<String?> changeId;
  final Value<int> enqueuedAt;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.recordTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.changeId = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String recordTable,
    required String rowId,
    this.changeId = const Value.absent(),
    required int enqueuedAt,
  }) : recordTable = Value(recordTable),
       rowId = Value(rowId),
       enqueuedAt = Value(enqueuedAt);
  static Insertable<SyncOutboxData> custom({
    Expression<int>? id,
    Expression<String>? recordTable,
    Expression<String>? rowId,
    Expression<String>? changeId,
    Expression<int>? enqueuedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordTable != null) 'record_table': recordTable,
      if (rowId != null) 'row_id': rowId,
      if (changeId != null) 'change_id': changeId,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? recordTable,
    Value<String>? rowId,
    Value<String?>? changeId,
    Value<int>? enqueuedAt,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      recordTable: recordTable ?? this.recordTable,
      rowId: rowId ?? this.rowId,
      changeId: changeId ?? this.changeId,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordTable.present) {
      map['record_table'] = Variable<String>(recordTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (changeId.present) {
      map['change_id'] = Variable<String>(changeId.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<int>(enqueuedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('recordTable: $recordTable, ')
          ..write('rowId: $rowId, ')
          ..write('changeId: $changeId, ')
          ..write('enqueuedAt: $enqueuedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncRecordSeqsTable extends SyncRecordSeqs
    with TableInfo<$SyncRecordSeqsTable, SyncRecordSeq> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordSeqsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordKeyMeta = const VerificationMeta(
    'recordKey',
  );
  @override
  late final GeneratedColumn<String> recordKey = GeneratedColumn<String>(
    'record_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTableMeta = const VerificationMeta(
    'recordTable',
  );
  @override
  late final GeneratedColumn<String> recordTable = GeneratedColumn<String>(
    'record_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recordKey, recordTable, rowId, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_record_seqs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecordSeq> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_key')) {
      context.handle(
        _recordKeyMeta,
        recordKey.isAcceptableOrUnknown(data['record_key']!, _recordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_recordKeyMeta);
    }
    if (data.containsKey('record_table')) {
      context.handle(
        _recordTableMeta,
        recordTable.isAcceptableOrUnknown(
          data['record_table']!,
          _recordTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordKey};
  @override
  SyncRecordSeq map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecordSeq(
      recordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_key'],
      )!,
      recordTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
    );
  }

  @override
  $SyncRecordSeqsTable createAlias(String alias) {
    return $SyncRecordSeqsTable(attachedDatabase, alias);
  }
}

class SyncRecordSeq extends DataClass implements Insertable<SyncRecordSeq> {
  final String recordKey;
  final String recordTable;
  final String rowId;
  final int seq;
  const SyncRecordSeq({
    required this.recordKey,
    required this.recordTable,
    required this.rowId,
    required this.seq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_key'] = Variable<String>(recordKey);
    map['record_table'] = Variable<String>(recordTable);
    map['row_id'] = Variable<String>(rowId);
    map['seq'] = Variable<int>(seq);
    return map;
  }

  SyncRecordSeqsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordSeqsCompanion(
      recordKey: Value(recordKey),
      recordTable: Value(recordTable),
      rowId: Value(rowId),
      seq: Value(seq),
    );
  }

  factory SyncRecordSeq.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecordSeq(
      recordKey: serializer.fromJson<String>(json['recordKey']),
      recordTable: serializer.fromJson<String>(json['recordTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordKey': serializer.toJson<String>(recordKey),
      'recordTable': serializer.toJson<String>(recordTable),
      'rowId': serializer.toJson<String>(rowId),
      'seq': serializer.toJson<int>(seq),
    };
  }

  SyncRecordSeq copyWith({
    String? recordKey,
    String? recordTable,
    String? rowId,
    int? seq,
  }) => SyncRecordSeq(
    recordKey: recordKey ?? this.recordKey,
    recordTable: recordTable ?? this.recordTable,
    rowId: rowId ?? this.rowId,
    seq: seq ?? this.seq,
  );
  SyncRecordSeq copyWithCompanion(SyncRecordSeqsCompanion data) {
    return SyncRecordSeq(
      recordKey: data.recordKey.present ? data.recordKey.value : this.recordKey,
      recordTable: data.recordTable.present
          ? data.recordTable.value
          : this.recordTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordSeq(')
          ..write('recordKey: $recordKey, ')
          ..write('recordTable: $recordTable, ')
          ..write('rowId: $rowId, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recordKey, recordTable, rowId, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecordSeq &&
          other.recordKey == this.recordKey &&
          other.recordTable == this.recordTable &&
          other.rowId == this.rowId &&
          other.seq == this.seq);
}

class SyncRecordSeqsCompanion extends UpdateCompanion<SyncRecordSeq> {
  final Value<String> recordKey;
  final Value<String> recordTable;
  final Value<String> rowId;
  final Value<int> seq;
  final Value<int> rowid;
  const SyncRecordSeqsCompanion({
    this.recordKey = const Value.absent(),
    this.recordTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRecordSeqsCompanion.insert({
    required String recordKey,
    required String recordTable,
    required String rowId,
    required int seq,
    this.rowid = const Value.absent(),
  }) : recordKey = Value(recordKey),
       recordTable = Value(recordTable),
       rowId = Value(rowId),
       seq = Value(seq);
  static Insertable<SyncRecordSeq> custom({
    Expression<String>? recordKey,
    Expression<String>? recordTable,
    Expression<String>? rowId,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordKey != null) 'record_key': recordKey,
      if (recordTable != null) 'record_table': recordTable,
      if (rowId != null) 'row_id': rowId,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRecordSeqsCompanion copyWith({
    Value<String>? recordKey,
    Value<String>? recordTable,
    Value<String>? rowId,
    Value<int>? seq,
    Value<int>? rowid,
  }) {
    return SyncRecordSeqsCompanion(
      recordKey: recordKey ?? this.recordKey,
      recordTable: recordTable ?? this.recordTable,
      rowId: rowId ?? this.rowId,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordKey.present) {
      map['record_key'] = Variable<String>(recordKey.value);
    }
    if (recordTable.present) {
      map['record_table'] = Variable<String>(recordTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordSeqsCompanion(')
          ..write('recordKey: $recordKey, ')
          ..write('recordTable: $recordTable, ')
          ..write('rowId: $rowId, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncTextBasesTable extends SyncTextBases
    with TableInfo<$SyncTextBasesTable, SyncTextBase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncTextBasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clockMeta = const VerificationMeta('clock');
  @override
  late final GeneratedColumn<String> clock = GeneratedColumn<String>(
    'clock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, textContent, clock, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_text_bases';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncTextBase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(data['text']!, _textContentMeta),
      );
    } else if (isInserting) {
      context.missing(_textContentMeta);
    }
    if (data.containsKey('clock')) {
      context.handle(
        _clockMeta,
        clock.isAcceptableOrUnknown(data['clock']!, _clockMeta),
      );
    } else if (isInserting) {
      context.missing(_clockMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  SyncTextBase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncTextBase(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      clock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clock'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $SyncTextBasesTable createAlias(String alias) {
    return $SyncTextBasesTable(attachedDatabase, alias);
  }
}

class SyncTextBase extends DataClass implements Insertable<SyncTextBase> {
  final String entryId;
  final String textContent;
  final String clock;
  final String version;
  const SyncTextBase({
    required this.entryId,
    required this.textContent,
    required this.clock,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['text'] = Variable<String>(textContent);
    map['clock'] = Variable<String>(clock);
    map['version'] = Variable<String>(version);
    return map;
  }

  SyncTextBasesCompanion toCompanion(bool nullToAbsent) {
    return SyncTextBasesCompanion(
      entryId: Value(entryId),
      textContent: Value(textContent),
      clock: Value(clock),
      version: Value(version),
    );
  }

  factory SyncTextBase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncTextBase(
      entryId: serializer.fromJson<String>(json['entryId']),
      textContent: serializer.fromJson<String>(json['textContent']),
      clock: serializer.fromJson<String>(json['clock']),
      version: serializer.fromJson<String>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'textContent': serializer.toJson<String>(textContent),
      'clock': serializer.toJson<String>(clock),
      'version': serializer.toJson<String>(version),
    };
  }

  SyncTextBase copyWith({
    String? entryId,
    String? textContent,
    String? clock,
    String? version,
  }) => SyncTextBase(
    entryId: entryId ?? this.entryId,
    textContent: textContent ?? this.textContent,
    clock: clock ?? this.clock,
    version: version ?? this.version,
  );
  SyncTextBase copyWithCompanion(SyncTextBasesCompanion data) {
    return SyncTextBase(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      clock: data.clock.present ? data.clock.value : this.clock,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncTextBase(')
          ..write('entryId: $entryId, ')
          ..write('textContent: $textContent, ')
          ..write('clock: $clock, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, textContent, clock, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncTextBase &&
          other.entryId == this.entryId &&
          other.textContent == this.textContent &&
          other.clock == this.clock &&
          other.version == this.version);
}

class SyncTextBasesCompanion extends UpdateCompanion<SyncTextBase> {
  final Value<String> entryId;
  final Value<String> textContent;
  final Value<String> clock;
  final Value<String> version;
  final Value<int> rowid;
  const SyncTextBasesCompanion({
    this.entryId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.clock = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncTextBasesCompanion.insert({
    required String entryId,
    required String textContent,
    required String clock,
    required String version,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       textContent = Value(textContent),
       clock = Value(clock),
       version = Value(version);
  static Insertable<SyncTextBase> custom({
    Expression<String>? entryId,
    Expression<String>? textContent,
    Expression<String>? clock,
    Expression<String>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (textContent != null) 'text': textContent,
      if (clock != null) 'clock': clock,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncTextBasesCompanion copyWith({
    Value<String>? entryId,
    Value<String>? textContent,
    Value<String>? clock,
    Value<String>? version,
    Value<int>? rowid,
  }) {
    return SyncTextBasesCompanion(
      entryId: entryId ?? this.entryId,
      textContent: textContent ?? this.textContent,
      clock: clock ?? this.clock,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (textContent.present) {
      map['text'] = Variable<String>(textContent.value);
    }
    if (clock.present) {
      map['clock'] = Variable<String>(clock.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncTextBasesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('textContent: $textContent, ')
          ..write('clock: $clock, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String key;
  final String value;
  const SyncState({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(key: Value(key), value: Value(value));
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncState copyWith({String? key, String? value}) =>
      SyncState(key: key ?? this.key, value: value ?? this.value);
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncState> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncHeldStatesTable extends SyncHeldStates
    with TableInfo<$SyncHeldStatesTable, SyncHeldState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncHeldStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordKeyMeta = const VerificationMeta(
    'recordKey',
  );
  @override
  late final GeneratedColumn<String> recordKey = GeneratedColumn<String>(
    'record_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateJsonMeta = const VerificationMeta(
    'stateJson',
  );
  @override
  late final GeneratedColumn<String> stateJson = GeneratedColumn<String>(
    'state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heldAtMeta = const VerificationMeta('heldAt');
  @override
  late final GeneratedColumn<int> heldAt = GeneratedColumn<int>(
    'held_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recordKey, stateJson, heldAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_held_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncHeldState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_key')) {
      context.handle(
        _recordKeyMeta,
        recordKey.isAcceptableOrUnknown(data['record_key']!, _recordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_recordKeyMeta);
    }
    if (data.containsKey('state_json')) {
      context.handle(
        _stateJsonMeta,
        stateJson.isAcceptableOrUnknown(data['state_json']!, _stateJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stateJsonMeta);
    }
    if (data.containsKey('held_at')) {
      context.handle(
        _heldAtMeta,
        heldAt.isAcceptableOrUnknown(data['held_at']!, _heldAtMeta),
      );
    } else if (isInserting) {
      context.missing(_heldAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordKey};
  @override
  SyncHeldState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncHeldState(
      recordKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_key'],
      )!,
      stateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_json'],
      )!,
      heldAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}held_at'],
      )!,
    );
  }

  @override
  $SyncHeldStatesTable createAlias(String alias) {
    return $SyncHeldStatesTable(attachedDatabase, alias);
  }
}

class SyncHeldState extends DataClass implements Insertable<SyncHeldState> {
  final String recordKey;
  final String stateJson;
  final int heldAt;
  const SyncHeldState({
    required this.recordKey,
    required this.stateJson,
    required this.heldAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_key'] = Variable<String>(recordKey);
    map['state_json'] = Variable<String>(stateJson);
    map['held_at'] = Variable<int>(heldAt);
    return map;
  }

  SyncHeldStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncHeldStatesCompanion(
      recordKey: Value(recordKey),
      stateJson: Value(stateJson),
      heldAt: Value(heldAt),
    );
  }

  factory SyncHeldState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncHeldState(
      recordKey: serializer.fromJson<String>(json['recordKey']),
      stateJson: serializer.fromJson<String>(json['stateJson']),
      heldAt: serializer.fromJson<int>(json['heldAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordKey': serializer.toJson<String>(recordKey),
      'stateJson': serializer.toJson<String>(stateJson),
      'heldAt': serializer.toJson<int>(heldAt),
    };
  }

  SyncHeldState copyWith({String? recordKey, String? stateJson, int? heldAt}) =>
      SyncHeldState(
        recordKey: recordKey ?? this.recordKey,
        stateJson: stateJson ?? this.stateJson,
        heldAt: heldAt ?? this.heldAt,
      );
  SyncHeldState copyWithCompanion(SyncHeldStatesCompanion data) {
    return SyncHeldState(
      recordKey: data.recordKey.present ? data.recordKey.value : this.recordKey,
      stateJson: data.stateJson.present ? data.stateJson.value : this.stateJson,
      heldAt: data.heldAt.present ? data.heldAt.value : this.heldAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncHeldState(')
          ..write('recordKey: $recordKey, ')
          ..write('stateJson: $stateJson, ')
          ..write('heldAt: $heldAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recordKey, stateJson, heldAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncHeldState &&
          other.recordKey == this.recordKey &&
          other.stateJson == this.stateJson &&
          other.heldAt == this.heldAt);
}

class SyncHeldStatesCompanion extends UpdateCompanion<SyncHeldState> {
  final Value<String> recordKey;
  final Value<String> stateJson;
  final Value<int> heldAt;
  final Value<int> rowid;
  const SyncHeldStatesCompanion({
    this.recordKey = const Value.absent(),
    this.stateJson = const Value.absent(),
    this.heldAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncHeldStatesCompanion.insert({
    required String recordKey,
    required String stateJson,
    required int heldAt,
    this.rowid = const Value.absent(),
  }) : recordKey = Value(recordKey),
       stateJson = Value(stateJson),
       heldAt = Value(heldAt);
  static Insertable<SyncHeldState> custom({
    Expression<String>? recordKey,
    Expression<String>? stateJson,
    Expression<int>? heldAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordKey != null) 'record_key': recordKey,
      if (stateJson != null) 'state_json': stateJson,
      if (heldAt != null) 'held_at': heldAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncHeldStatesCompanion copyWith({
    Value<String>? recordKey,
    Value<String>? stateJson,
    Value<int>? heldAt,
    Value<int>? rowid,
  }) {
    return SyncHeldStatesCompanion(
      recordKey: recordKey ?? this.recordKey,
      stateJson: stateJson ?? this.stateJson,
      heldAt: heldAt ?? this.heldAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordKey.present) {
      map['record_key'] = Variable<String>(recordKey.value);
    }
    if (stateJson.present) {
      map['state_json'] = Variable<String>(stateJson.value);
    }
    if (heldAt.present) {
      map['held_at'] = Variable<int>(heldAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncHeldStatesCompanion(')
          ..write('recordKey: $recordKey, ')
          ..write('stateJson: $stateJson, ')
          ..write('heldAt: $heldAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncUploadsTable extends SyncUploads
    with TableInfo<$SyncUploadsTable, SyncUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobNameMeta = const VerificationMeta(
    'blobName',
  );
  @override
  late final GeneratedColumn<String> blobName = GeneratedColumn<String>(
    'blob_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploadIdMeta = const VerificationMeta(
    'uploadId',
  );
  @override
  late final GeneratedColumn<String> uploadId = GeneratedColumn<String>(
    'upload_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partCountMeta = const VerificationMeta(
    'partCount',
  );
  @override
  late final GeneratedColumn<int> partCount = GeneratedColumn<int>(
    'part_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ackedPartsMeta = const VerificationMeta(
    'ackedParts',
  );
  @override
  late final GeneratedColumn<String> ackedParts = GeneratedColumn<String>(
    'acked_parts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _partsDirMeta = const VerificationMeta(
    'partsDir',
  );
  @override
  late final GeneratedColumn<String> partsDir = GeneratedColumn<String>(
    'parts_dir',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    blobId,
    blobName,
    uploadId,
    totalBytes,
    partCount,
    ackedParts,
    partsDir,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncUpload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('blob_name')) {
      context.handle(
        _blobNameMeta,
        blobName.isAcceptableOrUnknown(data['blob_name']!, _blobNameMeta),
      );
    } else if (isInserting) {
      context.missing(_blobNameMeta);
    }
    if (data.containsKey('upload_id')) {
      context.handle(
        _uploadIdMeta,
        uploadId.isAcceptableOrUnknown(data['upload_id']!, _uploadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_uploadIdMeta);
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_totalBytesMeta);
    }
    if (data.containsKey('part_count')) {
      context.handle(
        _partCountMeta,
        partCount.isAcceptableOrUnknown(data['part_count']!, _partCountMeta),
      );
    } else if (isInserting) {
      context.missing(_partCountMeta);
    }
    if (data.containsKey('acked_parts')) {
      context.handle(
        _ackedPartsMeta,
        ackedParts.isAcceptableOrUnknown(data['acked_parts']!, _ackedPartsMeta),
      );
    }
    if (data.containsKey('parts_dir')) {
      context.handle(
        _partsDirMeta,
        partsDir.isAcceptableOrUnknown(data['parts_dir']!, _partsDirMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blobId};
  @override
  SyncUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncUpload(
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      blobName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_name'],
      )!,
      uploadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_id'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      partCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}part_count'],
      )!,
      ackedParts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acked_parts'],
      )!,
      partsDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parts_dir'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $SyncUploadsTable createAlias(String alias) {
    return $SyncUploadsTable(attachedDatabase, alias);
  }
}

class SyncUpload extends DataClass implements Insertable<SyncUpload> {
  final String blobId;
  final String blobName;
  final String uploadId;
  final int totalBytes;
  final int partCount;
  final String ackedParts;
  final String? partsDir;
  final String status;
  const SyncUpload({
    required this.blobId,
    required this.blobName,
    required this.uploadId,
    required this.totalBytes,
    required this.partCount,
    required this.ackedParts,
    this.partsDir,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['blob_id'] = Variable<String>(blobId);
    map['blob_name'] = Variable<String>(blobName);
    map['upload_id'] = Variable<String>(uploadId);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['part_count'] = Variable<int>(partCount);
    map['acked_parts'] = Variable<String>(ackedParts);
    if (!nullToAbsent || partsDir != null) {
      map['parts_dir'] = Variable<String>(partsDir);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  SyncUploadsCompanion toCompanion(bool nullToAbsent) {
    return SyncUploadsCompanion(
      blobId: Value(blobId),
      blobName: Value(blobName),
      uploadId: Value(uploadId),
      totalBytes: Value(totalBytes),
      partCount: Value(partCount),
      ackedParts: Value(ackedParts),
      partsDir: partsDir == null && nullToAbsent
          ? const Value.absent()
          : Value(partsDir),
      status: Value(status),
    );
  }

  factory SyncUpload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncUpload(
      blobId: serializer.fromJson<String>(json['blobId']),
      blobName: serializer.fromJson<String>(json['blobName']),
      uploadId: serializer.fromJson<String>(json['uploadId']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      partCount: serializer.fromJson<int>(json['partCount']),
      ackedParts: serializer.fromJson<String>(json['ackedParts']),
      partsDir: serializer.fromJson<String?>(json['partsDir']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blobId': serializer.toJson<String>(blobId),
      'blobName': serializer.toJson<String>(blobName),
      'uploadId': serializer.toJson<String>(uploadId),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'partCount': serializer.toJson<int>(partCount),
      'ackedParts': serializer.toJson<String>(ackedParts),
      'partsDir': serializer.toJson<String?>(partsDir),
      'status': serializer.toJson<String>(status),
    };
  }

  SyncUpload copyWith({
    String? blobId,
    String? blobName,
    String? uploadId,
    int? totalBytes,
    int? partCount,
    String? ackedParts,
    Value<String?> partsDir = const Value.absent(),
    String? status,
  }) => SyncUpload(
    blobId: blobId ?? this.blobId,
    blobName: blobName ?? this.blobName,
    uploadId: uploadId ?? this.uploadId,
    totalBytes: totalBytes ?? this.totalBytes,
    partCount: partCount ?? this.partCount,
    ackedParts: ackedParts ?? this.ackedParts,
    partsDir: partsDir.present ? partsDir.value : this.partsDir,
    status: status ?? this.status,
  );
  SyncUpload copyWithCompanion(SyncUploadsCompanion data) {
    return SyncUpload(
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      blobName: data.blobName.present ? data.blobName.value : this.blobName,
      uploadId: data.uploadId.present ? data.uploadId.value : this.uploadId,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      partCount: data.partCount.present ? data.partCount.value : this.partCount,
      ackedParts: data.ackedParts.present
          ? data.ackedParts.value
          : this.ackedParts,
      partsDir: data.partsDir.present ? data.partsDir.value : this.partsDir,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncUpload(')
          ..write('blobId: $blobId, ')
          ..write('blobName: $blobName, ')
          ..write('uploadId: $uploadId, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('partCount: $partCount, ')
          ..write('ackedParts: $ackedParts, ')
          ..write('partsDir: $partsDir, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    blobId,
    blobName,
    uploadId,
    totalBytes,
    partCount,
    ackedParts,
    partsDir,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncUpload &&
          other.blobId == this.blobId &&
          other.blobName == this.blobName &&
          other.uploadId == this.uploadId &&
          other.totalBytes == this.totalBytes &&
          other.partCount == this.partCount &&
          other.ackedParts == this.ackedParts &&
          other.partsDir == this.partsDir &&
          other.status == this.status);
}

class SyncUploadsCompanion extends UpdateCompanion<SyncUpload> {
  final Value<String> blobId;
  final Value<String> blobName;
  final Value<String> uploadId;
  final Value<int> totalBytes;
  final Value<int> partCount;
  final Value<String> ackedParts;
  final Value<String?> partsDir;
  final Value<String> status;
  final Value<int> rowid;
  const SyncUploadsCompanion({
    this.blobId = const Value.absent(),
    this.blobName = const Value.absent(),
    this.uploadId = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.partCount = const Value.absent(),
    this.ackedParts = const Value.absent(),
    this.partsDir = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncUploadsCompanion.insert({
    required String blobId,
    required String blobName,
    required String uploadId,
    required int totalBytes,
    required int partCount,
    this.ackedParts = const Value.absent(),
    this.partsDir = const Value.absent(),
    required String status,
    this.rowid = const Value.absent(),
  }) : blobId = Value(blobId),
       blobName = Value(blobName),
       uploadId = Value(uploadId),
       totalBytes = Value(totalBytes),
       partCount = Value(partCount),
       status = Value(status);
  static Insertable<SyncUpload> custom({
    Expression<String>? blobId,
    Expression<String>? blobName,
    Expression<String>? uploadId,
    Expression<int>? totalBytes,
    Expression<int>? partCount,
    Expression<String>? ackedParts,
    Expression<String>? partsDir,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blobId != null) 'blob_id': blobId,
      if (blobName != null) 'blob_name': blobName,
      if (uploadId != null) 'upload_id': uploadId,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (partCount != null) 'part_count': partCount,
      if (ackedParts != null) 'acked_parts': ackedParts,
      if (partsDir != null) 'parts_dir': partsDir,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncUploadsCompanion copyWith({
    Value<String>? blobId,
    Value<String>? blobName,
    Value<String>? uploadId,
    Value<int>? totalBytes,
    Value<int>? partCount,
    Value<String>? ackedParts,
    Value<String?>? partsDir,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return SyncUploadsCompanion(
      blobId: blobId ?? this.blobId,
      blobName: blobName ?? this.blobName,
      uploadId: uploadId ?? this.uploadId,
      totalBytes: totalBytes ?? this.totalBytes,
      partCount: partCount ?? this.partCount,
      ackedParts: ackedParts ?? this.ackedParts,
      partsDir: partsDir ?? this.partsDir,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (blobName.present) {
      map['blob_name'] = Variable<String>(blobName.value);
    }
    if (uploadId.present) {
      map['upload_id'] = Variable<String>(uploadId.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (partCount.present) {
      map['part_count'] = Variable<int>(partCount.value);
    }
    if (ackedParts.present) {
      map['acked_parts'] = Variable<String>(ackedParts.value);
    }
    if (partsDir.present) {
      map['parts_dir'] = Variable<String>(partsDir.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncUploadsCompanion(')
          ..write('blobId: $blobId, ')
          ..write('blobName: $blobName, ')
          ..write('uploadId: $uploadId, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('partCount: $partCount, ')
          ..write('ackedParts: $ackedParts, ')
          ..write('partsDir: $partsDir, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMediaCacheTable extends SyncMediaCache
    with TableInfo<$SyncMediaCacheTable, SyncMediaCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMediaCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _blobIdMeta = const VerificationMeta('blobId');
  @override
  late final GeneratedColumn<String> blobId = GeneratedColumn<String>(
    'blob_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<int> downloadedAt = GeneratedColumn<int>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<int> lastOpenedAt = GeneratedColumn<int>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadedMeta = const VerificationMeta(
    'uploaded',
  );
  @override
  late final GeneratedColumn<bool> uploaded = GeneratedColumn<bool>(
    'uploaded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uploaded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reportedStateMeta = const VerificationMeta(
    'reportedState',
  );
  @override
  late final GeneratedColumn<String> reportedState = GeneratedColumn<String>(
    'reported_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    blobId,
    downloadedAt,
    lastOpenedAt,
    uploaded,
    reportedState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_media_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMediaCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('blob_id')) {
      context.handle(
        _blobIdMeta,
        blobId.isAcceptableOrUnknown(data['blob_id']!, _blobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blobIdMeta);
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('uploaded')) {
      context.handle(
        _uploadedMeta,
        uploaded.isAcceptableOrUnknown(data['uploaded']!, _uploadedMeta),
      );
    }
    if (data.containsKey('reported_state')) {
      context.handle(
        _reportedStateMeta,
        reportedState.isAcceptableOrUnknown(
          data['reported_state']!,
          _reportedStateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {blobId};
  @override
  SyncMediaCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMediaCacheData(
      blobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_id'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_at'],
      ),
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_opened_at'],
      ),
      uploaded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uploaded'],
      )!,
      reportedState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reported_state'],
      )!,
    );
  }

  @override
  $SyncMediaCacheTable createAlias(String alias) {
    return $SyncMediaCacheTable(attachedDatabase, alias);
  }
}

class SyncMediaCacheData extends DataClass
    implements Insertable<SyncMediaCacheData> {
  final String blobId;
  final int? downloadedAt;
  final int? lastOpenedAt;
  final bool uploaded;
  final String reportedState;
  const SyncMediaCacheData({
    required this.blobId,
    this.downloadedAt,
    this.lastOpenedAt,
    required this.uploaded,
    required this.reportedState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['blob_id'] = Variable<String>(blobId);
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<int>(downloadedAt);
    }
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<int>(lastOpenedAt);
    }
    map['uploaded'] = Variable<bool>(uploaded);
    map['reported_state'] = Variable<String>(reportedState);
    return map;
  }

  SyncMediaCacheCompanion toCompanion(bool nullToAbsent) {
    return SyncMediaCacheCompanion(
      blobId: Value(blobId),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      uploaded: Value(uploaded),
      reportedState: Value(reportedState),
    );
  }

  factory SyncMediaCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMediaCacheData(
      blobId: serializer.fromJson<String>(json['blobId']),
      downloadedAt: serializer.fromJson<int?>(json['downloadedAt']),
      lastOpenedAt: serializer.fromJson<int?>(json['lastOpenedAt']),
      uploaded: serializer.fromJson<bool>(json['uploaded']),
      reportedState: serializer.fromJson<String>(json['reportedState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blobId': serializer.toJson<String>(blobId),
      'downloadedAt': serializer.toJson<int?>(downloadedAt),
      'lastOpenedAt': serializer.toJson<int?>(lastOpenedAt),
      'uploaded': serializer.toJson<bool>(uploaded),
      'reportedState': serializer.toJson<String>(reportedState),
    };
  }

  SyncMediaCacheData copyWith({
    String? blobId,
    Value<int?> downloadedAt = const Value.absent(),
    Value<int?> lastOpenedAt = const Value.absent(),
    bool? uploaded,
    String? reportedState,
  }) => SyncMediaCacheData(
    blobId: blobId ?? this.blobId,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    uploaded: uploaded ?? this.uploaded,
    reportedState: reportedState ?? this.reportedState,
  );
  SyncMediaCacheData copyWithCompanion(SyncMediaCacheCompanion data) {
    return SyncMediaCacheData(
      blobId: data.blobId.present ? data.blobId.value : this.blobId,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      uploaded: data.uploaded.present ? data.uploaded.value : this.uploaded,
      reportedState: data.reportedState.present
          ? data.reportedState.value
          : this.reportedState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMediaCacheData(')
          ..write('blobId: $blobId, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('uploaded: $uploaded, ')
          ..write('reportedState: $reportedState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(blobId, downloadedAt, lastOpenedAt, uploaded, reportedState);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMediaCacheData &&
          other.blobId == this.blobId &&
          other.downloadedAt == this.downloadedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.uploaded == this.uploaded &&
          other.reportedState == this.reportedState);
}

class SyncMediaCacheCompanion extends UpdateCompanion<SyncMediaCacheData> {
  final Value<String> blobId;
  final Value<int?> downloadedAt;
  final Value<int?> lastOpenedAt;
  final Value<bool> uploaded;
  final Value<String> reportedState;
  final Value<int> rowid;
  const SyncMediaCacheCompanion({
    this.blobId = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.uploaded = const Value.absent(),
    this.reportedState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMediaCacheCompanion.insert({
    required String blobId,
    this.downloadedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.uploaded = const Value.absent(),
    this.reportedState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : blobId = Value(blobId);
  static Insertable<SyncMediaCacheData> custom({
    Expression<String>? blobId,
    Expression<int>? downloadedAt,
    Expression<int>? lastOpenedAt,
    Expression<bool>? uploaded,
    Expression<String>? reportedState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blobId != null) 'blob_id': blobId,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (uploaded != null) 'uploaded': uploaded,
      if (reportedState != null) 'reported_state': reportedState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMediaCacheCompanion copyWith({
    Value<String>? blobId,
    Value<int?>? downloadedAt,
    Value<int?>? lastOpenedAt,
    Value<bool>? uploaded,
    Value<String>? reportedState,
    Value<int>? rowid,
  }) {
    return SyncMediaCacheCompanion(
      blobId: blobId ?? this.blobId,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      uploaded: uploaded ?? this.uploaded,
      reportedState: reportedState ?? this.reportedState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blobId.present) {
      map['blob_id'] = Variable<String>(blobId.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<int>(downloadedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<int>(lastOpenedAt.value);
    }
    if (uploaded.present) {
      map['uploaded'] = Variable<bool>(uploaded.value);
    }
    if (reportedState.present) {
      map['reported_state'] = Variable<String>(reportedState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMediaCacheCompanion(')
          ..write('blobId: $blobId, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('uploaded: $uploaded, ')
          ..write('reportedState: $reportedState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MediaBlobsTable mediaBlobs = $MediaBlobsTable(this);
  late final $DaysTable days = $DaysTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $EntryPhotosTable entryPhotos = $EntryPhotosTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $JournalSettingsTable journalSettings = $JournalSettingsTable(
    this,
  );
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncRecordSeqsTable syncRecordSeqs = $SyncRecordSeqsTable(this);
  late final $SyncTextBasesTable syncTextBases = $SyncTextBasesTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $SyncHeldStatesTable syncHeldStates = $SyncHeldStatesTable(this);
  late final $SyncUploadsTable syncUploads = $SyncUploadsTable(this);
  late final $SyncMediaCacheTable syncMediaCache = $SyncMediaCacheTable(this);
  late final Index daysDateActive = Index(
    'days_date_active',
    'CREATE UNIQUE INDEX days_date_active ON days (date) WHERE deleted_at IS NULL',
  );
  late final Index syncOutboxRecord = Index(
    'sync_outbox_record',
    'CREATE UNIQUE INDEX sync_outbox_record ON sync_outbox (record_table, row_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mediaBlobs,
    days,
    entries,
    entryPhotos,
    settings,
    journalSettings,
    syncOutbox,
    syncRecordSeqs,
    syncTextBases,
    syncStates,
    syncHeldStates,
    syncUploads,
    syncMediaCache,
    daysDateActive,
    syncOutboxRecord,
  ];
}

typedef $$MediaBlobsTableCreateCompanionBuilder = MediaBlobsCompanion Function({
  required String id,
  required String relPath,
  required String mime,
  required String kind,
  required int bytes,
  Value<int?> width,
  Value<int?> height,
  Value<int?> durationMs,
  required int createdAt,
  Value<String?> posterId,
  Value<String> fieldClocks,
  Value<int> rowid,
});
typedef $$MediaBlobsTableUpdateCompanionBuilder = MediaBlobsCompanion Function({
  Value<String> id,
  Value<String> relPath,
  Value<String> mime,
  Value<String> kind,
  Value<int> bytes,
  Value<int?> width,
  Value<int?> height,
  Value<int?> durationMs,
  Value<int> createdAt,
  Value<String?> posterId,
  Value<String> fieldClocks,
  Value<int> rowid,
});

class $$MediaBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterId => $composableBuilder(
    column: $table.posterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterId => $composableBuilder(
    column: $table.posterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaBlobsTable> {
  $$MediaBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get posterId =>
      $composableBuilder(column: $table.posterId, builder: (column) => column);

  GeneratedColumn<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => column,
  );
}

class $$MediaBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaBlobsTable,
          MediaBlob,
          $$MediaBlobsTableFilterComposer,
          $$MediaBlobsTableOrderingComposer,
          $$MediaBlobsTableAnnotationComposer,
          $$MediaBlobsTableCreateCompanionBuilder,
          $$MediaBlobsTableUpdateCompanionBuilder,
          (
            MediaBlob,
            BaseReferences<_$AppDatabase, $MediaBlobsTable, MediaBlob>,
          ),
          MediaBlob,
          PrefetchHooks Function()
        > {
  $$MediaBlobsTableTableManager(_$AppDatabase db, $MediaBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> posterId = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaBlobsCompanion(
                id: id,
                relPath: relPath,
                mime: mime,
                kind: kind,
                bytes: bytes,
                width: width,
                height: height,
                durationMs: durationMs,
                createdAt: createdAt,
                posterId: posterId,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String relPath,
                required String mime,
                required String kind,
                required int bytes,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int createdAt,
                Value<String?> posterId = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaBlobsCompanion.insert(
                id: id,
                relPath: relPath,
                mime: mime,
                kind: kind,
                bytes: bytes,
                width: width,
                height: height,
                durationMs: durationMs,
                createdAt: createdAt,
                posterId: posterId,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaBlobsTable, MediaBlob>(table),
                  BaseReferences<_$AppDatabase, $MediaBlobsTable, MediaBlob>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaBlobsTable,
      MediaBlob,
      $$MediaBlobsTableFilterComposer,
      $$MediaBlobsTableOrderingComposer,
      $$MediaBlobsTableAnnotationComposer,
      $$MediaBlobsTableCreateCompanionBuilder,
      $$MediaBlobsTableUpdateCompanionBuilder,
      (MediaBlob, BaseReferences<_$AppDatabase, $MediaBlobsTable, MediaBlob>),
      MediaBlob,
      PrefetchHooks Function()
    >;
typedef $$DaysTableCreateCompanionBuilder = DaysCompanion Function({
  required String id,
  required String date,
  Value<String?> moodId,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<String> fieldClocks,
  Value<int> rowid,
});
typedef $$DaysTableUpdateCompanionBuilder = DaysCompanion Function({
  Value<String> id,
  Value<String> date,
  Value<String?> moodId,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> fieldClocks,
  Value<int> rowid,
});

class $$DaysTableFilterComposer extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moodId => $composableBuilder(
    column: $table.moodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DaysTableOrderingComposer extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moodId => $composableBuilder(
    column: $table.moodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $DaysTable> {
  $$DaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get moodId =>
      $composableBuilder(column: $table.moodId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => column,
  );
}

class $$DaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DaysTable,
          Day,
          $$DaysTableFilterComposer,
          $$DaysTableOrderingComposer,
          $$DaysTableAnnotationComposer,
          $$DaysTableCreateCompanionBuilder,
          $$DaysTableUpdateCompanionBuilder,
          (Day, BaseReferences<_$AppDatabase, $DaysTable, Day>),
          Day,
          PrefetchHooks Function()
        > {
  $$DaysTableTableManager(_$AppDatabase db, $DaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String?> moodId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion(
                id: id,
                date: date,
                moodId: moodId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String date,
                Value<String?> moodId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaysCompanion.insert(
                id: id,
                date: date,
                moodId: moodId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DaysTable, Day>(table),
                  BaseReferences<_$AppDatabase, $DaysTable, Day>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DaysTable,
      Day,
      $$DaysTableFilterComposer,
      $$DaysTableOrderingComposer,
      $$DaysTableAnnotationComposer,
      $$DaysTableCreateCompanionBuilder,
      $$DaysTableUpdateCompanionBuilder,
      (Day, BaseReferences<_$AppDatabase, $DaysTable, Day>),
      Day,
      PrefetchHooks Function()
    >;
typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  required String id,
  required String dayId,
  required String type,
  Value<String?> textContent,
  Value<String?> mediaId,
  Value<String?> thumbnailMediaId,
  Value<int?> durationMs,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<String?> conflictSourceDevice,
  Value<String> textVersion,
  Value<String> fieldClocks,
  Value<int> rowid,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<String> id,
  Value<String> dayId,
  Value<String> type,
  Value<String?> textContent,
  Value<String?> mediaId,
  Value<String?> thumbnailMediaId,
  Value<int?> durationMs,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String?> conflictSourceDevice,
  Value<String> textVersion,
  Value<String> fieldClocks,
  Value<int> rowid,
});

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailMediaId => $composableBuilder(
    column: $table.thumbnailMediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictSourceDevice => $composableBuilder(
    column: $table.conflictSourceDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textVersion => $composableBuilder(
    column: $table.textVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailMediaId => $composableBuilder(
    column: $table.thumbnailMediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictSourceDevice => $composableBuilder(
    column: $table.conflictSourceDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textVersion => $composableBuilder(
    column: $table.textVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dayId =>
      $composableBuilder(column: $table.dayId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get thumbnailMediaId => $composableBuilder(
    column: $table.thumbnailMediaId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get conflictSourceDevice => $composableBuilder(
    column: $table.conflictSourceDevice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textVersion => $composableBuilder(
    column: $table.textVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => column,
  );
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
          Entry,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dayId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String?> thumbnailMediaId = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> conflictSourceDevice = const Value.absent(),
                Value<String> textVersion = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                dayId: dayId,
                type: type,
                textContent: textContent,
                mediaId: mediaId,
                thumbnailMediaId: thumbnailMediaId,
                durationMs: durationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                conflictSourceDevice: conflictSourceDevice,
                textVersion: textVersion,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dayId,
                required String type,
                Value<String?> textContent = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String?> thumbnailMediaId = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> conflictSourceDevice = const Value.absent(),
                Value<String> textVersion = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                dayId: dayId,
                type: type,
                textContent: textContent,
                mediaId: mediaId,
                thumbnailMediaId: thumbnailMediaId,
                durationMs: durationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                conflictSourceDevice: conflictSourceDevice,
                textVersion: textVersion,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, Entry>(table),
                  BaseReferences<_$AppDatabase, $EntriesTable, Entry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, BaseReferences<_$AppDatabase, $EntriesTable, Entry>),
      Entry,
      PrefetchHooks Function()
    >;
typedef $$EntryPhotosTableCreateCompanionBuilder =
    EntryPhotosCompanion Function({
      required String id,
      required String entryId,
      required String mediaId,
      required int sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<String> fieldClocks,
      Value<int> rowid,
    });
typedef $$EntryPhotosTableUpdateCompanionBuilder =
    EntryPhotosCompanion Function({
      Value<String> id,
      Value<String> entryId,
      Value<String> mediaId,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> fieldClocks,
      Value<int> rowid,
    });

class $$EntryPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $EntryPhotosTable> {
  $$EntryPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $EntryPhotosTable> {
  $$EntryPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntryPhotosTable> {
  $$EntryPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => column,
  );
}

class $$EntryPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntryPhotosTable,
          EntryPhoto,
          $$EntryPhotosTableFilterComposer,
          $$EntryPhotosTableOrderingComposer,
          $$EntryPhotosTableAnnotationComposer,
          $$EntryPhotosTableCreateCompanionBuilder,
          $$EntryPhotosTableUpdateCompanionBuilder,
          (
            EntryPhoto,
            BaseReferences<_$AppDatabase, $EntryPhotosTable, EntryPhoto>,
          ),
          EntryPhoto,
          PrefetchHooks Function()
        > {
  $$EntryPhotosTableTableManager(_$AppDatabase db, $EntryPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<String> mediaId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryPhotosCompanion(
                id: id,
                entryId: entryId,
                mediaId: mediaId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entryId,
                required String mediaId,
                required int sortOrder,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryPhotosCompanion.insert(
                id: id,
                entryId: entryId,
                mediaId: mediaId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryPhotosTable, EntryPhoto>(table),
                  BaseReferences<_$AppDatabase, $EntryPhotosTable, EntryPhoto>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntryPhotosTable,
      EntryPhoto,
      $$EntryPhotosTableFilterComposer,
      $$EntryPhotosTableOrderingComposer,
      $$EntryPhotosTableAnnotationComposer,
      $$EntryPhotosTableCreateCompanionBuilder,
      $$EntryPhotosTableUpdateCompanionBuilder,
      (
        EntryPhoto,
        BaseReferences<_$AppDatabase, $EntryPhotosTable, EntryPhoto>,
      ),
      EntryPhoto,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$JournalSettingsTableCreateCompanionBuilder =
    JournalSettingsCompanion Function({
      required String key,
      required String value,
      Value<String> fieldClocks,
      Value<int> rowid,
    });
typedef $$JournalSettingsTableUpdateCompanionBuilder =
    JournalSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<String> fieldClocks,
      Value<int> rowid,
    });

class $$JournalSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $JournalSettingsTable> {
  $$JournalSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JournalSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalSettingsTable> {
  $$JournalSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JournalSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalSettingsTable> {
  $$JournalSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get fieldClocks => $composableBuilder(
    column: $table.fieldClocks,
    builder: (column) => column,
  );
}

class $$JournalSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JournalSettingsTable,
          JournalSetting,
          $$JournalSettingsTableFilterComposer,
          $$JournalSettingsTableOrderingComposer,
          $$JournalSettingsTableAnnotationComposer,
          $$JournalSettingsTableCreateCompanionBuilder,
          $$JournalSettingsTableUpdateCompanionBuilder,
          (
            JournalSetting,
            BaseReferences<
              _$AppDatabase,
              $JournalSettingsTable,
              JournalSetting
            >,
          ),
          JournalSetting,
          PrefetchHooks Function()
        > {
  $$JournalSettingsTableTableManager(
    _$AppDatabase db,
    $JournalSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalSettingsCompanion(
                key: key,
                value: value,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<String> fieldClocks = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalSettingsCompanion.insert(
                key: key,
                value: value,
                fieldClocks: fieldClocks,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JournalSettingsTable, JournalSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $JournalSettingsTable,
                    JournalSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JournalSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JournalSettingsTable,
      JournalSetting,
      $$JournalSettingsTableFilterComposer,
      $$JournalSettingsTableOrderingComposer,
      $$JournalSettingsTableAnnotationComposer,
      $$JournalSettingsTableCreateCompanionBuilder,
      $$JournalSettingsTableUpdateCompanionBuilder,
      (
        JournalSetting,
        BaseReferences<_$AppDatabase, $JournalSettingsTable, JournalSetting>,
      ),
      JournalSetting,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  required String recordTable,
  required String rowId,
  Value<String?> changeId,
  required int enqueuedAt,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  Value<String> recordTable,
  Value<String> rowId,
  Value<String?> changeId,
  Value<int> enqueuedAt,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordTable => $composableBuilder(
    column: $table.recordTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordTable => $composableBuilder(
    column: $table.recordTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordTable => $composableBuilder(
    column: $table.recordTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get changeId =>
      $composableBuilder(column: $table.changeId, builder: (column) => column);

  GeneratedColumn<int> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxData,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxData,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
          ),
          SyncOutboxData,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String?> changeId = const Value.absent(),
                Value<int> enqueuedAt = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                recordTable: recordTable,
                rowId: rowId,
                changeId: changeId,
                enqueuedAt: enqueuedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordTable,
                required String rowId,
                Value<String?> changeId = const Value.absent(),
                required int enqueuedAt,
              }) => SyncOutboxCompanion.insert(
                id: id,
                recordTable: recordTable,
                rowId: rowId,
                changeId: changeId,
                enqueuedAt: enqueuedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, SyncOutboxData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOutboxTable,
                    SyncOutboxData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxData,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxData,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
      ),
      SyncOutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncRecordSeqsTableCreateCompanionBuilder =
    SyncRecordSeqsCompanion Function({
      required String recordKey,
      required String recordTable,
      required String rowId,
      required int seq,
      Value<int> rowid,
    });
typedef $$SyncRecordSeqsTableUpdateCompanionBuilder =
    SyncRecordSeqsCompanion Function({
      Value<String> recordKey,
      Value<String> recordTable,
      Value<String> rowId,
      Value<int> seq,
      Value<int> rowid,
    });

class $$SyncRecordSeqsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRecordSeqsTable> {
  $$SyncRecordSeqsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordTable => $composableBuilder(
    column: $table.recordTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRecordSeqsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRecordSeqsTable> {
  $$SyncRecordSeqsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordTable => $composableBuilder(
    column: $table.recordTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRecordSeqsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRecordSeqsTable> {
  $$SyncRecordSeqsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordKey =>
      $composableBuilder(column: $table.recordKey, builder: (column) => column);

  GeneratedColumn<String> get recordTable => $composableBuilder(
    column: $table.recordTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $$SyncRecordSeqsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRecordSeqsTable,
          SyncRecordSeq,
          $$SyncRecordSeqsTableFilterComposer,
          $$SyncRecordSeqsTableOrderingComposer,
          $$SyncRecordSeqsTableAnnotationComposer,
          $$SyncRecordSeqsTableCreateCompanionBuilder,
          $$SyncRecordSeqsTableUpdateCompanionBuilder,
          (
            SyncRecordSeq,
            BaseReferences<_$AppDatabase, $SyncRecordSeqsTable, SyncRecordSeq>,
          ),
          SyncRecordSeq,
          PrefetchHooks Function()
        > {
  $$SyncRecordSeqsTableTableManager(
    _$AppDatabase db,
    $SyncRecordSeqsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordSeqsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordSeqsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordSeqsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recordKey = const Value.absent(),
                Value<String> recordTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordSeqsCompanion(
                recordKey: recordKey,
                recordTable: recordTable,
                rowId: rowId,
                seq: seq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordKey,
                required String recordTable,
                required String rowId,
                required int seq,
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordSeqsCompanion.insert(
                recordKey: recordKey,
                recordTable: recordTable,
                rowId: rowId,
                seq: seq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRecordSeqsTable, SyncRecordSeq>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncRecordSeqsTable,
                    SyncRecordSeq
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRecordSeqsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRecordSeqsTable,
      SyncRecordSeq,
      $$SyncRecordSeqsTableFilterComposer,
      $$SyncRecordSeqsTableOrderingComposer,
      $$SyncRecordSeqsTableAnnotationComposer,
      $$SyncRecordSeqsTableCreateCompanionBuilder,
      $$SyncRecordSeqsTableUpdateCompanionBuilder,
      (
        SyncRecordSeq,
        BaseReferences<_$AppDatabase, $SyncRecordSeqsTable, SyncRecordSeq>,
      ),
      SyncRecordSeq,
      PrefetchHooks Function()
    >;
typedef $$SyncTextBasesTableCreateCompanionBuilder =
    SyncTextBasesCompanion Function({
      required String entryId,
      required String textContent,
      required String clock,
      required String version,
      Value<int> rowid,
    });
typedef $$SyncTextBasesTableUpdateCompanionBuilder =
    SyncTextBasesCompanion Function({
      Value<String> entryId,
      Value<String> textContent,
      Value<String> clock,
      Value<String> version,
      Value<int> rowid,
    });

class $$SyncTextBasesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncTextBasesTable> {
  $$SyncTextBasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clock => $composableBuilder(
    column: $table.clock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncTextBasesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncTextBasesTable> {
  $$SyncTextBasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clock => $composableBuilder(
    column: $table.clock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncTextBasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncTextBasesTable> {
  $$SyncTextBasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clock =>
      $composableBuilder(column: $table.clock, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$SyncTextBasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncTextBasesTable,
          SyncTextBase,
          $$SyncTextBasesTableFilterComposer,
          $$SyncTextBasesTableOrderingComposer,
          $$SyncTextBasesTableAnnotationComposer,
          $$SyncTextBasesTableCreateCompanionBuilder,
          $$SyncTextBasesTableUpdateCompanionBuilder,
          (
            SyncTextBase,
            BaseReferences<_$AppDatabase, $SyncTextBasesTable, SyncTextBase>,
          ),
          SyncTextBase,
          PrefetchHooks Function()
        > {
  $$SyncTextBasesTableTableManager(_$AppDatabase db, $SyncTextBasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncTextBasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncTextBasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncTextBasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> textContent = const Value.absent(),
                Value<String> clock = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncTextBasesCompanion(
                entryId: entryId,
                textContent: textContent,
                clock: clock,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String textContent,
                required String clock,
                required String version,
                Value<int> rowid = const Value.absent(),
              }) => SyncTextBasesCompanion.insert(
                entryId: entryId,
                textContent: textContent,
                clock: clock,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncTextBasesTable, SyncTextBase>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncTextBasesTable,
                    SyncTextBase
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncTextBasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncTextBasesTable,
      SyncTextBase,
      $$SyncTextBasesTableFilterComposer,
      $$SyncTextBasesTableOrderingComposer,
      $$SyncTextBasesTableAnnotationComposer,
      $$SyncTextBasesTableCreateCompanionBuilder,
      $$SyncTextBasesTableUpdateCompanionBuilder,
      (
        SyncTextBase,
        BaseReferences<_$AppDatabase, $SyncTextBasesTable, SyncTextBase>,
      ),
      SyncTextBase,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncState,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>,
          ),
          SyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncStatesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStatesTable, SyncState>(table),
                  BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
      SyncState,
      PrefetchHooks Function()
    >;
typedef $$SyncHeldStatesTableCreateCompanionBuilder =
    SyncHeldStatesCompanion Function({
      required String recordKey,
      required String stateJson,
      required int heldAt,
      Value<int> rowid,
    });
typedef $$SyncHeldStatesTableUpdateCompanionBuilder =
    SyncHeldStatesCompanion Function({
      Value<String> recordKey,
      Value<String> stateJson,
      Value<int> heldAt,
      Value<int> rowid,
    });

class $$SyncHeldStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncHeldStatesTable> {
  $$SyncHeldStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heldAt => $composableBuilder(
    column: $table.heldAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncHeldStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncHeldStatesTable> {
  $$SyncHeldStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heldAt => $composableBuilder(
    column: $table.heldAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncHeldStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncHeldStatesTable> {
  $$SyncHeldStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordKey =>
      $composableBuilder(column: $table.recordKey, builder: (column) => column);

  GeneratedColumn<String> get stateJson =>
      $composableBuilder(column: $table.stateJson, builder: (column) => column);

  GeneratedColumn<int> get heldAt =>
      $composableBuilder(column: $table.heldAt, builder: (column) => column);
}

class $$SyncHeldStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncHeldStatesTable,
          SyncHeldState,
          $$SyncHeldStatesTableFilterComposer,
          $$SyncHeldStatesTableOrderingComposer,
          $$SyncHeldStatesTableAnnotationComposer,
          $$SyncHeldStatesTableCreateCompanionBuilder,
          $$SyncHeldStatesTableUpdateCompanionBuilder,
          (
            SyncHeldState,
            BaseReferences<_$AppDatabase, $SyncHeldStatesTable, SyncHeldState>,
          ),
          SyncHeldState,
          PrefetchHooks Function()
        > {
  $$SyncHeldStatesTableTableManager(
    _$AppDatabase db,
    $SyncHeldStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncHeldStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncHeldStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncHeldStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recordKey = const Value.absent(),
                Value<String> stateJson = const Value.absent(),
                Value<int> heldAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncHeldStatesCompanion(
                recordKey: recordKey,
                stateJson: stateJson,
                heldAt: heldAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordKey,
                required String stateJson,
                required int heldAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncHeldStatesCompanion.insert(
                recordKey: recordKey,
                stateJson: stateJson,
                heldAt: heldAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncHeldStatesTable, SyncHeldState>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncHeldStatesTable,
                    SyncHeldState
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncHeldStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncHeldStatesTable,
      SyncHeldState,
      $$SyncHeldStatesTableFilterComposer,
      $$SyncHeldStatesTableOrderingComposer,
      $$SyncHeldStatesTableAnnotationComposer,
      $$SyncHeldStatesTableCreateCompanionBuilder,
      $$SyncHeldStatesTableUpdateCompanionBuilder,
      (
        SyncHeldState,
        BaseReferences<_$AppDatabase, $SyncHeldStatesTable, SyncHeldState>,
      ),
      SyncHeldState,
      PrefetchHooks Function()
    >;
typedef $$SyncUploadsTableCreateCompanionBuilder =
    SyncUploadsCompanion Function({
      required String blobId,
      required String blobName,
      required String uploadId,
      required int totalBytes,
      required int partCount,
      Value<String> ackedParts,
      Value<String?> partsDir,
      required String status,
      Value<int> rowid,
    });
typedef $$SyncUploadsTableUpdateCompanionBuilder =
    SyncUploadsCompanion Function({
      Value<String> blobId,
      Value<String> blobName,
      Value<String> uploadId,
      Value<int> totalBytes,
      Value<int> partCount,
      Value<String> ackedParts,
      Value<String?> partsDir,
      Value<String> status,
      Value<int> rowid,
    });

class $$SyncUploadsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncUploadsTable> {
  $$SyncUploadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobName => $composableBuilder(
    column: $table.blobName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadId => $composableBuilder(
    column: $table.uploadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partCount => $composableBuilder(
    column: $table.partCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ackedParts => $composableBuilder(
    column: $table.ackedParts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partsDir => $composableBuilder(
    column: $table.partsDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncUploadsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncUploadsTable> {
  $$SyncUploadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobName => $composableBuilder(
    column: $table.blobName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadId => $composableBuilder(
    column: $table.uploadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partCount => $composableBuilder(
    column: $table.partCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ackedParts => $composableBuilder(
    column: $table.ackedParts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partsDir => $composableBuilder(
    column: $table.partsDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncUploadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncUploadsTable> {
  $$SyncUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<String> get blobName =>
      $composableBuilder(column: $table.blobName, builder: (column) => column);

  GeneratedColumn<String> get uploadId =>
      $composableBuilder(column: $table.uploadId, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get partCount =>
      $composableBuilder(column: $table.partCount, builder: (column) => column);

  GeneratedColumn<String> get ackedParts => $composableBuilder(
    column: $table.ackedParts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get partsDir =>
      $composableBuilder(column: $table.partsDir, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$SyncUploadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncUploadsTable,
          SyncUpload,
          $$SyncUploadsTableFilterComposer,
          $$SyncUploadsTableOrderingComposer,
          $$SyncUploadsTableAnnotationComposer,
          $$SyncUploadsTableCreateCompanionBuilder,
          $$SyncUploadsTableUpdateCompanionBuilder,
          (
            SyncUpload,
            BaseReferences<_$AppDatabase, $SyncUploadsTable, SyncUpload>,
          ),
          SyncUpload,
          PrefetchHooks Function()
        > {
  $$SyncUploadsTableTableManager(_$AppDatabase db, $SyncUploadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> blobId = const Value.absent(),
                Value<String> blobName = const Value.absent(),
                Value<String> uploadId = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> partCount = const Value.absent(),
                Value<String> ackedParts = const Value.absent(),
                Value<String?> partsDir = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncUploadsCompanion(
                blobId: blobId,
                blobName: blobName,
                uploadId: uploadId,
                totalBytes: totalBytes,
                partCount: partCount,
                ackedParts: ackedParts,
                partsDir: partsDir,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blobId,
                required String blobName,
                required String uploadId,
                required int totalBytes,
                required int partCount,
                Value<String> ackedParts = const Value.absent(),
                Value<String?> partsDir = const Value.absent(),
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => SyncUploadsCompanion.insert(
                blobId: blobId,
                blobName: blobName,
                uploadId: uploadId,
                totalBytes: totalBytes,
                partCount: partCount,
                ackedParts: ackedParts,
                partsDir: partsDir,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncUploadsTable, SyncUpload>(table),
                  BaseReferences<_$AppDatabase, $SyncUploadsTable, SyncUpload>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncUploadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncUploadsTable,
      SyncUpload,
      $$SyncUploadsTableFilterComposer,
      $$SyncUploadsTableOrderingComposer,
      $$SyncUploadsTableAnnotationComposer,
      $$SyncUploadsTableCreateCompanionBuilder,
      $$SyncUploadsTableUpdateCompanionBuilder,
      (
        SyncUpload,
        BaseReferences<_$AppDatabase, $SyncUploadsTable, SyncUpload>,
      ),
      SyncUpload,
      PrefetchHooks Function()
    >;
typedef $$SyncMediaCacheTableCreateCompanionBuilder =
    SyncMediaCacheCompanion Function({
      required String blobId,
      Value<int?> downloadedAt,
      Value<int?> lastOpenedAt,
      Value<bool> uploaded,
      Value<String> reportedState,
      Value<int> rowid,
    });
typedef $$SyncMediaCacheTableUpdateCompanionBuilder =
    SyncMediaCacheCompanion Function({
      Value<String> blobId,
      Value<int?> downloadedAt,
      Value<int?> lastOpenedAt,
      Value<bool> uploaded,
      Value<String> reportedState,
      Value<int> rowid,
    });

class $$SyncMediaCacheTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMediaCacheTable> {
  $$SyncMediaCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportedState => $composableBuilder(
    column: $table.reportedState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMediaCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMediaCacheTable> {
  $$SyncMediaCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get blobId => $composableBuilder(
    column: $table.blobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get uploaded => $composableBuilder(
    column: $table.uploaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportedState => $composableBuilder(
    column: $table.reportedState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMediaCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMediaCacheTable> {
  $$SyncMediaCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get blobId =>
      $composableBuilder(column: $table.blobId, builder: (column) => column);

  GeneratedColumn<int> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get uploaded =>
      $composableBuilder(column: $table.uploaded, builder: (column) => column);

  GeneratedColumn<String> get reportedState => $composableBuilder(
    column: $table.reportedState,
    builder: (column) => column,
  );
}

class $$SyncMediaCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMediaCacheTable,
          SyncMediaCacheData,
          $$SyncMediaCacheTableFilterComposer,
          $$SyncMediaCacheTableOrderingComposer,
          $$SyncMediaCacheTableAnnotationComposer,
          $$SyncMediaCacheTableCreateCompanionBuilder,
          $$SyncMediaCacheTableUpdateCompanionBuilder,
          (
            SyncMediaCacheData,
            BaseReferences<
              _$AppDatabase,
              $SyncMediaCacheTable,
              SyncMediaCacheData
            >,
          ),
          SyncMediaCacheData,
          PrefetchHooks Function()
        > {
  $$SyncMediaCacheTableTableManager(
    _$AppDatabase db,
    $SyncMediaCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMediaCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMediaCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMediaCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> blobId = const Value.absent(),
                Value<int?> downloadedAt = const Value.absent(),
                Value<int?> lastOpenedAt = const Value.absent(),
                Value<bool> uploaded = const Value.absent(),
                Value<String> reportedState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMediaCacheCompanion(
                blobId: blobId,
                downloadedAt: downloadedAt,
                lastOpenedAt: lastOpenedAt,
                uploaded: uploaded,
                reportedState: reportedState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String blobId,
                Value<int?> downloadedAt = const Value.absent(),
                Value<int?> lastOpenedAt = const Value.absent(),
                Value<bool> uploaded = const Value.absent(),
                Value<String> reportedState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMediaCacheCompanion.insert(
                blobId: blobId,
                downloadedAt: downloadedAt,
                lastOpenedAt: lastOpenedAt,
                uploaded: uploaded,
                reportedState: reportedState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMediaCacheTable, SyncMediaCacheData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncMediaCacheTable,
                    SyncMediaCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMediaCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMediaCacheTable,
      SyncMediaCacheData,
      $$SyncMediaCacheTableFilterComposer,
      $$SyncMediaCacheTableOrderingComposer,
      $$SyncMediaCacheTableAnnotationComposer,
      $$SyncMediaCacheTableCreateCompanionBuilder,
      $$SyncMediaCacheTableUpdateCompanionBuilder,
      (
        SyncMediaCacheData,
        BaseReferences<_$AppDatabase, $SyncMediaCacheTable, SyncMediaCacheData>,
      ),
      SyncMediaCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MediaBlobsTableTableManager get mediaBlobs =>
      $$MediaBlobsTableTableManager(_db, _db.mediaBlobs);
  $$DaysTableTableManager get days => $$DaysTableTableManager(_db, _db.days);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$EntryPhotosTableTableManager get entryPhotos =>
      $$EntryPhotosTableTableManager(_db, _db.entryPhotos);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$JournalSettingsTableTableManager get journalSettings =>
      $$JournalSettingsTableTableManager(_db, _db.journalSettings);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncRecordSeqsTableTableManager get syncRecordSeqs =>
      $$SyncRecordSeqsTableTableManager(_db, _db.syncRecordSeqs);
  $$SyncTextBasesTableTableManager get syncTextBases =>
      $$SyncTextBasesTableTableManager(_db, _db.syncTextBases);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$SyncHeldStatesTableTableManager get syncHeldStates =>
      $$SyncHeldStatesTableTableManager(_db, _db.syncHeldStates);
  $$SyncUploadsTableTableManager get syncUploads =>
      $$SyncUploadsTableTableManager(_db, _db.syncUploads);
  $$SyncMediaCacheTableTableManager get syncMediaCache =>
      $$SyncMediaCacheTableTableManager(_db, _db.syncMediaCache);
}
