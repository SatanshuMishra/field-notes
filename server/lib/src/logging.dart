import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

typedef LogSink = void Function(String line);

void stdoutLogSink(String line) => stdout.writeln(line);

abstract final class LogContext {
  static const String route = 'relay.route';
  static const String account = 'relay.account';
  static const String device = 'relay.device';
}

const List<String> logFields = <String>[
  'ts',
  'route',
  'account',
  'device',
  'bytes',
  'status',
  'ms',
];

const String unmatchedRoute = 'unmatched';

final class AttributedHijack extends HijackException {
  const AttributedHijack(this.attributes);

  final Map<String, Object> attributes;
}

String logLine({
  required DateTime time,
  required String route,
  required String? account,
  required String? device,
  required int bytes,
  required int status,
  required int milliseconds,
}) => jsonEncode(<String, Object?>{
  'ts': time.toUtc().toIso8601String(),
  'route': route,
  'account': account,
  'device': device,
  'bytes': bytes,
  'status': status,
  'ms': milliseconds,
});

Middleware requestLogger(LogSink sink, DateTime Function() clock) =>
    (Handler inner) => (Request request) async {
      final Stopwatch watch = Stopwatch()..start();
      void write(Map<String, Object> context, int bytes, int status) => sink(
        logLine(
          time: clock(),
          route: context[LogContext.route] as String? ?? unmatchedRoute,
          account: context[LogContext.account] as String?,
          device: context[LogContext.device] as String?,
          bytes: bytes,
          status: status,
          milliseconds: watch.elapsedMilliseconds,
        ),
      );
      final int requestBytes = request.contentLength ?? 0;
      try {
        final Response response = await inner(request);
        write(
          response.context,
          requestBytes + (response.contentLength ?? 0),
          response.statusCode,
        );
        return response;
      } on AttributedHijack catch (hijack) {
        write(hijack.attributes, requestBytes, HttpStatus.switchingProtocols);
        rethrow;
      } on HijackException {
        write(
          const <String, Object>{},
          requestBytes,
          HttpStatus.switchingProtocols,
        );
        rethrow;
      } catch (_) {
        write(
          const <String, Object>{},
          requestBytes,
          HttpStatus.internalServerError,
        );
        return Response.internalServerError();
      }
    };
