import 'states/capture_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'capture',
    groupName: 'every capture state loads and matches its baseline',
    states: captureStates,
  );
}
