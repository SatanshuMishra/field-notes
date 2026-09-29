import 'states/immersive_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'immersive',
    groupName: 'every immersive recorder state loads and matches its baseline',
    states: immersiveStates,
  );
}
