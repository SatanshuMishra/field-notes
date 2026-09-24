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
