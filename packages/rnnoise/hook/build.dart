import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const List<String> _sources = <String>[
  'third_party/rnnoise/src/denoise.c',
  'third_party/rnnoise/src/rnn.c',
  'third_party/rnnoise/src/pitch.c',
  'third_party/rnnoise/src/kiss_fft.c',
  'third_party/rnnoise/src/celt_lpc.c',
  'third_party/rnnoise/src/nnet.c',
  'third_party/rnnoise/src/nnet_default.c',
  'third_party/rnnoise/src/parse_lpcnet_weights.c',
  'third_party/rnnoise/src/rnnoise_data.c',
  'third_party/rnnoise/src/rnnoise_tables.c',
];

const List<String> _includes = <String>[
  'third_party/rnnoise/include',
  'third_party/rnnoise/src',
];

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final OS targetOS = input.config.code.targetOS;
    final CBuilder library = CBuilder.library(
      name: 'rnnoise',
      assetName: 'rnnoise.dart',
      sources: _sources,
      includes: _includes,
      defines: <String, String?>{
        'RNNOISE_BUILD': null,
        if (targetOS == OS.windows) 'WIN32': null,
        if (targetOS == OS.windows) 'DLL_EXPORT': null,
      },
      libraries: <String>[
        if (targetOS == OS.android || targetOS == OS.linux) 'm',
      ],
    );
    await library.run(input: input, output: output);
  });
}
