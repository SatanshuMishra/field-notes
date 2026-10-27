import 'states/updates_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'updates',
    groupName: 'every updates state loads and matches its baseline',
    states: updatesStates,
  );
}
