import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:field_notes/app/app.dart';
import 'package:field_notes/data/database/app_database.dart'
    show AppDatabase, MediaBlobsCompanion;
import 'package:field_notes/data/drafts/filesystem_draft_store.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/design/feedback/confirm_dialog.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/note_tree.dart';
import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/capture/text/editor/photo_toolbar.dart'
    show photoToolbarTargetFor, photoToolbarWidthFor;
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/input/delta_mirror.dart';
import 'package:field_notes/features/note_engine/layout/caret_geometry.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/note_engine.dart';
import 'package:field_notes/features/note_engine/photos/photo_import_flow.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/render/caret_painter.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/note_engine/spell/spell_checker.dart';
import 'package:field_notes/features/notes/notes_providers.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../support/sandbox_path_provider.dart';
import 'probe_server.dart';
import 'probe_storage.dart';

const String _probeFolder = 'probe';
const int _defaultPhotoWidth = 1600;
const int _defaultPhotoHeight = 1200;
const int _decodeBucket = 64;
const int _frameHistory = 50000;
const int _keystrokeHistory = 20000;
const int _logHistory = 20000;
const int _viewportPasses = 12;
const Duration _pressHold = Duration(milliseconds: 80);
const Set<String> _textInputKeystrokeMethods = <String>{
  'TextInputClient.updateEditingState',
  'TextInputClient.updateEditingStateWithDeltas',
  'TextInputClient.updateEditingStateWithTag',
  'TextInputClient.performAction',
  'TextInputClient.performSelectors',
  'TextInputClient.insertContent',
};

final Set<String> _blockKindNames = <String>{
  for (final MdBlockKind kind in MdBlockKind.values) kind.name,
};

const Set<MdInlineKind> _plainInlineKinds = <MdInlineKind>{
  MdInlineKind.text,
  MdInlineKind.softBreak,
  MdInlineKind.hardBreak,
};

final Set<String> _plainRunKinds = <String>{
  for (final MdInlineKind kind in _plainInlineKinds) kind.name,
};

int probeStyledRunCount(Iterable<String> runKinds) => runKinds
    .where(
      (String kind) =>
          !_blockKindNames.contains(kind) && !_plainRunKinds.contains(kind),
    )
    .length;

Iterable<int> probeCaretAuditOffsets({
  required int from,
  required int to,
  required int length,
}) => Iterable<int>.generate(
  (to == length ? to + 1 : to) - from,
  (int index) => from + index,
);

final class _DelayedDraftStore implements DraftStore {
  const _DelayedDraftStore(this._inner, this._delay);

  final DraftStore _inner;
  final Duration Function() _delay;

  @override
  Future<String?> read(String key) async {
    final Duration delay = _delay();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return _inner.read(key);
  }

  @override
  Future<void> write(String key, String source) => _inner.write(key, source);

  @override
  Future<void> delete(String key) => _inner.delete(key);
}

Future<void> main() async {
  final ProbeBinding binding = ProbeBinding.ensureInitialized();
  final Directory support = await getApplicationSupportDirectory();
  final ProbeStorage storage = await ProbeStorage.open(
    Directory(p.join(support.path, _probeFolder)),
  );
  PathProviderPlatform.instance = SandboxPathProvider(storage.root);
  final _Probe probe = _Probe(binding: binding, storage: storage);
  probe.install();
  runApp(_ProbeRoot(probe: probe));
  await ProbeServer(probe.handlers).bind();
}

final class _TimedMessage {
  const _TimedMessage({
    required this.endMicros,
    required this.handlerMicros,
    required this.keyDownMicros,
  });

  final int endMicros;
  final int handlerMicros;
  final int? keyDownMicros;
}

final class _Frame {
  const _Frame({
    required this.buildStart,
    required this.buildFinish,
    required this.rasterFinish,
    required this.buildMicros,
    required this.rasterMicros,
  });

  final int buildStart;
  final int buildFinish;
  final int rasterFinish;
  final int buildMicros;
  final int rasterMicros;
}

final class _ProbeRecorder {
  final List<_TimedMessage> _keystrokes = <_TimedMessage>[];
  final List<_Frame> _frames = <_Frame>[];
  final List<String> _committed = <String>[];
  final List<int> _decodeWidths = <int>[];
  int? _pendingKeyDown;

  List<_TimedMessage> get keystrokes =>
      List<_TimedMessage>.unmodifiable(_keystrokes);

  List<_Frame> get frames => List<_Frame>.unmodifiable(_frames);

  List<String> get committed => List<String>.unmodifiable(_committed);

  List<int> get decodeWidths => List<int>.unmodifiable(_decodeWidths);

  void keyDown(int micros) {
    _pendingKeyDown = micros;
  }

  void message({
    required String channel,
    required ByteData? data,
    required ByteData? reply,
    required int arrival,
    required int end,
  }) {
    final bool keystroke = channel == SystemChannels.textInput.name
        ? _recordTextInput(data)
        : _handledKey(reply);
    if (!keystroke) {
      return;
    }
    _keystrokes.add(
      _TimedMessage(
        endMicros: end,
        handlerMicros: end - arrival,
        keyDownMicros: _pendingKeyDown,
      ),
    );
    _pendingKeyDown = null;
    _trim(_keystrokes, _keystrokeHistory);
  }

  void timings(List<ui.FrameTiming> timings) {
    for (final ui.FrameTiming timing in timings) {
      _frames.add(
        _Frame(
          buildStart: timing.timestampInMicroseconds(ui.FramePhase.buildStart),
          buildFinish: timing.timestampInMicroseconds(
            ui.FramePhase.buildFinish,
          ),
          rasterFinish: timing.timestampInMicroseconds(
            ui.FramePhase.rasterFinish,
          ),
          buildMicros: timing.buildDuration.inMicroseconds,
          rasterMicros: timing.rasterDuration.inMicroseconds,
        ),
      );
    }
    _trim(_frames, _frameHistory);
  }

  void decode(int width) {
    _decodeWidths.add(width);
    _trim(_decodeWidths, _frameHistory);
  }

  void resetTimings() {
    _keystrokes.clear();
    _frames.clear();
  }

  void clearCommitted() {
    _committed.clear();
  }

  bool _recordTextInput(ByteData? data) {
    if (data == null) {
      return false;
    }
    final MethodCall call;
    try {
      call = const JSONMethodCodec().decodeMethodCall(data);
    } on Object {
      return false;
    }
    if (call.method == 'TextInputClient.updateEditingStateWithDeltas') {
      _recordDeltas(call.arguments);
    }
    return _textInputKeystrokeMethods.contains(call.method);
  }

  void _recordDeltas(Object? arguments) {
    if (arguments is! List<Object?> || arguments.length < 2) {
      return;
    }
    final Object? payload = arguments[1];
    if (payload is! Map<Object?, Object?>) {
      return;
    }
    final Object? deltas = payload['deltas'];
    if (deltas is! List<Object?>) {
      return;
    }
    for (final Object? delta in deltas) {
      if (delta is! Map<Object?, Object?>) {
        continue;
      }
      final Object? text = delta['deltaText'];
      final Object? base = delta['composingBase'];
      final Object? extent = delta['composingExtent'];
      final bool composing = base is int && extent is int && base != extent;
      if (text is String && text.isNotEmpty && !composing) {
        _committed.add(text);
      }
    }
    _trim(_committed, _logHistory);
  }

  bool _handledKey(ByteData? reply) {
    if (reply == null) {
      return false;
    }
    try {
      final Object? decoded = const JSONMessageCodec().decodeMessage(reply);
      return decoded is Map<Object?, Object?> && decoded['handled'] == true;
    } on Object {
      return false;
    }
  }

  static void _trim<T>(List<T> list, int limit) {
    if (list.length > limit) {
      list.removeRange(0, list.length - limit);
    }
  }
}

final class _TimedMessenger extends BinaryMessenger {
  const _TimedMessenger(this._inner, this._recorder);

  final BinaryMessenger _inner;
  final _ProbeRecorder _recorder;

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) =>
      // ignore: deprecated_member_use
      _inner.handlePlatformMessage(channel, data, callback);

  @override
  Future<ByteData?>? send(String channel, ByteData? message) =>
      _inner.send(channel, message);

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    final bool timed =
        channel == SystemChannels.textInput.name ||
        channel == SystemChannels.keyEvent.name;
    if (handler == null || !timed) {
      _inner.setMessageHandler(channel, handler);
      return;
    }
    _inner.setMessageHandler(channel, (ByteData? data) async {
      final int arrival = developer.Timeline.now;
      final ByteData? reply = await handler(data);
      final int end = developer.Timeline.now;
      _recorder.message(
        channel: channel,
        data: data,
        reply: reply,
        arrival: arrival,
        end: end,
      );
      return reply;
    });
  }
}

class ProbeBinding extends WidgetsFlutterBinding {
  static ProbeBinding? _probe;

  static ProbeBinding ensureInitialized() => _probe ??= ProbeBinding();

  final _ProbeRecorder _recorder = _ProbeRecorder();

  @override
  BinaryMessenger createBinaryMessenger() =>
      _TimedMessenger(super.createBinaryMessenger(), _recorder);

  @override
  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) {
    ui.TargetImageSize recording(int intrinsicWidth, int intrinsicHeight) {
      final ui.TargetImageSize target = getTargetSize == null
          ? const ui.TargetImageSize()
          : getTargetSize(intrinsicWidth, intrinsicHeight);
      final int? width = target.width;
      final int? height = target.height;
      _recorder.decode(
        width ??
            (height == null || intrinsicHeight == 0
                ? intrinsicWidth
                : (intrinsicWidth * height / intrinsicHeight).round()),
      );
      return target;
    }

    return super.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: recording,
    );
  }
}

final class _SilentReminderScheduler implements ReminderScheduler {
  const _SilentReminderScheduler();

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> schedule(DateTime at) async {}

  @override
  Future<void> cancel() async {}
}

final class _PhotoRequest {
  const _PhotoRequest({
    required this.width,
    required this.height,
    required this.delay,
  });

  final int width;
  final int height;
  final Duration delay;
}

final class _ProbePhotoPicker implements PhotoPicker {
  const _ProbePhotoPicker(this._next);

  final _PhotoRequest Function() _next;

  @override
  bool get supportsCamera => false;

  @override
  Future<List<CaptureMedia>> pickFromLibrary() async {
    final _PhotoRequest request = _next();
    if (request.delay > Duration.zero) {
      await Future<void>.delayed(request.delay);
    }
    final Uint8List bytes = await _generatedPng(
      request.width,
      request.height,
      '${request.width}x${request.height}',
    );
    return <CaptureMedia>[
      CaptureBytes(
        bytes: bytes,
        mime: 'image/png',
        width: request.width,
        height: request.height,
      ),
    ];
  }

  @override
  Future<CaptureMedia?> captureFromCamera() async => null;
}

Future<Uint8List> _generatedPng(int width, int height, String seed) async {
  final int hash = seed.codeUnits.fold<int>(
    17,
    (int value, int unit) => (value * 31 + unit) & 0xFFFFFF,
  );
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect bounds = Offset.zero & Size(width.toDouble(), height.toDouble());
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, <Color>[
        Color(0xFF000000 | hash),
        Color(0xFF000000 | (hash ^ 0x5A7F3C)),
      ]),
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (data == null) {
    throw StateError('could not encode a $width x $height photo');
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

final class _RootConfig {
  const _RootConfig({
    required this.scope,
    required this.overrides,
    required this.width,
    required this.scaler,
  });

  final Key scope;
  final List<Override>? overrides;
  final double? width;
  final double? scaler;

  _RootConfig copyWith({
    Key? scope,
    List<Override>? overrides,
    bool clearOverrides = false,
    double? width,
    bool clearWidth = false,
    double? scaler,
    bool clearScaler = false,
  }) => _RootConfig(
    scope: scope ?? this.scope,
    overrides: clearOverrides ? null : overrides ?? this.overrides,
    width: clearWidth ? null : width ?? this.width,
    scaler: clearScaler ? null : scaler ?? this.scaler,
  );
}

class _ProbeRoot extends StatelessWidget {
  const _ProbeRoot({required this.probe});

  final _Probe probe;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_RootConfig>(
      valueListenable: probe.root,
      builder: (BuildContext context, _RootConfig config, Widget? _) {
        final MediaQueryData ambient = MediaQuery.of(context);
        final double? scaler = config.scaler;
        final double width = config.width ?? ambient.size.width;
        final List<Override>? overrides = config.overrides;
        return RepaintBoundary(
          key: probe.shotKey,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: ambient.size.height,
              child: MediaQuery(
                data: ambient.copyWith(
                  size: Size(width, ambient.size.height),
                  textScaler: scaler == null
                      ? ambient.textScaler
                      : TextScaler.linear(scaler),
                ),
                child: overrides == null
                    ? const SizedBox.shrink()
                    : ProviderScope(
                        key: config.scope,
                        overrides: overrides,
                        child: const FieldNotesApp(),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _Surface {
  const _Surface({
    required this.render,
    required this.layout,
    required this.editor,
  });

  final RenderNoteView render;
  final LaidOutNote layout;
  final NoteEditorViewState? editor;

  String get source => layout.inputs.source;

  NoteEditorController? get controller => editor?.widget.controller;

  Rect? toGlobal(Rect content) {
    final Rect? local = render.contentRectToLocal(content);
    return local == null
        ? null
        : MatrixUtils.transformRect(render.getTransformTo(null), local);
  }

  Offset pointToGlobal(Offset content) => render.contentToGlobal(content);
}

final class _Glyph {
  const _Glyph({required this.box, required this.visible});

  final TextBox box;
  final int visible;
}

final class _Probe {
  _Probe({required this.binding, required ProbeStorage storage})
    : _storage = storage,
      _database = _openDatabase(storage) {
    root = ValueNotifier<_RootConfig>(
      _RootConfig(
        scope: UniqueKey(),
        overrides: _overridesFor(storage, _database),
        width: null,
        scaler: null,
      ),
    );
  }

  final ProbeBinding binding;
  final GlobalKey shotKey = GlobalKey();
  late final ValueNotifier<_RootConfig> root;
  ProbeStorage _storage;
  AppDatabase _database;
  SemanticsHandle? _semantics;
  List<_PhotoRequest> _photoQueue = const <_PhotoRequest>[];
  ProbeErrorLog _errorLog = const ProbeErrorLog();
  List<Map<String, Object?>> _log = const <Map<String, Object?>>[];
  String? _surfaceName;
  String? _openedSource;
  String? _openedEntryId;
  String? _openedDate;
  NoteEditorController? _listening;
  int _transactions = 0;
  Duration _draftReadDelay = Duration.zero;
  int? _openDispatched;
  int? _openMark;
  int _pointer = 7000;

  static AppDatabase _openDatabase(ProbeStorage storage) =>
      AppDatabase(NativeDatabase.createInBackground(File(storage.database)));

  List<Override> _overridesFor(ProbeStorage storage, AppDatabase database) =>
      <Override>[
        databaseProvider.overrideWithValue(database),
        mediaRootProvider.overrideWith((Ref ref) async => storage.media),
        draftRootProvider.overrideWith((Ref ref) async => storage.drafts),
        draftStoreProvider.overrideWith(
          (Ref ref) async => _DelayedDraftStore(
            FilesystemDraftStore(root: storage.drafts),
            () => _draftReadDelay,
          ),
        ),
        notePhotoPickerProvider.overrideWithValue(
          _ProbePhotoPicker(_takePhotoRequest),
        ),
        reminderSchedulerProvider.overrideWithValue(
          const _SilentReminderScheduler(),
        ),
      ];

  _PhotoRequest _takePhotoRequest() {
    final List<_PhotoRequest> queue = _photoQueue;
    if (queue.isEmpty) {
      return const _PhotoRequest(
        width: _defaultPhotoWidth,
        height: _defaultPhotoHeight,
        delay: Duration.zero,
      );
    }
    _photoQueue = List<_PhotoRequest>.unmodifiable(queue.skip(1));
    return queue.first;
  }

  void install() {
    final FlutterExceptionHandler? flutterPrevious = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _recordError(details.exceptionAsString(), details.library, details.stack);
      flutterPrevious?.call(details);
    };
    final ui.ErrorCallback? platformPrevious =
        PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _recordError(error.toString(), null, stack);
      return platformPrevious?.call(error, stack) ?? false;
    };
    SchedulerBinding.instance.addTimingsCallback(binding._recorder.timings);
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event is KeyDownEvent) {
        binding._recorder.keyDown(event.timeStamp.inMicroseconds);
      }
      return false;
    });
    _semantics = SemanticsBinding.instance.ensureSemantics();
  }

  void _recordError(String error, String? library, StackTrace? stack) {
    _errorLog = _errorLog.recordError(<String, Object?>{
      'error': error,
      'library': library,
      'stack': stack?.toString(),
    });
  }

  void _harvestDrops() {
    final Object? previous = _errorLog.owner;
    if (previous is NoteEditorViewState) {
      _errorLog = _errorLog.observe(previous, _dropReasons(previous));
    }
    final NoteEditorViewState? editor = _findSurface()?.editor;
    if (editor != null) {
      _errorLog = _errorLog.observe(editor, _dropReasons(editor));
    }
  }

  static List<String> _dropReasons(NoteEditorViewState editor) => <String>[
    for (final DeltaDrop drop in editor.debugInputDrops) drop.reason.name,
  ];

  Map<String, ProbeHandler> get handlers => <String, ProbeHandler>{
    'state': _state,
    'keys': _keys,
    'find': _find,
    'open': _open,
    'save': _save,
    'close': _close,
    'set': _set,
    'select': _select,
    'focus': _focus,
    'errors': _errorsEndpoint,
    'timings': _timings,
    'clock': _clock,
    'caretAudit': _caretAudit,
    'boxes': _boxes,
    'hit': _hit,
    'offsetAt': _offsetAt,
    'semantics': _semanticsEndpoint,
    'settings': _settings,
    'viewport': _viewport,
    'pid': _pid,
    'shot': _shot,
    'nextPhoto': _nextPhoto,
    'watch': _watch,
    'log': _logEndpoint,
    'flags': _flags,
    probeScenarioEndpoint: _scenario,
  };

  Future<ProbeReply> _pid(ProbeRequest request) async =>
      ProbeReply.json(<String, Object?>{'pid': pid});

  Future<ProbeReply> _clock(ProbeRequest request) async =>
      ProbeReply.json(<String, Object?>{'now': developer.Timeline.now});

  Future<ProbeReply> _scenario(ProbeRequest request) async {
    final String? name = request.query['name'];
    if (name == null || name.isEmpty) {
      throw ArgumentError('scenario needs a name');
    }
    final bool fresh = request.query['fresh'] == '1';
    root.value = root.value.copyWith(clearOverrides: true);
    await _frames(2);
    await _database.close();
    final ProbeStorage storage = await _storage.begin(name, fresh: fresh);
    PathProviderPlatform.instance = SandboxPathProvider(storage.root);
    final AppDatabase database = _openDatabase(storage);
    _storage = storage;
    _database = database;
    _resetSurface();
    _photoQueue = const <_PhotoRequest>[];
    _errorLog = const ProbeErrorLog();
    _draftReadDelay = Duration.zero;
    _log = const <Map<String, Object?>>[];
    binding._recorder.resetTimings();
    binding._recorder.clearCommitted();
    root.value = root.value.copyWith(
      scope: UniqueKey(),
      overrides: _overridesFor(storage, database),
    );
    await _frames(2);
    return ProbeReply.json(<String, Object?>{
      'scenario': storage.scenario,
      'fresh': storage.wiped,
    });
  }

  void _resetSurface() {
    _listening?.removeTransactionListener(_onTransaction);
    _listening = null;
    _surfaceName = null;
    _openedSource = null;
    _openedEntryId = null;
    _openedDate = null;
    _transactions = 0;
    _openDispatched = null;
    _openMark = null;
  }

  Future<ProbeReply> _open(ProbeRequest request) async {
    final String surface = request.query['surface'] ?? 'composer';
    const Set<String> surfaces = <String>{
      'composer',
      'new',
      'viewer',
      'feed-card',
      'day-card',
    };
    if (!surfaces.contains(surface)) {
      throw ArgumentError.value(surface, 'surface', 'unknown surface');
    }
    _harvestDrops();
    final ProviderContainer container = ProviderScope.containerOf(
      _rootNavigator().context,
      listen: false,
    );
    final List<String> mediaIds = await _seedMedia(request.query['media']);
    final String body = request.body;
    final String? reopen = request.query['entry'];
    final Entry? entry = reopen != null && reopen.isNotEmpty
        ? await _existingEntry(container, reopen)
        : surface == 'new'
        ? null
        : await _savedEntry(container, body, mediaIds);
    final String date = entry == null
        ? captureDateKey(DateTime.now())
        : await _dateOf(container, entry);
    _resetSurface();
    _surfaceName = surface;
    _openedSource = surface == 'new' ? '' : entry?.textContent ?? body;
    _openedEntryId = entry?.id;
    _openedDate = date;
    final int entryCount = (await _entriesOn(container, date)).length;
    _dispatch(surface, entry, date);
    bool opened = false;
    for (int frame = 0; frame < 600 && !opened; frame++) {
      await _frames(1);
      final _Surface? found = _findSurface();
      opened =
          found != null &&
          found.render.hasSize &&
          found.layout.fragments.isNotEmpty &&
          (surface != 'composer' && surface != 'new' || found.editor != null);
    }
    if (opened) {
      _openMark = developer.Timeline.now;
      _attach();
    }
    return ProbeReply.json(<String, Object?>{
      'opened': opened,
      'surface': surface,
      'entryId': entry?.id,
      'entryCount': entryCount,
    });
  }

  static Future<Entry> _savedEntry(
    ProviderContainer container,
    String body,
    List<String> mediaIds,
  ) async {
    final NoteWriter writer = await container.read(noteWriterProvider.future);
    final NoteSaveResult result = await writer.save(
      date: captureDateKey(DateTime.now()),
      source: body,
      photoMediaIds: mediaIds,
    );
    return result.entry;
  }

  static Future<Entry> _existingEntry(
    ProviderContainer container,
    String id,
  ) async {
    final Entry? entry = await container
        .read(journalRepositoryProvider)
        .entryById(id);
    if (entry == null) {
      throw ArgumentError.value(id, 'entry', 'no entry with this id');
    }
    return entry;
  }

  static Future<String> _dateOf(
    ProviderContainer container,
    Entry entry,
  ) async {
    final Day? day = await container
        .read(journalRepositoryProvider)
        .dayById(entry.dayId);
    return day?.date ?? captureDateKey(DateTime.now());
  }

  static Future<List<Entry>> _entriesOn(
    ProviderContainer container,
    String date,
  ) =>
      container.read(journalRepositoryProvider).watchEntriesForDate(date).first;

  void _dispatch(String surface, Entry? entry, String today) {
    final NavigatorState navigator = _rootNavigator();
    navigator.popUntil((Route<Object?> route) => route.isFirst);
    final BuildContext context =
        navigator.overlay?.context ?? navigator.context;
    _openDispatched = developer.Timeline.now;
    switch (surface) {
      case 'composer':
        unawaited(showEditNote(context, entry: entry!, date: today));
      case 'new':
        unawaited(showTextComposer(context, today));
      case 'viewer':
        unawaited(
          showLogViewer(
            context,
            date: today,
            entryId: entry!.id,
            exit: LogViewerExit.close,
          ),
        );
      case 'day-card':
        unawaited(showDayDetail(context, date: today, focusEntryId: entry!.id));
      case 'feed-card':
        break;
    }
  }

  Future<List<String>> _seedMedia(String? media) async {
    if (media == null || media.trim().isEmpty) {
      return const <String>[];
    }
    final List<String> ids = <String>[];
    for (final String item in media.split(',')) {
      final List<String> parts = item.trim().split(':');
      if (parts.length != 3) {
        throw ArgumentError.value(item, 'media', 'expected ref:w:h');
      }
      final String reference = parts[0].toLowerCase();
      final int width = int.parse(parts[1]);
      final int height = int.parse(parts[2]);
      final String id = '$reference${'0' * 52}';
      await _seedBlob(id, width, height);
      ids.add(id);
    }
    return List<String>.unmodifiable(ids);
  }

  Future<void> _seedBlob(String id, int width, int height) async {
    final String relPath = relPathForBlob(
      id: id,
      mime: 'image/png',
      kind: MediaKind.photo,
    );
    final File file = File(p.join(_storage.media.path, relPath));
    final Uint8List bytes = await _generatedPng(width, height, id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    await _database
        .into(_database.mediaBlobs)
        .insertOnConflictUpdate(
          MediaBlobsCompanion.insert(
            id: id,
            relPath: relPath,
            mime: 'image/png',
            kind: MediaKind.photo.id,
            bytes: bytes.length,
            width: Value<int?>(width),
            height: Value<int?>(height),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<ProbeReply> _save(ProbeRequest request) async {
    _harvestDrops();
    final String date = _openedDate ?? captureDateKey(DateTime.now());
    final String? entryId = _openedEntryId;
    final ProviderContainer container = ProviderScope.containerOf(
      _rootNavigator().context,
      listen: false,
    );
    final Element? edit = _textElement(editNoteSaveLabel);
    final Element? target = edit ?? _textElement('Save');
    if (target == null) {
      throw StateError('no Save control on screen');
    }
    await _pressElement(target);
    if (edit != null) {
      Element? confirm;
      for (int frame = 0; frame < 60 && confirm == null; frame++) {
        await _frames(1);
        confirm = _keyedElement(confirmDialogConfirmKey);
      }
      if (confirm != null) {
        await _pressElement(confirm);
      }
    }
    bool saved = false;
    for (int frame = 0; frame < 240 && !saved; frame++) {
      await _frames(1);
      saved = _keyedElement(noteEditorKey) == null;
    }
    final List<Entry> entries = await _entriesOn(container, date);
    final String? stored = await _storedText(container, entries, entryId);
    if (saved) {
      _resetSurface();
    }
    return ProbeReply.json(<String, Object?>{
      'saved': saved,
      'stored': stored,
      'entryCount': entries.length,
    });
  }

  static Future<String?> _storedText(
    ProviderContainer container,
    List<Entry> entries,
    String? entryId,
  ) async {
    if (entryId != null) {
      return (await container
              .read(journalRepositoryProvider)
              .entryById(entryId))
          ?.textContent;
    }
    if (entries.isEmpty) {
      return null;
    }
    return entries
        .reduce((Entry a, Entry b) => b.updatedAt > a.updatedAt ? b : a)
        .textContent;
  }

  Future<ProbeReply> _close(ProbeRequest request) async {
    _harvestDrops();
    final Element? close = _keyedElement(composerCloseKey);
    if (close != null) {
      await _pressElement(close);
    } else {
      final NavigatorState navigator = _rootNavigator();
      await navigator.maybePop();
    }
    bool prompt = false;
    bool closed = false;
    for (int frame = 0; frame < 30 && !prompt && !closed; frame++) {
      await _frames(1);
      prompt = _keyedElement(composerDiscardKey) != null;
      closed = _keyedElement(noteEditorKey) == null && close != null;
    }
    final Element? discard = prompt && request.query['discard'] == '1'
        ? _keyedElement(composerDiscardKey)
        : null;
    if (discard != null) {
      await _pressElement(discard);
    }
    bool discarded = false;
    for (int frame = 0; frame < 60 && discard != null && !discarded; frame++) {
      await _frames(1);
      discarded = _keyedElement(noteEditorKey) == null;
    }
    closed =
        discarded ||
        !prompt && (close == null || _keyedElement(noteEditorKey) == null);
    if (closed) {
      _resetSurface();
    }
    return ProbeReply.json(<String, Object?>{
      'closed': closed,
      'discardPrompt': prompt,
      'discarded': discarded,
    });
  }

  Future<ProbeReply> _set(ProbeRequest request) async {
    final NoteEditorController controller = _requireController();
    final String body = request.body;
    final int? base = _int(request.query['base']);
    if (base == null) {
      controller.text = body;
    } else {
      controller.value = TextEditingValue(
        text: body,
        selection: TextSelection(
          baseOffset: base,
          extentOffset: _int(request.query['extent']) ?? base,
        ),
      );
    }
    await _frames(1);
    return ProbeReply.json(<String, Object?>{
      'length': controller.state.source.length,
    });
  }

  Future<ProbeReply> _select(ProbeRequest request) async {
    final NoteEditorController controller = _requireController();
    final int base = _int(request.query['base']) ?? 0;
    final int extent = _int(request.query['extent']) ?? base;
    final TextAffinity affinity = request.query['affinity'] == 'upstream'
        ? TextAffinity.upstream
        : TextAffinity.downstream;
    controller.selection = TextSelection(
      baseOffset: base,
      extentOffset: extent,
      affinity: affinity,
    );
    await _frames(1);
    return ProbeReply.json(<String, Object?>{
      'selection': _selectionJson(controller.state.selection),
    });
  }

  Future<ProbeReply> _focus(ProbeRequest request) async {
    final NoteEditorViewState editor = _requireEditor();
    editor.widget.focusNode.requestFocus();
    await _frames(2);
    return ProbeReply.json(<String, Object?>{
      'focused': editor.widget.focusNode.hasFocus,
    });
  }

  Future<ProbeReply> _state(ProbeRequest request) async {
    final _Surface? surface = _findSurface();
    _attach();
    _harvestDrops();
    final ProviderContainer? container = request.query['entries'] == '1'
        ? ProviderScope.containerOf(_rootNavigator().context, listen: false)
        : null;
    final ui.FlutterView view = _view();
    final double dpr = view.devicePixelRatio;
    final Map<String, Object?> result = <String, Object?>{
      'surface': surface == null ? null : _surfaceName,
      'view': <String, Object?>{
        'width': view.physicalSize.width / dpr,
        'height': view.physicalSize.height / dpr,
        'devicePixelRatio': dpr,
      },
      'imageCacheBytes': PaintingBinding.instance.imageCache.currentSizeBytes,
      'oversizeDecodes': _oversizeDecodes(surface, dpr),
      'transactions': _transactions,
      'keyed': _keyedRects(''),
      'textFieldFocused': _textFieldFocused(),
    };
    if (surface == null) {
      return ProbeReply.json(<String, Object?>{
        ...result,
        if (request.query['text'] != '0') 'source': null,
        'length': 0,
        'selection': null,
        'composing': <int>[-1, -1],
        'focused': false,
        'activeLine': null,
        'caret': null,
        'photoSelected': null,
        'canUndo': false,
        'canRedo': false,
        'column': null,
        'columnLeft': null,
        'em': null,
        'scroll': null,
        'writingSurface': null,
        'photoToolbarNarrowWidth': null,
        'blocks': const <Object?>[],
        'lines': const <Object?>[],
        'photos': const <Object?>[],
        'placeholders': const <Object?>[],
        'dropBoundary': null,
        'misspelled': const <Object?>[],
      });
    }
    final RenderNoteView render = surface.render;
    final LaidOutNote layout = surface.layout;
    final NoteEditorController? controller = surface.controller;
    final NoteEditorViewState? editor = surface.editor;
    final NoteSelection? selection =
        controller?.state.selection ?? render.selection;
    final MdRange? composing = controller?.state.composing;
    final Rect? caretLocal = render.caretRect;
    final List<PhotoRect> photos = layout.photoRects;
    final TextRange? selectedPhoto = render.selectedPhotoRange;
    final int selectedOrdinal = selectedPhoto == null
        ? -1
        : photos.indexWhere(
            (PhotoRect photo) => photo.sourceRange.start == selectedPhoto.start,
          );
    final String? goal = request.query['goalX'];
    return ProbeReply.json(<String, Object?>{
      ...result,
      if (request.query['text'] != '0') 'source': surface.source,
      'length': surface.source.length,
      'selection': selection == null ? null : _selectionJson(selection),
      'composing': composing == null
          ? <int>[-1, -1]
          : <int>[composing.start, composing.end],
      'focused': editor?.widget.focusNode.hasFocus ?? render.focused,
      'activeLine': render.activeLine,
      'caret': caretLocal == null
          ? null
          : _rectJson(
              MatrixUtils.transformRect(
                render.getTransformTo(null),
                caretLocal,
              ),
            ),
      'photoSelected': selectedOrdinal < 0 ? null : selectedOrdinal,
      'canUndo': controller?.canUndo ?? false,
      'canRedo': controller?.canRedo ?? false,
      'column': layout.inputs.columnWidth,
      'columnLeft': surface.pointToGlobal(Offset.zero).dx,
      'em': NoteTypography.emOf(layout.inputs.textScaler),
      'scroll': _scrollJson(render),
      'writingSurface': _nullableRect(_writingSurface(editor)),
      'photoToolbarNarrowWidth': photoToolbarWidthFor(
        scaler: layout.inputs.textScaler,
        placement: false,
        moves: true,
        target: photoToolbarTargetFor(defaultTargetPlatform),
      ),
      'blocks': _blocksJson(surface),
      'lines': _linesJson(layout),
      'photos': <Object?>[
        for (int i = 0; i < photos.length; i++)
          <String, Object?>{
            'reference': photos[i].reference,
            'ordinal': i,
            'rect': _nullableRect(surface.toGlobal(photos[i].rect)),
            'ringDegrees': i == selectedOrdinal ? _ringDegrees() : null,
            'tiltDegrees': photoFigureTiltDegrees(photos[i].reference),
          },
      ],
      'placeholders': editor == null || editor.debugImportPlaceholders.isEmpty
          ? const <Object?>[]
          : <Object?>[
              for (final Element element in _elementsWhere(
                (Element element) =>
                    element.widget is PhotoImportPlaceholderBox,
              ))
                ?_nullableRect(_elementRect(element)),
            ],
      'dropBoundary': editor?.debugDropBoundary,
      'misspelled': <Object?>[
        for (final SpellUnderlineDecoration decoration
            in render.decorations.whereType<SpellUnderlineDecoration>())
          for (final SpellMark mark in decoration.marks)
            <int>[mark.range.start, mark.range.end],
      ],
      if (goal != null && selection != null)
        'verticalGoal': _verticalGoal(surface, selection, double.parse(goal)),
      if (request.query['reference'] == '1')
        'referenceLines': _linesJson(_referenceLayout(layout)),
      if (container != null)
        'entryCount': (await _entriesOn(
          container,
          _openedDate ?? captureDateKey(DateTime.now()),
        )).length,
    });
  }

  static Map<String, Object?> _scrollJson(RenderNoteView render) {
    final ViewportOffset? offset = render.offset;
    return <String, Object?>{
      'offset': render.scrollOffset,
      'max': offset is ScrollPosition && offset.hasContentDimensions
          ? offset.maxScrollExtent
          : 0.0,
    };
  }

  static Rect? _writingSurface(NoteEditorViewState? editor) {
    final Element? layer = _keyedElement(notePhotoToolbarLayerKey);
    final Rect? rect = layer == null ? null : _elementRect(layer);
    if (editor == null || rect == null) {
      return null;
    }
    return Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      math.max(0, rect.height - editor.widget.bottomInset),
    );
  }

  static bool _textFieldFocused() {
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        context.findAncestorStateOfType<EditableTextState>() != null;
  }

  int _oversizeDecodes(_Surface? surface, double dpr) {
    if (surface == null || surface.layout.photoRects.isEmpty) {
      return 0;
    }
    final double drawn = surface.layout.photoRects.fold<double>(
      0,
      (double widest, PhotoRect photo) =>
          math.max(widest, photo.imageRect.width),
    );
    final int bucket = ((drawn * dpr) / _decodeBucket).ceil() * _decodeBucket;
    return binding._recorder.decodeWidths
        .where((int width) => width > bucket)
        .length;
  }

  static List<Object?> _blocksJson(_Surface surface) {
    final LaidOutNote layout = surface.layout;
    final MdTree tree = parseNoteTree(
      layout.inputs.source,
      tables: tablesEnabled,
    );
    final List<LaidOutRow> rows = layout.flow.rows;
    final List<FragmentInfo> fragments = layout.fragments;
    return <Object?>[
      for (final MdBlock block in tree.blocks)
        if (block.kind != MdBlockKind.blankLine)
          _blockJson(surface, block, rows, fragments),
    ];
  }

  static Map<String, Object?> _blockJson(
    _Surface surface,
    MdBlock block,
    List<LaidOutRow> rows,
    List<FragmentInfo> fragments,
  ) {
    final LaidOutNote layout = surface.layout;
    final MdRange range = block.sourceRange;
    final List<String> runKinds = <String>[
      for (final LaidOutRow row in rows)
        if (_startsInside(row.row.sourceRange.start, range))
          for (final ({TextRange visibleRange, String styleKind}) run
              in row.styleRuns)
            run.styleKind,
    ];
    final List<Rect> boxes = <Rect>[
      for (final FragmentInfo fragment in fragments)
        if (_startsInside(fragment.sourceRange.start, range))
          fragment.lineBox.rect,
      for (final PhotoRect photo in layout.photoRects)
        if (_startsInside(photo.sourceRange.start, range)) photo.rect,
    ];
    final double? top = boxes.isEmpty
        ? null
        : boxes.map((Rect box) => box.top).reduce(math.min);
    final double? bottom = boxes.isEmpty
        ? null
        : boxes.map((Rect box) => box.bottom).reduce(math.max);
    final MdBlockData? data = block.data;
    return <String, Object?>{
      'kind': block.kind.name,
      'start': range.start,
      'end': range.end,
      'unclosedFence':
          block.kind == MdBlockKind.fencedCode &&
          data is MdFenceData &&
          !data.isClosed,
      'styleKind': runKinds
          .where((String kind) => _blockKindNames.contains(kind))
          .firstOrNull,
      'inlineNodes': _styledInlineCount(block),
      'styledRuns': probeStyledRunCount(runKinds),
      'top': top,
      'globalTop': top == null
          ? null
          : surface.pointToGlobal(Offset(0, top)).dy,
      'globalBottom': bottom == null
          ? null
          : surface.pointToGlobal(Offset(0, bottom)).dy,
    };
  }

  static bool _startsInside(int offset, MdRange range) =>
      offset >= range.start &&
      (offset < range.end || (range.isEmpty && offset == range.start));

  static int _styledInlineCount(MdBlock block) {
    int count = 0;
    void visit(MdInline inline) {
      if (!_plainInlineKinds.contains(inline.kind)) {
        count += 1;
      }
      for (final MdInline child in inline.children) {
        visit(child);
      }
    }

    for (final MdInline inline in block.inlines) {
      visit(inline);
    }
    for (final MdBlock child in block.blocks) {
      count += _styledInlineCount(child);
    }
    return count;
  }

  static List<Object?> _linesJson(NoteLayout layout) {
    final String text = layout.inputs.visibleText.text;
    return <Object?>[
      for (final FragmentInfo fragment in layout.fragments)
        <String, Object?>{
          'text': text.substring(
            fragment.visibleRange.start.clamp(0, text.length),
            fragment.visibleRange.end.clamp(0, text.length),
          ),
          'top': fragment.lineBox.rect.top,
        },
    ];
  }

  static LaidOutNote _referenceLayout(LaidOutNote layout) {
    final LayoutInputs inputs = layout.inputs;
    final MdTree tree = parseNoteTree(inputs.source, tables: tablesEnabled);
    return NoteLayoutEngine().layout(
      LayoutInputs(
        source: inputs.source,
        tree: tree,
        visibleText: const NoteVisibleProjector().project(
          inputs.source,
          tree,
          null,
        ),
        activeLine: null,
        columnWidth: inputs.columnWidth,
        textScaler: inputs.textScaler,
        boldText: inputs.boldText,
        locale: inputs.locale,
        readerMode: true,
        mediaDimensions: inputs.mediaDimensions,
        unavailableMedia: inputs.unavailableMedia,
      ),
    );
  }

  double? _ringDegrees() {
    final Element? ring = _keyedElement(photoFigureRingKey);
    final RenderObject? object = ring?.renderObject;
    if (object is! RenderBox || !object.attached) {
      return null;
    }
    final Float64List m = object.getTransformTo(null).storage;
    return math.atan2(m[1], m[0]) * 180 / math.pi;
  }

  Map<String, Object?> _verticalGoal(
    _Surface surface,
    NoteSelection selection,
    double goalX,
  ) {
    final LaidOutNote layout = surface.layout;
    final ({LineFragment fragment, VisualLine line}) located = layout.geometry
        .locate(selection.head, selection.affinity);
    final VisualLine line = located.line;
    final double lineEndX = surface
        .pointToGlobal(Offset(line.left + line.width, line.top))
        .dx;
    final List<_Glyph> glyphs = _glyphsOf(layout, located.fragment, line);
    double advance = 0;
    for (final _Glyph glyph in glyphs) {
      final double left = surface
          .pointToGlobal(Offset(glyph.box.left, glyph.box.top))
          .dx;
      final double right = surface
          .pointToGlobal(Offset(glyph.box.right, glyph.box.top))
          .dx;
      final double width = (right - left).abs();
      if (goalX >= math.min(left, right) && goalX <= math.max(left, right)) {
        advance = width;
        break;
      }
      advance = math.max(advance, width);
    }
    return <String, Object?>{
      'glyphAdvance': advance,
      'lineShorterThanGoal': lineEndX < goalX,
      'lineEndX': lineEndX,
    };
  }

  static List<_Glyph> _glyphsOf(
    LaidOutNote layout,
    LineFragment fragment,
    VisualLine line,
  ) {
    final ui.Paragraph? paragraph = fragment.paragraph;
    if (paragraph == null) {
      return const <_Glyph>[];
    }
    final int base = fragment.visibleRange.start;
    final int end = line.visibleRange.end - base;
    final List<_Glyph> glyphs = <_Glyph>[];
    int local = line.visibleRange.start - base;
    while (local < end) {
      final TextBox? box = layout.geometry.glyphBoxAt(fragment, local);
      final TextRange cluster = CaretGeometry.graphemeAt(paragraph, local);
      if (box != null) {
        glyphs.add(_Glyph(box: box, visible: base + local));
      }
      local = math.max(local + 1, cluster.end);
    }
    return glyphs;
  }

  Future<ProbeReply> _keys(ProbeRequest request) async =>
      ProbeReply.json(_keyedRects(request.query['prefix'] ?? ''));

  Future<ProbeReply> _find(ProbeRequest request) async {
    final String? key = request.query['key'];
    if (key != null) {
      return ProbeReply.json(<String, Object?>{
        'rects': <Object?>[
          for (final Element element in _elementsWhere(
            (Element element) => _keyValue(element) == key,
          ))
            ?_nullableRect(_elementRect(element)),
        ],
        'offsets': const <Object?>[],
      });
    }
    final String? text = request.query['text'];
    if (text == null || text.isEmpty) {
      throw ArgumentError('find needs a key or a text');
    }
    final String? source = _findSurface()?.source;
    final List<Object?> offsets = <Object?>[];
    if (source != null) {
      int from = source.indexOf(text);
      while (from >= 0) {
        offsets.add(<int>[from, from + text.length]);
        from = source.indexOf(text, from + 1);
      }
    }
    final ui.FlutterView view = _view();
    final Rect screen =
        Offset.zero & (view.physicalSize / view.devicePixelRatio);
    return ProbeReply.json(<String, Object?>{
      'offsets': offsets,
      'rects': <Object?>[
        for (final Element element in _elementsWhere((Element element) {
          final Widget widget = element.widget;
          return widget is RichText && widget.text.toPlainText().contains(text);
        }))
          if (_elementRect(element) case final Rect rect
              when rect.overlaps(screen))
            _rectJson(rect),
      ],
    });
  }

  Future<ProbeReply> _errorsEndpoint(ProbeRequest request) async {
    _harvestDrops();
    final bool scenario = request.query['scope'] == 'scenario';
    final Map<String, Object?> reply = _errorLog.json(scenario: scenario);
    if (request.query['reset'] == '1') {
      _errorLog = _errorLog.resetScenario();
    } else if (request.query['clear'] == '1') {
      _errorLog = _errorLog.clearWindow();
    }
    return ProbeReply.json(reply);
  }

  Future<ProbeReply> _timings(ProbeRequest request) async {
    final _ProbeRecorder recorder = binding._recorder;
    final int? lastKeystroke = recorder.keystrokes.lastOrNull?.endMicros;
    for (
      int wait = 0;
      wait < 30 &&
          lastKeystroke != null &&
          !recorder.frames.any((_Frame f) => f.buildStart >= lastKeystroke);
      wait++
    ) {
      SchedulerBinding.instance.scheduleFrame();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final List<_Frame> frames = recorder.frames;
    final int? dispatched = _openDispatched;
    final int? mark = _openMark;
    final _Frame? openFrame = mark == null
        ? null
        : frames.where((_Frame frame) => frame.buildStart <= mark).lastOrNull;
    final ui.Display? display =
        PlatformDispatcher.instance.displays.firstOrNull;
    final Map<String, Object?> reply = <String, Object?>{
      'refreshHz': display?.refreshRate ?? 60,
      'nowMicros': developer.Timeline.now,
      'keystrokes': <Object?>[
        for (final _TimedMessage keystroke in recorder.keystrokes)
          _keystrokeJson(
            keystroke,
            frames
                .where(
                  (_Frame frame) => frame.buildStart >= keystroke.endMicros,
                )
                .firstOrNull,
          ),
      ],
      'frames': <Object?>[
        for (final _Frame frame in frames)
          <String, Object?>{
            'buildMs': frame.buildMicros / 1000,
            'rasterMs': frame.rasterMicros / 1000,
            'buildStartMicros': frame.buildStart,
            'rasterFinishMicros': frame.rasterFinish,
          },
      ],
      'open': dispatched == null
          ? null
          : <String, Object?>{
              'dispatchedMicros': dispatched,
              'firstLineRasterFinishMicros': openFrame?.rasterFinish,
            },
    };
    if (request.query['reset'] == '1') {
      recorder.resetTimings();
      _openDispatched = null;
      _openMark = null;
    }
    return ProbeReply.json(reply);
  }

  static Map<String, Object?> _keystrokeJson(
    _TimedMessage keystroke,
    _Frame? frame,
  ) => probeKeystrokeJson(
    handlerMicros: keystroke.handlerMicros,
    buildMicros: frame?.buildMicros,
    rasterFinishMicros: frame?.rasterFinish,
    keyDownMicros: keystroke.keyDownMicros,
  );

  Future<ProbeReply> _caretAudit(ProbeRequest request) async {
    final _Surface surface = _requireSurface();
    final LaidOutNote layout = surface.layout;
    final String source = surface.source;
    final int from = (_int(request.query['from']) ?? 0).clamp(0, source.length);
    final int to = (_int(request.query['to']) ?? source.length).clamp(
      from,
      source.length,
    );
    final MdTree tree = layout.inputs.tree;
    final double dpr = _view().devicePixelRatio;
    final List<Object?> samples = <Object?>[];
    for (final int offset in probeCaretAuditOffsets(
      from: from,
      to: to,
      length: source.length,
    )) {
      final Rect downstream = layout.caretRect(offset, TextAffinity.downstream);
      final Rect upstream = layout.caretRect(offset, TextAffinity.upstream);
      final List<TextAffinity> affinities = upstream == downstream
          ? const <TextAffinity>[TextAffinity.downstream]
          : const <TextAffinity>[
              TextAffinity.upstream,
              TextAffinity.downstream,
            ];
      final String? blockKind = tree.blockAt(offset)?.kind.name;
      for (final TextAffinity affinity in affinities) {
        final Rect lineBox = layout.lineBoxAt(offset, affinity).rect;
        final Rect caret = noteCaretRect(
          caret: layout.caretRect(offset, affinity),
          lineBox: lineBox,
          devicePixelRatio: dpr,
        );
        samples.add(<String, Object?>{
          'offset': offset,
          'affinity': affinity.name,
          'blockKind': blockKind,
          'dx': caret.left - _glyphEdge(layout, offset, affinity, caret.left),
          'dTop': caret.top - lineBox.top,
          'dBottom': caret.bottom - lineBox.bottom,
        });
      }
    }
    return ProbeReply.json(<String, Object?>{'samples': samples});
  }

  static double _glyphEdge(
    LaidOutNote layout,
    int offset,
    TextAffinity affinity,
    double fallback,
  ) {
    final ({LineFragment fragment, VisualLine line}) located = layout.geometry
        .locate(offset, affinity);
    final LineFragment fragment = located.fragment;
    final VisualLine line = located.line;
    final ui.Paragraph? paragraph = fragment.paragraph;
    if (paragraph == null) {
      return fallback;
    }
    if (line.visibleRange.isCollapsed) {
      return line.left;
    }
    final int visible = layout.inputs.visibleText.map.sourceToVisible(offset);
    final int local = visible - fragment.visibleRange.start;
    final int lineStart = line.visibleRange.start - fragment.visibleRange.start;
    final int lineEnd = line.visibleRange.end - fragment.visibleRange.start;
    final bool before = local >= lineEnd
        ? true
        : local <= lineStart
        ? false
        : affinity == TextAffinity.upstream;
    final TextBox? box = before
        ? layout.geometry.glyphBoxAt(
            fragment,
            CaretGeometry.graphemeAt(paragraph, local - 1).start,
          )
        : layout.geometry.glyphBoxAt(fragment, local);
    if (box == null) {
      return fallback;
    }
    final bool ltr = box.direction == TextDirection.ltr;
    return before == ltr ? box.right : box.left;
  }

  Future<ProbeReply> _boxes(ProbeRequest request) async {
    final _Surface surface = _requireSurface();
    final LaidOutNote layout = surface.layout;
    final String source = surface.source;
    final int from = (_int(request.query['from']) ?? 0).clamp(0, source.length);
    final int to = (_int(request.query['to']) ?? from).clamp(0, source.length);
    final NoteSelection selection = NoteSelection(anchor: from, head: to);
    final int visibleFrom = layout.inputs.visibleText.map.sourceToVisible(
      math.min(from, to),
    );
    final int visibleTo = layout.inputs.visibleText.map.sourceToVisible(
      math.max(from, to),
    );
    final List<Object?> glyphs = <Object?>[];
    for (final LaidOutRow row in layout.flow.rows) {
      for (final LineFragment fragment in row.fragments) {
        for (final VisualLine line in fragment.lines) {
          final TextRange range = line.visibleRange;
          final bool touched =
              range.start <= visibleTo && range.end >= visibleFrom;
          if (!touched) {
            continue;
          }
          for (final _Glyph glyph in _glyphsOf(layout, fragment, line)) {
            final Rect? rect = surface.toGlobal(glyph.box.toRect());
            if (rect == null) {
              continue;
            }
            glyphs.add(<String, Object?>{
              'rect': _rectJson(rect),
              'selected':
                  glyph.visible >= visibleFrom && glyph.visible < visibleTo,
            });
          }
        }
      }
    }
    final double em = NoteTypography.emOf(layout.inputs.textScaler);
    final int firstSelected = glyphs.indexWhere(
      (Object? glyph) =>
          glyph is Map<String, Object?> && glyph['selected'] == true,
    );
    return ProbeReply.json(<String, Object?>{
      'selection': <Object?>[
        for (final Rect box in layout.selectionBoxes(selection))
          ?_nullableRect(surface.toGlobal(box)),
      ],
      'glyphs': glyphs,
      'firstSelected': firstSelected < 0 ? null : firstSelected,
      'photos': <Object?>[
        for (final PhotoRect photo in layout.photoRects)
          ?_nullableRect(surface.toGlobal(photo.rect)),
      ],
      'gutters': <Object?>[
        for (final PhotoRect photo in layout.photoRects)
          if (photo.flow != PhotoFlow.block)
            ?_nullableRect(
              surface.toGlobal(
                photo.flow == PhotoFlow.floatLeft
                    ? Rect.fromLTWH(
                        photo.rect.right,
                        photo.rect.top,
                        em,
                        photo.rect.height,
                      )
                    : Rect.fromLTWH(
                        photo.rect.left - em,
                        photo.rect.top,
                        em,
                        photo.rect.height,
                      ),
              ),
            ),
      ],
    });
  }

  Future<ProbeReply> _hit(ProbeRequest request) async {
    final Offset point = _point(request);
    final HitTestResult result = HitTestResult();
    RendererBinding.instance.hitTestInView(result, point, _view().viewId);
    final Map<RenderObject, Element> owners = <RenderObject, Element>{};
    _visit((Element element) {
      if (element is RenderObjectElement) {
        owners[element.renderObject] = element;
      }
    });
    return ProbeReply.json(<String, Object?>{
      'path': <Object?>[
        for (final HitTestEntry<HitTestTarget> entry in result.path)
          _hitLabel(entry.target, owners),
      ],
    });
  }

  static String _hitLabel(
    HitTestTarget target,
    Map<RenderObject, Element> owners,
  ) {
    if (target is! RenderObject) {
      return '${target.runtimeType}';
    }
    final Element? owner = owners[target];
    if (owner == null) {
      return '${target.runtimeType}';
    }
    final List<String> names = <String>[_widgetLabel(owner.widget)];
    owner.visitAncestorElements((Element ancestor) {
      if (ancestor is RenderObjectElement) {
        return false;
      }
      if (ancestor.widget.key != null) {
        names.add(_widgetLabel(ancestor.widget));
      }
      return true;
    });
    return names.join(' < ');
  }

  static String _widgetLabel(Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String>
        ? '${widget.runtimeType} ${key.value}'
        : '${widget.runtimeType}';
  }

  Future<ProbeReply> _offsetAt(ProbeRequest request) async {
    final _Surface surface = _requireSurface();
    final TextPosition position = surface.layout.positionAt(
      surface.render.globalToContent(_point(request)),
    );
    return ProbeReply.json(<String, Object?>{
      'offset': position.offset,
      'affinity': position.affinity.name,
    });
  }

  Future<ProbeReply> _semanticsEndpoint(ProbeRequest request) async {
    _semantics ??= SemanticsBinding.instance.ensureSemantics();
    await _frames(2);
    SemanticsNode? rootNode;
    for (final RenderView view in RendererBinding.instance.renderViews) {
      rootNode ??= view.owner?.semanticsOwner?.rootSemanticsNode;
    }
    if (rootNode == null) {
      return ProbeReply.json(<String, Object?>{'root': null});
    }
    final ui.FlutterView view = _view();
    final double logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    final Rect rootRect = MatrixUtils.transformRect(
      rootNode.transform ?? Matrix4.identity(),
      rootNode.rect,
    );
    final double scale = rootRect.width > 0 ? logicalWidth / rootRect.width : 1;
    return ProbeReply.json(<String, Object?>{
      'root': _semanticsJson(rootNode, Matrix4.identity(), scale),
    });
  }

  static Map<String, Object?> _semanticsJson(
    SemanticsNode node,
    Matrix4 parent,
    double scale,
  ) {
    final Matrix4? own = node.transform;
    final Matrix4 transform = own == null ? parent : parent.multiplied(own);
    final SemanticsData data = node.getSemanticsData();
    final Rect rect = MatrixUtils.transformRect(transform, node.rect);
    final TextSelection? selection = data.textSelection;
    final List<Map<String, Object?>> children = <Map<String, Object?>>[];
    node.visitChildren((SemanticsNode child) {
      children.add(_semanticsJson(child, transform, scale));
      return true;
    });
    return <String, Object?>{
      'label': data.label,
      'value': data.value,
      'hint': data.hint,
      'flags': data.flagsCollection.toStrings(),
      'actions': <String>[
        for (final SemanticsAction action in SemanticsAction.values)
          if (data.hasAction(action)) action.name,
      ],
      'rect': <double>[
        rect.left * scale,
        rect.top * scale,
        rect.width * scale,
        rect.height * scale,
      ],
      'textSelection': selection == null
          ? null
          : <int>[selection.baseOffset, selection.extentOffset],
      'children': children,
    };
  }

  Future<ProbeReply> _settings(ProbeRequest request) async {
    final ProviderContainer container = ProviderScope.containerOf(
      _rootNavigator().context,
      listen: false,
    );
    final SettingsRepository repository = container.read(
      settingsRepositoryProvider,
    );
    final String? size = request.query['textSize'];
    if (size != null) {
      await repository.setTextSize(TextSize.values.byName(size));
    }
    final String? spell = request.query['spellCheck'];
    if (spell != null) {
      await repository.setSpellCheckEnabled(spell == '1');
    }
    await _frames(3);
    final AppSettings settings = await repository.load();
    return ProbeReply.json(<String, Object?>{
      'textSize': settings.textSize.name,
      'spellCheck': settings.spellCheckEnabled,
    });
  }

  Future<ProbeReply> _viewport(ProbeRequest request) async {
    if (request.query['clear'] == '1') {
      root.value = root.value.copyWith(clearWidth: true);
      await _frames(2);
      return ProbeReply.json(<String, Object?>{'column': _column()});
    }
    final String? requested = request.query['column'];
    if (requested == null) {
      throw ArgumentError('viewport needs a column or clear=1');
    }
    final double target = double.parse(requested);
    final ui.FlutterView view = _view();
    final double viewWidth = view.physicalSize.width / view.devicePixelRatio;
    double width = root.value.width ?? viewWidth;
    for (int pass = 0; pass < _viewportPasses; pass++) {
      final double? column = _column();
      if (column != null && (column - target).abs() < 0.01) {
        break;
      }
      final double next = (width + target - (column ?? width)).clamp(
        1,
        viewWidth,
      );
      if (next == width && pass > 0) {
        break;
      }
      width = next;
      root.value = root.value.copyWith(width: width);
      await _frames(2);
    }
    return ProbeReply.json(<String, Object?>{'column': _column()});
  }

  double? _column() => _findSurface()?.layout.inputs.columnWidth;

  Future<ProbeReply> _shot(ProbeRequest request) async {
    await _frames(1);
    final RenderObject? object = shotKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw StateError('no probe surface to capture');
    }
    final ui.Image image = await object.toImage(
      pixelRatio: _view().devicePixelRatio,
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (data == null) {
      throw StateError('could not encode the screenshot');
    }
    return ProbeReply.png(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  Future<ProbeReply> _nextPhoto(ProbeRequest request) async {
    _photoQueue = List<_PhotoRequest>.unmodifiable(<_PhotoRequest>[
      ..._photoQueue,
      _PhotoRequest(
        width: _int(request.query['w']) ?? _defaultPhotoWidth,
        height: _int(request.query['h']) ?? _defaultPhotoHeight,
        delay: Duration(milliseconds: _int(request.query['delayMs']) ?? 0),
      ),
    ]);
    return ProbeReply.json(<String, Object?>{'queued': _photoQueue.length});
  }

  Future<ProbeReply> _watch(ProbeRequest request) async {
    _attach();
    _log = const <Map<String, Object?>>[];
    binding._recorder.clearCommitted();
    return ProbeReply.json(<String, Object?>{'watching': _listening != null});
  }

  Future<ProbeReply> _logEndpoint(ProbeRequest request) async {
    _attach();
    final Map<String, Object?> reply = <String, Object?>{
      'transactions': _log,
      'committed': binding._recorder.committed,
    };
    if (request.query['clear'] == '1') {
      _log = const <Map<String, Object?>>[];
      binding._recorder.clearCommitted();
    }
    return ProbeReply.json(reply);
  }

  Future<ProbeReply> _flags(ProbeRequest request) async {
    final String? scaler = request.query['scaler'];
    if (scaler != null) {
      root.value = scaler == 'off'
          ? root.value.copyWith(clearScaler: true)
          : root.value.copyWith(scaler: double.parse(scaler));
      await _frames(2);
    }
    final int? draftDelay = _int(request.query['draftReadDelayMs']);
    if (draftDelay != null) {
      _draftReadDelay = Duration(milliseconds: draftDelay);
    }
    return ProbeReply.json(<String, Object?>{
      'scaler': root.value.scaler,
      'draftReadDelayMs': _draftReadDelay.inMilliseconds,
    });
  }

  void _attach() {
    final NoteEditorController? controller = _findSurface()?.controller;
    if (identical(controller, _listening)) {
      return;
    }
    _listening?.removeTransactionListener(_onTransaction);
    _listening = controller;
    _transactions = 0;
    controller?.addTransactionListener(_onTransaction);
  }

  void _onTransaction(Transaction transaction) {
    if (transaction.addToHistory && !transaction.changes.isEmpty) {
      _transactions += 1;
    }
    final List<Map<String, Object?>> log = <Map<String, Object?>>[
      ..._log,
      <String, Object?>{
        'event': transaction.event.label,
        'changes': <Object?>[
          for (final TextReplacement change in transaction.changes.replacements)
            <int>[change.from, change.to, change.inserted.length],
        ],
        'selection': _selectionJson(transaction.selection),
      },
    ];
    _log = List<Map<String, Object?>>.unmodifiable(
      log.length > _logHistory ? log.sublist(log.length - _logHistory) : log,
    );
  }

  _Surface? _findSurface() {
    final Element? editorBox = _keyedElement(noteEditorKey);
    if (editorBox != null) {
      final NoteEditorViewState? state = editorBox
          .findAncestorStateOfType<NoteEditorViewState>();
      final RenderNoteView? render = state == null
          ? null
          : _renderNoteViewBelow(state.context);
      if (state != null && render != null) {
        final NoteLayout? layout = state.debugLayout;
        return _Surface(
          render: render,
          layout: layout is LaidOutNote ? layout : render.noteLayout,
          editor: state,
        );
      }
    }
    final List<Element> readers = _elementsWhere(
      (Element element) => element.widget is NoteReaderView,
    );
    if (readers.isEmpty) {
      return null;
    }
    final String? opened = _openedSource;
    final Element reader =
        readers
            .where(
              (Element element) =>
                  (element.widget as NoteReaderView).source == opened,
            )
            .lastOrNull ??
        readers.last;
    final RenderNoteView? render = _renderNoteViewBelow(reader);
    return render == null
        ? null
        : _Surface(render: render, layout: render.noteLayout, editor: null);
  }

  static RenderNoteView? _renderNoteViewBelow(BuildContext context) {
    RenderNoteView? found;
    void visit(Element element) {
      if (found != null) {
        return;
      }
      final Object? object = element is RenderObjectElement
          ? element.renderObject
          : null;
      if (object is RenderNoteView && object.attached) {
        found = object;
        return;
      }
      element.visitChildElements(visit);
    }

    if (context is Element) {
      context.visitChildElements(visit);
    }
    return found;
  }

  _Surface _requireSurface() {
    final _Surface? surface = _findSurface();
    if (surface == null) {
      throw StateError('no note surface on screen');
    }
    return surface;
  }

  NoteEditorViewState _requireEditor() {
    final NoteEditorViewState? editor = _findSurface()?.editor;
    if (editor == null) {
      throw StateError('no editor on screen');
    }
    _attach();
    return editor;
  }

  NoteEditorController _requireController() =>
      _requireEditor().widget.controller;

  NavigatorState _rootNavigator() {
    NavigatorState? navigator;
    void visit(Element element) {
      if (navigator != null) {
        return;
      }
      if (element is StatefulElement && element.state is NavigatorState) {
        navigator = element.state as NavigatorState;
        return;
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    final NavigatorState? found = navigator;
    if (found == null) {
      throw StateError('the app has no navigator yet');
    }
    return found;
  }

  static void _visit(void Function(Element element) action) {
    void visit(Element element) {
      action(element);
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  }

  static List<Element> _elementsWhere(bool Function(Element element) test) {
    final List<Element> found = <Element>[];
    _visit((Element element) {
      if (test(element)) {
        found.add(element);
      }
    });
    return found;
  }

  static Element? _keyedElement(Key key) =>
      _elementsWhere((Element element) => element.widget.key == key).lastOrNull;

  static Element? _textElement(String label) =>
      _elementsWhere((Element element) {
        final Widget widget = element.widget;
        return widget is Text && widget.data == label;
      }).lastOrNull;

  static String? _keyValue(Element element) {
    final Key? key = element.widget.key;
    return key is ValueKey<String> ? key.value : null;
  }

  static Rect? _elementRect(Element element) {
    final RenderObject? object = element.renderObject;
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      object.getTransformTo(null),
      Offset.zero & object.size,
    );
  }

  static Map<String, Object?> _keyedRects(String prefix) {
    final Map<String, Object?> rects = <String, Object?>{};
    _visit((Element element) {
      final String? key = _keyValue(element);
      if (key == null || !key.startsWith(prefix)) {
        return;
      }
      final Rect? rect = _elementRect(element);
      if (rect != null) {
        rects[key] = _rectJson(rect);
      }
    });
    return rects;
  }

  Future<void> _pressElement(Element element) async {
    final Rect? rect = _elementRect(element);
    if (rect == null) {
      throw StateError('${element.widget.runtimeType} is not laid out');
    }
    final Offset centre = rect.center;
    final int pointer = _pointer++;
    final int viewId = _view().viewId;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: pointer, position: centre, viewId: viewId),
    );
    await Future<void>.delayed(_pressHold);
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: pointer, position: centre, viewId: viewId),
    );
    await _frames(1);
  }

  static Future<void> _frames(int count) async {
    for (int i = 0; i < count; i++) {
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  static ui.FlutterView _view() =>
      PlatformDispatcher.instance.implicitView ??
      PlatformDispatcher.instance.views.first;

  static Offset _point(ProbeRequest request) {
    final double? x = double.tryParse(request.query['x'] ?? '');
    final double? y = double.tryParse(request.query['y'] ?? '');
    if (x == null || y == null) {
      throw ArgumentError('needs x and y');
    }
    return Offset(x, y);
  }

  static int? _int(String? value) =>
      value == null || value.isEmpty ? null : int.parse(value);

  static List<Object?> _selectionJson(NoteSelection selection) => <Object?>[
    selection.anchor,
    selection.head,
    selection.affinity.name,
  ];

  static List<double> _rectJson(Rect rect) => <double>[
    rect.left,
    rect.top,
    rect.width,
    rect.height,
  ];

  static List<double>? _nullableRect(Rect? rect) =>
      rect == null ? null : _rectJson(rect);
}
