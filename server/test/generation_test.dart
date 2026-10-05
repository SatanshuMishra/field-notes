import 'package:relay_server/relay_server.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

void main() {
  test('marking a running relay restored reaches its next answers', () async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn before = await harness.signIn(account.firstDevice);
    final StringBuffer out = StringBuffer();

    final int code = runAdminCommand(
      const <String>['mark-restored'],
      config: harness.config,
      out: out,
      err: StringBuffer(),
      clock: harness.clock,
    );

    expect(code, exitOk);
    final String marked = '$out'.split('\n').first.split('\t').last;
    expect(marked, isNot(before.response.generation));
    final SignedIn after = await harness.signIn(account.firstDevice);
    expect(after.response.generation, marked);
    expect((await harness.pull(after.session)).generation, marked);
  });
}
