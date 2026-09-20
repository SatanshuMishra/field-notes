import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:field_notes/domain/services/draft_store.dart';

const Duration draftIdleDebounce = Duration(milliseconds: 400);

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
  String? _lastPersisted;
  String? _restoredSource;
  bool _restoredDraft = false;
  bool _applying = false;
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

  Future<String?> restore() async {
    final String? stored = await _run<String?>((store) => store.read(key));
    if (_disposed || stored == null) {
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
    _debounce?.cancel();
    _debounce = null;
    _lastPersisted = null;
    return _run<void>((store) => store.delete(key));
  }

  Future<void> discardRestored() async {
    _restoredDraft = false;
    _restoredSource = null;
    _apply(initialSource);
    notifyListeners();
    await discard();
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
    if (_applying) {
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
