import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:field_notes/data/sync/relay_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_protocol/sync_protocol.dart';

final Uri _relay = Uri.parse('https://relay.test');

List<int> _challengeBody() => utf8.encode(
  jsonEncode(
    ChallengeResponse(
      challengeId: 'challenge',
      nonce: 'nonce',
      expiresAt: DateTime.utc(2026, 10, 5, 12),
    ).toJson(),
  ),
);

Stream<List<int>> _trickle(List<int> body, int pieces, Duration gap) async* {
  final int size = (body.length / pieces).ceil();
  for (int start = 0; start < body.length; start += size) {
    await Future<void>.delayed(gap);
    yield body.sublist(start, min(start + size, body.length));
  }
}

MockClient _answering(Stream<List<int>> Function() body) =>
    MockClient.streaming(
      (http.BaseRequest request, http.ByteStream _) async =>
          http.StreamedResponse(
            body(),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
    );

void main() {
  test('a slow answer keeps arriving past the request timeout', () async {
    final RelayClient relay = RelayClient(
      baseUrl: _relay,
      client: _answering(
        () => _trickle(_challengeBody(), 4, const Duration(seconds: 1)),
      ),
      timeout: const Duration(seconds: 3),
    );

    final ChallengeResponse answer = await relay.sessionChallenge('device');

    expect(answer.challengeId, 'challenge');
  });

  test(
    'an answer that stops arriving fails after the request timeout',
    () async {
      final RelayClient relay = RelayClient(
        baseUrl: _relay,
        client: _answering(
          () => _trickle(_challengeBody(), 2, const Duration(seconds: 2)),
        ),
        timeout: const Duration(seconds: 1),
      );

      await expectLater(
        relay.sessionChallenge('device'),
        throwsA(isA<RelayUnreachable>()),
      );
    },
  );
}
