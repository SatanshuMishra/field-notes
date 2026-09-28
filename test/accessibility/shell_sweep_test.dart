import 'states/shell_states.dart';
import 'support/a11y_state.dart';

void main() {
  a11ySweepArea(
    area: 'shell',
    groupName: 'every shell state loads and matches its baseline',
    states: shellStates,
  );
}
