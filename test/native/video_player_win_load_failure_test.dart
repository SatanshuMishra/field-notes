import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sources = 'third_party/video_player_win/windows';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _between(String source, String start, String end) {
  final int from = source.indexOf(start);
  expect(from, isNot(-1), reason: '$start is missing');
  final int to = source.indexOf(end, from + start.length);
  expect(to, isNot(-1), reason: '$start has no end');
  return source.substring(from, to);
}

void main() {
  test('the load callback is taken off the player before it runs', () {
    final String player = _read('$_sources/my_grabber_player.cpp');
    expect(
      RegExp(r'm_loadCallback\(').allMatches(player),
      isEmpty,
      reason:
          'a load callback that releases the player must not run while '
          'the player still holds it',
    );
    final String finish = _between(
      player,
      'void MyPlayer::finishLoad(bool loaded)',
      '\n}\n',
    );
    final int taken = finish.indexOf('std::move(m_loadCallback)');
    final int cleared = finish.indexOf('m_loadCallback = NULL;');
    final int invoked = finish.indexOf('callback(loaded);');
    expect(taken, isNot(-1));
    expect(cleared, greaterThan(taken));
    expect(invoked, greaterThan(cleared));
    expect(
      RegExp(r'finishLoad\(').allMatches(player).length,
      greaterThanOrEqualTo(4),
      reason:
          'can play, engine error and the OpenURL failure all finish the '
          'load through finishLoad',
    );
  });

  test('a failed open replies to Dart exactly once', () {
    final String plugin = _read('$_sources/video_player_win_plugin.cpp');
    final String open = _between(
      plugin,
      'std::move(result);',
      '} else if (method_call.method_name().compare("play") == 0)',
    );
    expect(
      RegExp(r'(?<![A-Za-z_])result->').allMatches(open),
      isEmpty,
      reason: 'the moved method result is null after std::move',
    );
    expect(open, contains('if (FAILED(hr) && !*replied)'));
  });
}
