import 'package:integration_test/integration_test_driver.dart';

const String _outputFilename = 'note_perf_bench';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) {
        throw StateError(
          'the benchmark returned no report data; '
          'nothing was written to build/$_outputFilename.json',
        );
      }
      await writeResponseData(data, testOutputFilename: _outputFilename);
    },
  );
}
