import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/services/draft_store.dart';

const Duration draftIdleDebounce = Duration(milliseconds: 400);
const Duration draftRestoreWait = Duration(seconds: 2);

class NoteDraftController extends ChangeNotifier with WidgetsBindingObserver {
  NoteDraftController({
    required this.key,
    required FutureOr<DraftStore> store,
    this.initialSource = '',
    this.idleDebounce = draftIdleDebounce,
  }) : _store = Future<DraftStore>.value(store) {
    _store.ignore();
  }

  final String key;
  final String initialSource;
  final Duration idleDebounce;
  final Future<DraftStore> _store;

  TextEditingController? _text;
  Timer? _debounce;
  Future<void> _queue = Future<void>.value();
  Future<String?>? _restoring;
  String? _lastPersisted;
  String? _restoredSource;
  bool _restoredDraft = false;
  bool _applying = false;
  bool _sealed = false;
  bool _disposed = false;

  bool get restoredDraft => _restoredDraft;

  bool get isAttached => _text != null;

  String get currentSource => _text?.text ?? initialSource;

  bool get isDirty => currentSource != initialSource;

  void attach(TextEditingController controller) {
    _text?.removeListener(_onChanged);
    _text = controller;
    controller.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<String?> restore() => _restoring ??= _restore();

  Future<void> restoreSettled() async {
    await _restoring?.timeout(draftRestoreWait, onTimeout: () => null);
  }

  Future<String?> _restore() async {
    final String? stored = await _run<String?>((store) => store.read(key));
    if (_disposed || _sealed || stored == null) {
      return null;
    }
    if (stored == initialSource) {
      await _run<void>((store) => store.delete(key));
      return null;
    }
    _lastPersisted = stored;
    _restoredSource = stored;
    _restoredDraft = true;
    _apply(stored);
    notifyListeners();
    return stored;
  }

  Future<void> flush() {
    if (_sealed) {
      return _queue;
    }
    _debounce?.cancel();
    _debounce = null;
    final String source = currentSource;
    if (source == _lastPersisted) {
      return _queue;
    }
    _lastPersisted = source;
    return _run<void>(
      (store) => source == initialSource
          ? store.delete(key)
          : store.write(key, source),
    );
  }

  Future<void> settle() {
    _debounce?.cancel();
    _debounce = null;
    return _queue;
  }

  Future<void> discard() {
    if (!_sealed) {
      _sealed = true;
      WidgetsBinding.instance.removeObserver(this);
    }
    return _deleteDraft();
  }

  Future<void> seal() => discard();

  Future<void> discardRestored() async {
    _restoredDraft = false;
    _restoredSource = null;
    _apply(initialSource);
    notifyListeners();
    await _deleteDraft();
  }

  Future<void> _deleteDraft() {
    _debounce?.cancel();
    _debounce = null;
    _lastPersisted = null;
    return _run<void>((store) => store.delete(key));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(flush());
    }
  }

  void _apply(String source) {
    _applying = true;
    try {
      _text?.text = source;
    } finally {
      _applying = false;
    }
  }

  void _onChanged() {
    if (_applying || _sealed) {
      return;
    }
    if (_restoredDraft && currentSource != _restoredSource) {
      _restoredDraft = false;
      _restoredSource = null;
      notifyListeners();
    }
    _debounce?.cancel();
    _debounce = Timer(idleDebounce, () => unawaited(flush()));
  }

  Future<T?> _run<T>(Future<T> Function(DraftStore store) action) {
    final Future<T?> result = _queue.then((_) async {
      if (_disposed) {
        return null;
      }
      try {
        final DraftStore store = await _store;
        return await action(store);
      } catch (error, stackTrace) {
        debugPrint('Draft $key operation failed: $error\n$stackTrace');
        return null;
      }
    });
    _queue = result.then((_) {});
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _text?.removeListener(_onChanged);
    _text = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
