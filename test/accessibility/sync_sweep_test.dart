import 'states/sync_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'sync',
    groupName: 'every sync state loads and matches its baseline',
    states: syncStates,
  );
}
