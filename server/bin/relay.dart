import 'dart:async';
import 'dart:io';

import 'package:relay_server/relay_server.dart';

const Set<String> _backupCommands = <String>{'snapshot-db', 'verify-copy'};

Future<void> main(List<String> arguments) async {
  final RelayConfig config;
  try {
    config = RelayConfig.fromEnvironment();
  } on ConfigException catch (error) {
    stderr.writeln(error.message);
    exit(exitUsage);
  }
  if (arguments.isNotEmpty) {
    exit(
      _backupCommands.contains(arguments.first)
          ? runBackupCommand(
              arguments,
              config: config,
              out: stdout,
              err: stderr,
            )
          : runAdminCommand(
              arguments,
              config: config,
              out: stdout,
              err: stderr,
            ),
    );
  }
  final RelayApp app;
  try {
    app = await RelayApp.open(config: config);
  } on Object catch (error) {
    stderr.writeln('The relay did not start: $error');
    exit(exitFailure);
  }
  final RelayServer server = await RelayServer.serve(app);
  final Completer<void> stopping = Completer<void>();
  void stop(ProcessSignal signal) {
    if (!stopping.isCompleted) {
      stopping.complete();
    }
  }

  final List<StreamSubscription<ProcessSignal>> signals =
      <StreamSubscription<ProcessSignal>>[
        ProcessSignal.sigint.watch().listen(stop),
        ProcessSignal.sigterm.watch().listen(stop),
      ];
  await stopping.future;
  for (final StreamSubscription<ProcessSignal> signal in signals) {
    await signal.cancel();
  }
  await server.close();
  exit(exitOk);
}
