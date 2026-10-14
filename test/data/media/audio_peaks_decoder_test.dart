import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/media/audio_peaks_decoder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('field_notes/audio_peaks');
const String _path = '/journal/media/ab/abcdef.m4a';

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _messenger.setMockMethodCallHandler(_channel, null));

  test('the decoder asks the platform for 100 ms windows', () async {
    final List<MethodCall> calls = <MethodCall>[];
    _messenger.setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      return <double>[0.1, 0.2];
    });

    final List<double> rms = await const AudioPeaksDecoder().windowRms(_path);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'windowRms');
    expect(calls.single.arguments, <String, Object?>{
      'path': _path,
      'windowMs': 100,
    });
    expect(rms, <double>[0.1, 0.2]);
  });

  test('a bad platform answer is a failure', () async {
    final Map<String, Object? Function()> answers =
        <String, Object? Function()>{
          'a platform exception': () =>
              throw PlatformException(code: 'decode-failed'),
          'a map': () => <String, Object?>{
            'rms': <double>[0.1],
          },
          'a negative value': () => <Object?>[-1],
          'a value that is not a number': () => <Object?>[double.nan],
        };
    for (final MapEntry<String, Object? Function()> answer in answers.entries) {
      _messenger.setMockMethodCallHandler(
        _channel,
        (MethodCall call) async => answer.value(),
      );

      await expectLater(
        const AudioPeaksDecoder().windowRms(_path),
        throwsA(isA<AudioPeaksDecodeException>()),
        reason: answer.key,
      );
    }
  });

  group('the macOS decoder sample rate guard', () {
    final bool skip = !Platform.isMacOS;

    List<String> liftedFunction(String name) {
      final List<String> lines = File('macos/Runner/MainFlutterWindow.swift')
          .readAsLinesSync();
      final int start = lines.indexWhere(
        (String line) => line.startsWith('  private static func $name('),
      );
      if (start < 0) {
        return <String>[];
      }
      final int end = lines.indexOf('  }', start);
      return lines
          .sublist(start, end + 1)
          .map((String line) => line.replaceFirst('private static', 'static'))
          .toList();
    }

    Uint8List caf(double sampleRate, int frames) {
      final BytesBuilder out = BytesBuilder();
      void u16(int v) =>
          out.add((ByteData(2)..setUint16(0, v)).buffer.asUint8List());
      void u32(int v) =>
          out.add((ByteData(4)..setUint32(0, v)).buffer.asUint8List());
      void i64(int v) =>
          out.add((ByteData(8)..setInt64(0, v)).buffer.asUint8List());
      void f64(double v) =>
          out.add((ByteData(8)..setFloat64(0, v)).buffer.asUint8List());
      void f32(double v) =>
          out.add((ByteData(4)..setFloat32(0, v)).buffer.asUint8List());
      out.add('caff'.codeUnits);
      u16(1);
      u16(0);
      out.add('desc'.codeUnits);
      i64(32);
      f64(sampleRate);
      out.add('lpcm'.codeUnits);
      u32(1);
      u32(4);
      u32(1);
      u32(1);
      u32(32);
      out.add('data'.codeUnits);
      i64(4 + frames * 4);
      u32(0);
      for (int i = 0; i < frames; i++) {
        f32(0.5);
      }
      return out.takeBytes();
    }

    Future<List<String>> runSwift(
      Directory dir,
      String source,
      List<String> args,
    ) async {
      final File swift = File('${dir.path}/h.swift')..writeAsStringSync(source);
      final ProcessResult compiled = await Process.run('swiftc', <String>[
        '-Onone',
        '-o',
        '${dir.path}/h',
        swift.path,
      ]);
      expect(compiled.exitCode, 0, reason: '${compiled.stderr}');
      final ProcessResult run = await Process.run('${dir.path}/h', args);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      return (run.stdout as String).trim().split('\n');
    }

    String decoderProgram() {
      final String constant = File('macos/Runner/MainFlutterWindow.swift')
          .readAsLinesSync()
          .firstWhere(
            (String l) => l.contains('audioPeaksReadFrames: AVAudioFrameCount'),
          )
          .replaceFirst('private ', '');
      return <String>[
        'import AVFoundation',
        constant,
        'enum H {',
        ...liftedFunction('windowFrames'),
        ...liftedFunction('windowRms'),
        '}',
        'for path in CommandLine.arguments.dropFirst() {',
        '  if let r = H.windowRms(path: path, windowMs: 100) {',
        '    print(r.map { String(\$0) }.joined(separator: ","))',
        '  } else {',
        '    print("failure")',
        '  }',
        '}',
      ].join('\n');
    }

    Future<void> withDir(Future<void> Function(Directory dir) body) async {
      final Directory dir = Directory.systemTemp.createTempSync('peaks_rate');
      try {
        await body(dir);
      } finally {
        dir.deleteSync(recursive: true);
      }
    }

    test(
      'the macOS decoder fails a NaN sample rate and still reads a good file',
      () => withDir((Directory dir) async {
        final File good = File('${dir.path}/good.m4a')
          ..writeAsBytesSync(caf(16000, 16000));
        final File nan = File('${dir.path}/nan.m4a')
          ..writeAsBytesSync(caf(double.nan, 1000));

        final List<String> lines = await runSwift(
          dir,
          decoderProgram(),
          <String>[good.path, nan.path],
        );

        expect(lines, hasLength(2));
        final List<double> values = lines[0]
            .split(',')
            .map(double.parse)
            .toList();
        expect(values, hasLength(10));
        for (final double v in values) {
          expect(v, closeTo(0.5, 0.000001));
        }
        expect(lines[1], 'failure');
      }),
      skip: skip,
    );

    test(
      'the macOS decoder fails a 0 Hz sample rate and one it cannot open',
      () => withDir((Directory dir) async {
        final List<String> paths = <String>[];
        final List<double> rates = <double>[
          0,
          -16000,
          double.infinity,
          10000000,
        ];
        for (int i = 0; i < rates.length; i++) {
          final File f = File('${dir.path}/r$i.m4a')
            ..writeAsBytesSync(caf(rates[i], 1000));
          paths.add(f.path);
        }

        final List<String> lines = await runSwift(dir, decoderProgram(), paths);

        expect(lines, <String>['failure', 'failure', 'failure', 'failure']);
      }),
      skip: skip,
    );

    test(
      'the macOS window length refuses a rate it cannot count',
      () => withDir((Directory dir) async {
        final String source = <String>[
          'enum H {',
          ...liftedFunction('windowFrames'),
          '}',
          'for a in CommandLine.arguments.dropFirst() {',
          '  if let n = H.windowFrames(sampleRate: Double(a)!, windowMs: 100) {',
          '    print(n)',
          '  } else {',
          '    print("failure")',
          '  }',
          '}',
        ].join('\n');

        final List<String> lines = await runSwift(dir, source, <String>[
          'nan',
          '0',
          '-16000',
          '-inf',
          'inf',
          '93000000000000000000',
          '1e-300',
          '4',
          '16000',
          '92000000000000000000',
        ]);

        expect(lines, <String>[
          'failure',
          'failure',
          'failure',
          'failure',
          'failure',
          'failure',
          '1',
          '1',
          '1600',
          '9200000000000000000',
        ]);
      }),
      skip: skip,
    );
  });
}
