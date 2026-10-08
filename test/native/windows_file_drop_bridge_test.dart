import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/note_engine/platform/file_drop.dart';

const String _runner = 'windows/runner';

String _source(String name) {
  final File file = File('$_runner/$name');
  expect(file.existsSync(), isTrue, reason: '$_runner/$name is missing');
  return file.readAsStringSync();
}

String _function(String source, String signature) {
  final int start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature must exist');
  final int end = source.indexOf('\n}\n', start);
  expect(end, isNot(-1), reason: '$signature must end');
  return source.substring(start, end);
}

Future<void> _deliver(String method, [Object? arguments]) {
  final Completer<ByteData?> reply = Completer<ByteData?>();
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        fileDropChannelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        reply.complete,
      )
      .then((_) => reply.future);
}

String _sent(String bridge, String constant) {
  final RegExpMatch? match = RegExp('$constant\\[\\] = "(\\w+)";')
      .firstMatch(bridge);
  expect(match, isNotNull, reason: '$constant must name a method');
  return match!.group(1)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Windows file drop bridge answers the macOS contract', () async {
    final String bridge = _source('file_drop_bridge.cpp');
    final String header = _source('file_drop_bridge.h');

    expect(bridge, contains('kFileDropChannelName[] = "$fileDropChannelName"'));
    for (final String key in <String>['x', 'y', 'paths']) {
      expect(bridge, contains('flutter::EncodableValue("$key")'));
    }

    final FileDropChannel channel = FileDropChannel();
    final List<FileDropEvent> events = <FileDropEvent>[];
    final StreamSubscription<FileDropEvent> subscription = channel.events
        .listen(events.add);
    addTearDown(subscription.cancel);
    await _deliver(_sent(bridge, 'kHoverMethod'), <String, Object?>{
      'x': 120.5,
      'y': 48.0,
    });
    await _deliver(_sent(bridge, 'kDropMethod'), <String, Object?>{
      'x': 120.5,
      'y': 60.0,
      'paths': <String>[r'C:\Users\me\leaf.JPG'],
    });
    await _deliver(_sent(bridge, 'kLeaveMethod'));
    await pumpEventQueue();
    expect(events, const <FileDropEvent>[
      FileDropHover(Offset(120.5, 48)),
      FileDropped(
        position: Offset(120.5, 60),
        paths: <String>[r'C:\Users\me\leaf.JPG'],
      ),
      FileDropLeave(),
    ]);

    expect(header, contains('class FileDropBridge : public IDropTarget {'));
    for (final String method in <String>[
      'QueryInterface',
      'AddRef',
      'Release',
      'DragEnter',
      'DragOver',
      'DragLeave',
      'Drop',
    ]) {
      expect(header, contains('STDMETHODCALLTYPE $method('));
    }
    expect(bridge, contains('__uuidof(IDropTarget)'));
    expect(bridge, contains('::InterlockedIncrement(&references_)'));
    expect(bridge, contains('::InterlockedDecrement(&references_)'));
    expect(bridge, contains('delete this;'));

    final String register = _function(
      bridge,
      'void FileDropBridge::Register()',
    );
    expect(register, contains('::RegisterDragDrop(view_, this)'));
    expect(register, contains('OutputDebugStringW(message)'));
    expect(bridge, contains('::RevokeDragDrop(view_)'));

    expect(bridge, contains('static_cast<CLIPFORMAT>(CF_HDROP)'));
    expect(bridge, contains('data->QueryGetData(&format) == S_OK'));
    expect(
      _function(bridge, 'HRESULT FileDropBridge::DragEnter('),
      contains('Hover(point, effect);'),
    );
    expect(
      _function(bridge, 'HRESULT FileDropBridge::DragOver('),
      contains('Hover(point, effect);'),
    );
    final String hover = _function(bridge, 'void FileDropBridge::Hover(');
    expect(hover, contains('*effect = DROPEFFECT_NONE;'));
    expect(hover, contains('*effect = DROPEFFECT_COPY;'));
    expect(hover, contains('kHoverMethod'));
    expect(
      _function(bridge, 'HRESULT FileDropBridge::DragLeave()'),
      contains('InvokeMethod(kLeaveMethod, nullptr)'),
    );
    final String drop = _function(bridge, 'HRESULT FileDropBridge::Drop(');
    expect(drop, contains('DroppedPaths(data)'));
    expect(drop, contains('kDropMethod'));
    expect(
      _function(bridge, 'flutter::EncodableList DroppedPaths('),
      contains('PathsFromDrop(static_cast<HDROP>(medium.hGlobal))'),
    );

    final String position = _function(
      bridge,
      'flutter::EncodableMap FileDropBridge::PositionOf(',
    );
    expect(position, contains('::ScreenToClient(view_, &client)'));
    expect(position, contains('::GetDpiForWindow(view_)'));
    expect(position, contains('dpi / 96.0'));
    expect(position, contains('client.x / scale'));
    expect(position, contains('client.y / scale'));

    final String flutterWindow = _source('flutter_window.cpp');
    expect(
      flutterWindow,
      matches(
        RegExp(
          r'new FileDropBridge\(\s*messenger, '
          r'flutter_controller_->view\(\)->GetNativeWindow\(\)\)',
        ),
      ),
    );
    expect(flutterWindow, contains('file_drop_bridge_.Get()->Register();'));
    final String destroy = _function(
      flutterWindow,
      'void FlutterWindow::OnDestroy()',
    );
    final int revoke = destroy.indexOf('file_drop_bridge_.Get()->Revoke();');
    expect(revoke, isNot(-1));
    expect(
      revoke,
      lessThan(destroy.indexOf('flutter_controller_ = nullptr;')),
      reason: 'the drop target is revoked before the controller goes',
    );
    expect(
      _source('flutter_window.h'),
      contains('Microsoft::WRL::ComPtr<FileDropBridge> file_drop_bridge_;'),
    );

    final String main = _source('main.cpp');
    expect(main, contains('::OleInitialize(nullptr)'));
    expect(main, contains('::OleUninitialize();'));
    expect(main, isNot(contains('CoInitializeEx')));
    expect(bridge, isNot(matches(RegExp(r'\b(try|catch|throw)\b'))));

    final String cmake = _source('CMakeLists.txt');
    expect(cmake, contains('"file_drop_bridge.cpp"'));
    expect(cmake, contains('"ole32.lib"'));
    expect(cmake, contains('"shell32.lib"'));
  });
}
