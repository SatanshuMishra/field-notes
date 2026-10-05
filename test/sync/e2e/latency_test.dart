import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sync_overrides.dart';
import '../support/relay_fixture.dart';
import '../support/simulated_device.dart';

const String _date = '2025-04-02';
const Duration _limit = Duration(seconds: 5);

Future<Duration> _timeUntilShown(
  SimulatedDevice from,
  SimulatedDevice to,
  domain.Mood mood,
) async {
  final Completer<void> shown = Completer<void>();
  final ProviderSubscription<AsyncValue<domain.Day?>> subscription = to
      .container
      .listen(dayForDateProvider(_date), (
        AsyncValue<domain.Day?>? previous,
        AsyncValue<domain.Day?> next,
      ) {
        if (next.value?.mood == mood && !shown.isCompleted) {
          shown.complete();
        }
      }, fireImmediately: true);
  try {
    expect(shown.isCompleted, isFalse);
    final Stopwatch stopwatch = Stopwatch()..start();
    await from.journal.setMoodForDate(date: _date, mood: mood);
    await shown.future.timeout(
      _limit,
      onTimeout: () => fail('${to.name} did not show ${mood.id} in time'),
    );
    return stopwatch.elapsed;
  } finally {
    subscription.close();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a mood reaches the other open device within five seconds', () async {
    final RelayFixture relay = await RelayFixture.start(rateBurst: 1000);
    addTearDown(relay.dispose);
    final SimulatedDevice mac = await SimulatedDevice.create(
      'Studio Mac of Ada',
    );
    addTearDown(mac.dispose);
    final SimulatedDevice phone = await SimulatedDevice.create(
      'Pocket Phone of Ada',
    );
    addTearDown(phone.dispose);
    await mac.enrol(relay);
    await phone.pairWith(mac, relay);
    await settle(relay, <SimulatedDevice>[mac, phone]);
    await eventually(() async => mac.engine.isLive && phone.engine.isLive);

    expect(
      await _timeUntilShown(mac, phone, domain.Mood.grateful),
      lessThan(_limit),
    );
    expect(
      await _timeUntilShown(phone, mac, domain.Mood.hopeful),
      lessThan(_limit),
    );
    expect(mac.engine.isLive && phone.engine.isLive, isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
