import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int probePort = 47111;

const List<String> probeEndpoints = <String>[
  'state',
  'keys',
  'find',
  'open',
  'save',
  'close',
  'set',
  'select',
  'focus',
  'errors',
  'timings',
  'clock',
  'caretAudit',
  'boxes',
  'hit',
  'offsetAt',
  'semantics',
  'settings',
  'viewport',
  'pid',
  'shot',
  'nextPhoto',
  'watch',
  'log',
  'flags',
];

const String probeScenarioEndpoint = 'scenario';

final class ProbeRequest {
  const ProbeRequest({
    required this.name,
    required this.query,
    required this.body,
  });

  final String name;
  final Map<String, String> query;
  final String body;
}

final class ProbeReply {
  const ProbeReply.json(this.body, {this.status = 200}) : png = null;

  const ProbeReply.png(List<int> bytes)
    : status = 200,
      body = null,
      png = bytes;

  final int status;
  final Object? body;
  final List<int>? png;
}

typedef ProbeHandler = Future<ProbeReply> Function(ProbeRequest request);

Map<String, Object?> probeKeystrokeJson({
  required int handlerMicros,
  required int? buildMicros,
  required int? rasterFinishMicros,
  required int? keyDownMicros,
}) => <String, Object?>{
  'handlerMs': handlerMicros / 1000,
  'buildMs': buildMicros == null ? null : buildMicros / 1000,
  'rasterFinishMicros': rasterFinishMicros,
  'keyDownMicros': keyDownMicros,
};

final class ProbeErrorLog {
  const ProbeErrorLog()
    : windowErrors = const <Map<String, Object?>>[],
      scenarioErrors = const <Map<String, Object?>>[],
      windowDrops = const <String>[],
      scenarioDrops = const <String>[],
      owner = null,
      seen = 0;

  const ProbeErrorLog._({
    required this.windowErrors,
    required this.scenarioErrors,
    required this.windowDrops,
    required this.scenarioDrops,
    required this.owner,
    required this.seen,
  });

  final List<Map<String, Object?>> windowErrors;
  final List<Map<String, Object?>> scenarioErrors;
  final List<String> windowDrops;
  final List<String> scenarioDrops;
  final Object? owner;
  final int seen;

  ProbeErrorLog recordError(Map<String, Object?> error) => ProbeErrorLog._(
    windowErrors: List<Map<String, Object?>>.unmodifiable(
      <Map<String, Object?>>[...windowErrors, error],
    ),
    scenarioErrors: List<Map<String, Object?>>.unmodifiable(
      <Map<String, Object?>>[...scenarioErrors, error],
    ),
    windowDrops: windowDrops,
    scenarioDrops: scenarioDrops,
    owner: owner,
    seen: seen,
  );

  ProbeErrorLog observe(Object dropOwner, List<String> drops) {
    final int from = identical(dropOwner, owner)
        ? (seen < drops.length ? seen : drops.length)
        : 0;
    final List<String> fresh = drops.sublist(from);
    return ProbeErrorLog._(
      windowErrors: windowErrors,
      scenarioErrors: scenarioErrors,
      windowDrops: List<String>.unmodifiable(<String>[
        ...windowDrops,
        ...fresh,
      ]),
      scenarioDrops: List<String>.unmodifiable(<String>[
        ...scenarioDrops,
        ...fresh,
      ]),
      owner: dropOwner,
      seen: drops.length,
    );
  }

  ProbeErrorLog clearWindow() => ProbeErrorLog._(
    windowErrors: const <Map<String, Object?>>[],
    scenarioErrors: scenarioErrors,
    windowDrops: const <String>[],
    scenarioDrops: scenarioDrops,
    owner: owner,
    seen: seen,
  );

  ProbeErrorLog resetScenario() => ProbeErrorLog._(
    windowErrors: const <Map<String, Object?>>[],
    scenarioErrors: const <Map<String, Object?>>[],
    windowDrops: const <String>[],
    scenarioDrops: const <String>[],
    owner: owner,
    seen: seen,
  );

  Map<String, Object?> json({required bool scenario}) => <String, Object?>{
    'errors': scenario ? scenarioErrors : windowErrors,
    'drops': <Object?>[
      for (final String reason in scenario ? scenarioDrops : windowDrops)
        <String, Object?>{'reason': reason},
    ],
  };
}

final class ProbeServer {
  ProbeServer(Map<String, ProbeHandler> handlers)
    : _handlers = Map<String, ProbeHandler>.unmodifiable(handlers) {
    final List<String> missing = <String>[
      ...probeEndpoints,
      probeScenarioEndpoint,
    ].where((String name) => !_handlers.containsKey(name)).toList();
    if (missing.isNotEmpty) {
      throw ArgumentError.value(
        missing.join(', '),
        'handlers',
        'no handler for probe endpoints',
      );
    }
  }

  final Map<String, ProbeHandler> _handlers;

  Future<ProbeReply> route(ProbeRequest request) async {
    final ProbeHandler? handler = _handlers[request.name];
    if (handler == null) {
      return ProbeReply.json(<String, Object?>{
        'error': 'unknown endpoint ${request.name}',
      }, status: 404);
    }
    try {
      return await handler(request);
    } catch (error) {
      return ProbeReply.json(<String, Object?>{
        'error': error.toString(),
      }, status: 500);
    }
  }

  Future<HttpServer> bind({int port = probePort}) async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    server.listen((HttpRequest request) {
      unawaited(_serve(request));
    });
    return server;
  }

  Future<void> _serve(HttpRequest request) async {
    final List<String> segments = request.uri.pathSegments;
    final String name = segments.isEmpty ? '' : segments.first;
    final String body = await utf8.decoder
        .bind(request)
        .join()
        .catchError((Object _) => '');
    final ProbeReply reply = await route(
      ProbeRequest(
        name: name,
        query: Map<String, String>.unmodifiable(request.uri.queryParameters),
        body: body,
      ),
    );
    final HttpResponse response = request.response;
    try {
      response.statusCode = reply.status;
      final List<int>? png = reply.png;
      if (png != null) {
        response.headers.contentType = ContentType('image', 'png');
        response.add(png);
      } else {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(reply.body));
      }
    } catch (error) {
      response.statusCode = HttpStatus.internalServerError;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(<String, Object?>{'error': error.toString()}));
    } finally {
      await response.close();
    }
  }
}
